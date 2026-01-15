class Provider::Openai::PdfTransactionExtractor
  ExtractionResult = Data.define(:detected_date_format, :detected_number_format, :transactions)
  Transaction = Data.define(:date, :description, :amount, :category)

  def initialize(client, user_categories: [])
    @client = client
    @user_categories = user_categories
  end

  def extract(pdf_text)
    response = client.responses.create(parameters: {
      model: "gpt-4.1",
      input: [ { role: "developer", content: build_user_message(pdf_text) } ],
      text: {
        format: {
          type: "json_schema",
          name: "extract_bank_statement_transactions",
          strict: true,
          schema: json_schema
        }
      },
      instructions: instructions
    })

    Rails.logger.info("Tokens used to extract PDF transactions: #{response.dig("usage", "total_tokens")}")

    build_result(response)
  end

  private

  attr_reader :client, :user_categories

  def build_result(response)
    response_json = JSON.parse(response.dig("output", 0, "content", 0, "text"))

    transactions = (response_json["transactions"] || []).map do |t|
      Transaction.new(
        date: t["date"],
        description: t["description"],
        amount: t["amount"],
        category: normalize_category(t["category"])
      )
    end

    ExtractionResult.new(
      detected_date_format: response_json["detected_date_format"] || "%d/%m/%Y",
      detected_number_format: response_json["detected_number_format"] || "1.234,56",
      transactions: transactions
    )
  end

  def normalize_category(category)
    return nil if category.nil? || category == "null" || category.blank?
    category
  end

  def json_schema
    category_names = user_categories.map { |c| c[:name] || c["name"] }.compact

    schema = {
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
          description: "The number format detected in the document"
        },
        transactions: {
          type: "array",
          description: "All transactions extracted from the statement",
          items: {
            type: "object",
            properties: {
              date: {
                type: "string",
                description: "Transaction date exactly as it appears in the document"
              },
              description: {
                type: "string",
                description: "Transaction description/merchant name"
              },
              amount: {
                type: "string",
                description: "Transaction amount with original formatting"
              },
              category: {
                type: [ "string", "null" ],
                description: "Matched category name or null"
              }
            },
            required: [ "date", "description", "amount", "category" ],
            additionalProperties: false
          }
        }
      },
      required: [ "detected_date_format", "detected_number_format", "transactions" ],
      additionalProperties: false
    }

    # Add category enum if categories provided
    if category_names.any?
      schema[:properties][:transactions][:items][:properties][:category][:enum] = [ *category_names, nil ]
    end

    schema
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
      1. Extract EVERY transaction visible in the statement
      2. For each transaction identify: date, description, amount
      3. Preserve the exact date format from the document
      4. Preserve the exact number format from the document
      5. Clean descriptions: remove card numbers and transaction codes
      6. Determine if amounts are debits (negative) or credits (positive)

      DATE FORMAT DETECTION:
      - Brazilian/European: DD/MM/YYYY (day > 12 indicates this format)
      - US format: MM/DD/YYYY
      - ISO format: YYYY-MM-DD

      NUMBER FORMAT DETECTION:
      - Brazilian/European: 1.234,56 (period = thousands, comma = decimal)
      - US/UK: 1,234.56 (comma = thousands, period = decimal)

      AMOUNT SIGNS:
      - Purchases, payments, withdrawals → NEGATIVE
      - Deposits, refunds, credits → POSITIVE

      #{category_instructions}

      Return transactions in chronological order.
    INSTRUCTIONS
  end

  def category_instructions
    if user_categories.any?
      category_list = user_categories.map { |c| "- #{c[:name] || c["name"]}" }.join("\n")
      "Available categories:\n#{category_list}\n\nOnly assign if 70%+ confident, otherwise null."
    else
      "No categories provided - return null for category."
    end
  end
end
