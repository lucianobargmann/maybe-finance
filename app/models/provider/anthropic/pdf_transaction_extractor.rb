class Provider::Anthropic::PdfTransactionExtractor
  ExtractionResult = Data.define(:detected_date_format, :detected_number_format, :transactions)
  Transaction = Data.define(:date, :description, :amount, :category)

  def initialize(client, user_categories: [], model: nil)
    @client = client
    @user_categories = user_categories
    @model = model || Setting.llm_model || "claude-sonnet-4-20250514"
  end

  def extract(pdf_text)
    response = client.messages.create(
      model: @model,
      max_tokens: 8192,
      system: instructions,
      messages: [ { role: "user", content: build_user_message(pdf_text) } ],
      tools: [
        {
          name: "extract_transactions",
          description: "Extract transactions from a bank or credit card statement",
          input_schema: json_schema
        }
      ],
      tool_choice: { type: "tool", name: "extract_transactions" }
    )

    # Convert response to deeply stringified hash
    response_hash = deep_stringify(response)

    usage = response_hash["usage"] || {}
    Rails.logger.info("Tokens used to extract PDF transactions: #{usage["input_tokens"].to_i + usage["output_tokens"].to_i}")
    Rails.logger.info("Response content: #{response_hash["content"].inspect}")

    build_result(response_hash)
  end

  private

  attr_reader :client, :user_categories

  def deep_stringify(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
    when Array
      obj.map { |v| deep_stringify(v) }
    when Symbol
      obj.to_s
    else
      if obj.respond_to?(:to_h) && !obj.is_a?(String) && !obj.is_a?(Numeric)
        deep_stringify(obj.to_h)
      else
        obj
      end
    end
  end

  def build_result(response)
    content = response["content"] || []
    tool_use = content.find { |c| c["type"] == "tool_use" }
    raise Provider::Anthropic::Error, "AI did not return structured extraction data" unless tool_use

    input = tool_use["input"]

    transactions_data = input["transactions"] || []
    transactions = transactions_data.map do |t|
      Transaction.new(
        date: t["date"],
        description: t["description"],
        amount: t["amount"],
        category: normalize_category(t["category"])
      )
    end

    ExtractionResult.new(
      detected_date_format: input["detected_date_format"] || "%d/%m/%Y",
      detected_number_format: input["detected_number_format"] || "1.234,56",
      transactions: transactions
    )
  end

  def normalize_category(category)
    return nil if category.nil? || category == "null" || category.blank?
    category
  end

  def json_schema
    category_names = user_categories.map { |c| c[:name] || c["name"] }.compact

    {
      type: "object",
      properties: {
        detected_date_format: {
          type: "string",
          enum: [ "%d/%m/%Y", "%m/%d/%Y", "%Y-%m-%d", "%d.%m.%Y" ],
          description: "The date format detected in the document"
        },
        detected_number_format: {
          type: "string",
          enum: [ "1,234.56", "1.234,56", "1 234,56" ],
          description: "The number format detected in the document (1,234.56 = US/UK, 1.234,56 = Brazilian/European)"
        },
        transactions: {
          type: "array",
          description: "All transactions extracted from the statement",
          items: {
            type: "object",
            properties: {
              date: {
                type: "string",
                description: "Transaction date WITH FULL YEAR (e.g., 15/01/2026, 01/15/2026, or 2026-01-15). NEVER omit the year."
              },
              description: {
                type: "string",
                description: "Transaction description/merchant name, cleaned of card numbers and transaction codes"
              },
              amount: {
                type: "string",
                description: "Transaction amount exactly as it appears (with original formatting). Negative for debits/purchases, positive for credits/deposits."
              },
              category: {
                type: [ "string", "null" ],
                enum: category_names.any? ? [ *category_names, nil ] : nil,
                description: "Matched category name from available categories, or null if uncertain"
              }
            },
            required: [ "date", "description", "amount" ]
          }
        }
      },
      required: [ "detected_date_format", "detected_number_format", "transactions" ]
    }
  end

  def build_user_message(pdf_text)
    <<~MESSAGE.strip_heredoc
      Extract all transactions from this bank/credit card statement:

      #{pdf_text}
    MESSAGE
  end

  def instructions
    <<~INSTRUCTIONS.strip_heredoc
      You are a financial document parser specializing in extracting transactions from bank and credit card statements.

      CRITICAL EXTRACTION RULES:
      1. Extract EVERY transaction visible in the statement - do not skip any
      2. For each transaction identify: date, description, amount
      3. Dates MUST ALWAYS include the full year (e.g., "15/01/2026" not "15/01")
      4. Preserve the exact number format from the document (e.g., "1.234,56" not "1234.56")
      5. Clean descriptions: remove card numbers, transaction codes, but keep merchant names
      6. Determine if amounts are debits (negative) or credits (positive) based on context

      DATE FORMAT - CRITICAL:
      - ALL dates MUST include the year. If the source only shows day/month (e.g., "12/01"), you MUST add the year.
      - Look for year context in: statement headers, period dates, "Janeiro 2026", "Jan 2026", etc.
      - If no year is visible, use the current year: #{Date.current.year}
      - Brazilian/European: DD/MM/YYYY (e.g., 15/01/2026 = January 15, 2026)
      - US format: MM/DD/YYYY (e.g., 01/15/2026 = January 15, 2026)
      - ISO format: YYYY-MM-DD
      - Use context clues: if you see day values > 12, that field is the day (DD/MM/YYYY)

      NUMBER FORMAT DETECTION:
      - Brazilian/European: 1.234,56 (period = thousands separator, comma = decimal)
      - US/UK: 1,234.56 (comma = thousands separator, period = decimal)
      - French/Scandinavian: 1 234,56 (space = thousands, comma = decimal)
      - Detect from the statement's country/bank or number patterns

      AMOUNT SIGN CONVENTION:
      - Purchases, payments, withdrawals, debits → NEGATIVE amounts
      - Deposits, refunds, credits → POSITIVE amounts
      - Look for indicators: "D" vs "C", "DB" vs "CR", minus signs, parentheses

      CATEGORY MATCHING (if categories provided):
      #{category_instructions}

      Return transactions in chronological order (oldest first).
    INSTRUCTIONS
  end

  def category_instructions
    if user_categories.any?
      category_list = user_categories.map { |c| "- #{c[:name] || c["name"]}" }.join("\n")
      <<~CAT
        Available categories:
        #{category_list}

        Only assign a category if you are 70%+ confident. Otherwise return null.
        Match based on merchant name, transaction type, and common spending patterns.
      CAT
    else
      "No categories provided - return null for all category fields."
    end
  end
end
