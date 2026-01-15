class ExtractPdfTransactionsJob < ApplicationJob
  queue_as :default

  def perform(import, pdf_content_base64)
    import.update!(pdf_processing_status: :extracting_text)
    broadcast_status(import)

    # Step 1: Decode Base64 and extract text from PDF
    pdf_content = Base64.strict_decode64(pdf_content_base64)
    text = Import::PdfTextParser.new(pdf_content).extract

    import.update!(pdf_processing_status: :extracting_transactions)
    broadcast_status(import)

    # Step 2: Use AI to extract transactions
    extractor = build_extractor(import.family)
    result = extractor.extract(text)

    # Step 3: Convert to CSV
    csv = generate_csv(result.transactions)

    # Step 4: Update import with CSV data and pre-configure columns
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
    import.generate_rows_from_csv
    import.sync_mappings

    broadcast_complete(import)

  rescue Import::PdfTextParser::PasswordProtectedError => e
    handle_error(import, e.message)
  rescue Import::PdfTextParser::InvalidPdfError => e
    handle_error(import, e.message)
  rescue Import::PdfTextParser::NoTextError => e
    handle_error(import, "Could not extract text from this PDF. It may contain only images. Please use CSV import instead.")
  rescue Provider::Error => e
    handle_error(import, "AI extraction failed: #{e.message}")
  rescue => e
    Rails.logger.error("PDF extraction failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    handle_error(import, "An unexpected error occurred during extraction. Please try again or use CSV import.")
  end

  private

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

  def broadcast_status(import)
    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "pdf_upload_status",
      partial: "import/pdf_uploads/processing",
      locals: { import: import }
    )
  end

  def broadcast_complete(import)
    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "pdf_upload_status",
      partial: "import/pdf_uploads/complete",
      locals: { import: import }
    )
  end

  def broadcast_error(import)
    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "pdf_upload_status",
      partial: "import/pdf_uploads/error",
      locals: { import: import }
    )
  end
end
