class ExtractTextTransactionsJob < ApplicationJob
  queue_as :default

  class TextValidationError < StandardError; end

  MIN_TEXT_LENGTH = 50

  def perform(import, text)
    validate_text!(text)

    # Step 1: Sending to AI
    import.update!(pdf_processing_status: :extracting_transactions)
    broadcast_status(import, step: :sending_to_ai)
    Rails.logger.info("[TextImport] Sending text to AI for extraction...")

    # Step 2: Extract transactions using AI
    extractor = build_extractor(import.family)
    result = extractor.extract(text)
    Rails.logger.info("[TextImport] AI response received - #{result.transactions.count} transactions found")

    # Step 3: Format and generate CSV
    broadcast_status(import, step: :formatting)
    Rails.logger.info("[TextImport] Formatting #{result.transactions.count} transactions...")
    csv = generate_csv(result.transactions)

    # Step 4: Update import with CSV data and pre-configure columns
    Rails.logger.info("[TextImport] Saving CSV data to import...")
    import.update!(
      raw_file_str: csv,
      pdf_processing_status: :pdf_complete,
      date_col_label: "date",
      amount_col_label: "amount",
      name_col_label: "description",
      category_col_label: "category",
      date_format: result.detected_date_format,
      number_format: result.detected_number_format
    )

    # Step 5: Generate rows and sync mappings
    Rails.logger.info("[TextImport] Generating import rows and syncing mappings...")
    import.generate_rows_from_csv
    import.sync_mappings

    Rails.logger.info("[TextImport] Complete! #{import.rows.count} rows ready for import")
    broadcast_complete(import)
  rescue TextValidationError => e
    handle_error(import, e.message)
  rescue Provider::Error => e
    handle_error(import, "AI extraction failed: #{e.message}")
  rescue => e
    Rails.logger.error("Text extraction failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    handle_error(import, "An unexpected error occurred during extraction. Please try again.")
  end

  private

  def validate_text!(text)
    raise TextValidationError, "Text is too short. Please paste more content." if text.to_s.strip.length < MIN_TEXT_LENGTH
    raise TextValidationError, "Text does not appear to contain transaction data." unless contains_transaction_data?(text)
  end

  def contains_transaction_data?(text)
    # Check for presence of numbers (amounts) and date-like patterns
    has_numbers = text.match?(/\d+[.,]\d{2}/)
    has_dates = text.match?(/\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/)
    has_numbers || has_dates
  end

  def build_extractor(family)
    provider_name = Setting.llm_provider&.to_sym || :anthropic
    provider = Provider::Registry.get_provider(provider_name)

    raise Provider::Error, "AI provider not configured" unless provider

    categories = family.categories.map do |c|
      { id: c.id, name: c.name, classification: c.classification }
    end

    case provider_name
    when :anthropic
      Provider::Anthropic::PdfTransactionExtractor.new(
        provider.send(:client),
        user_categories: categories
      )
    when :openai
      Provider::Openai::PdfTransactionExtractor.new(
        provider.send(:client),
        user_categories: categories
      )
    else
      raise Provider::Error, "Unsupported AI provider: #{provider_name}"
    end
  end

  def generate_csv(transactions)
    CSV.generate do |csv|
      csv << [ "date", "description", "amount", "category" ]
      transactions.each do |t|
        csv << [ t.date, t.description, t.amount, t.category ]
      end
    end
  end

  def handle_error(import, message)
    import.update!(
      pdf_processing_status: :pdf_failed,
      pdf_error_message: message
    )
    broadcast_error(import)
  end

  def broadcast_status(import, step: :extracting)
    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "text_paste_status",
      partial: "import/text_pastes/processing",
      locals: { import: import, step: step }
    )
  end

  def broadcast_complete(import)
    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "text_paste_status",
      partial: "import/text_pastes/complete",
      locals: { import: import }
    )
  end

  def broadcast_error(import)
    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "text_paste_status",
      partial: "import/text_pastes/error",
      locals: { import: import }
    )
  end
end
