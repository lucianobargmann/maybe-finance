class Import::TextPastesController < ApplicationController
  layout "imports"

  before_action :set_import
  before_action :require_ai_provider

  def show
  end

  def update
    pasted_text = params.dig(:import, :pasted_text)

    unless pasted_text.present?
      flash.now[:alert] = t(".no_text")
      return render :show, status: :unprocessable_entity
    end

    if pasted_text.length > 500_000
      flash.now[:alert] = t(".text_too_large")
      return render :show, status: :unprocessable_entity
    end

    @import.account = Current.family.accounts.find_by(id: params.dig(:import, :account_id))
    @import.update!(
      original_text_preview: pasted_text.first(500),
      pdf_processing_status: :pdf_pending
    )

    # Enqueue background job with pasted text
    ExtractTextTransactionsJob.perform_later(@import, pasted_text)

    redirect_to import_text_paste_path(@import), notice: t(".processing_started")
  end

  def retry
    @import.update!(pdf_processing_status: nil, pdf_error_message: nil)
    redirect_to import_text_paste_path(@import)
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
