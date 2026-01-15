class Import::PdfUploadsController < ApplicationController
  layout "imports"

  before_action :set_import
  before_action :require_ai_provider

  def show
  end

  def update
    pdf_file = params.dig(:import, :pdf_file)

    unless pdf_file.present?
      flash.now[:alert] = t(".no_file")
      return render :show, status: :unprocessable_entity
    end

    unless pdf_file.content_type == "application/pdf"
      flash.now[:alert] = t(".invalid_type")
      return render :show, status: :unprocessable_entity
    end

    if pdf_file.size > 10.megabytes
      flash.now[:alert] = t(".file_too_large")
      return render :show, status: :unprocessable_entity
    end

    @import.account = Current.family.accounts.find_by(id: params.dig(:import, :account_id))
    @import.update!(
      original_pdf_filename: pdf_file.original_filename,
      pdf_processing_status: :pdf_pending
    )

    # Enqueue background job with PDF content (Base64 encoded for JSON serialization)
    ExtractPdfTransactionsJob.perform_later(@import, Base64.strict_encode64(pdf_file.read))

    redirect_to import_pdf_upload_path(@import), notice: t(".processing_started")
  end

  def retry
    @import.update!(pdf_processing_status: nil, pdf_error_message: nil)
    redirect_to import_pdf_upload_path(@import)
  end

  private

  def set_import
    @import = Current.family.imports.find(params[:import_id])
  end

  def require_ai_provider
    provider_name = Setting.llm_provider&.to_sym || :anthropic
    provider = Provider::Registry.get_provider(provider_name)

    unless provider.present?
      redirect_to import_upload_path(@import), alert: t(".ai_not_configured")
    end
  end
end
