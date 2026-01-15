class Import::PdfTextParser
  class PasswordProtectedError < StandardError; end
  class InvalidPdfError < StandardError; end
  class NoTextError < StandardError; end

  def initialize(pdf_content)
    @pdf_content = pdf_content
  end

  def extract
    io = StringIO.new(@pdf_content)
    reader = PDF::Reader.new(io)

    text = reader.pages.map do |page|
      page.text
    end.join("\n\n")

    raise NoTextError, "No text could be extracted from the PDF" if text.strip.blank?

    text
  rescue PDF::Reader::EncryptedPDFError
    raise PasswordProtectedError, "This PDF is password protected. Please remove the password and try again."
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
    raise InvalidPdfError, "This file doesn't appear to be a valid PDF: #{e.message}"
  end

  private

  attr_reader :pdf_content
end
