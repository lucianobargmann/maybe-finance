class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: [:clear_cache, :clear_exchange_rate_cache]

  def show
    synth_provider = Provider::Registry.get_provider(:synth)
    @synth_usage = synth_provider&.usage
    @synth_connected = @synth_usage.present? && @synth_usage.success?

    finnhub_provider = Provider::Registry.get_provider(:finnhub)
    @finnhub_usage = finnhub_provider&.usage
    @finnhub_connected = @finnhub_usage.present? && @finnhub_usage.success?

    exchangerate_api_provider = Provider::Registry.get_provider(:exchangerate_api)
    @exchangerate_api_usage = exchangerate_api_provider&.usage
    @exchangerate_api_connected = @exchangerate_api_usage.present? && @exchangerate_api_usage.success?

    alpha_vantage_provider = Provider::Registry.get_provider(:alpha_vantage)
    @alpha_vantage_connected = alpha_vantage_provider.present?

    crypto_compare_provider = Provider::Registry.get_provider(:crypto_compare)
    @crypto_compare_usage = crypto_compare_provider&.usage
    @crypto_compare_connected = @crypto_compare_usage.present? && @crypto_compare_usage.success?

    # AI providers - check if configured (skip expensive health checks)
    anthropic_provider = Provider::Registry.get_provider(:anthropic)
    @anthropic_connected = anthropic_provider.present?

    openai_provider = Provider::Registry.get_provider(:openai)
    @openai_connected = openai_provider.present?
  end

  def update
    if hosting_params.key?(:require_invite_for_signup)
      Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:synth_api_key)
      Setting.synth_api_key = hosting_params[:synth_api_key]
    end

    if hosting_params.key?(:finnhub_api_key)
      Setting.finnhub_api_key = hosting_params[:finnhub_api_key]
    end

    if hosting_params.key?(:exchangerate_api_key)
      Setting.exchangerate_api_key = hosting_params[:exchangerate_api_key]
    end

    if hosting_params.key?(:alpha_vantage_api_key)
      Setting.alpha_vantage_api_key = hosting_params[:alpha_vantage_api_key]
    end

    if hosting_params.key?(:crypto_compare_api_key)
      Setting.crypto_compare_api_key = hosting_params[:crypto_compare_api_key]
    end

    if hosting_params.key?(:exchange_rate_provider)
      Setting.exchange_rate_provider = hosting_params[:exchange_rate_provider]
    end

    if hosting_params.key?(:security_provider)
      Setting.security_provider = hosting_params[:security_provider]
    end

    if hosting_params.key?(:anthropic_api_key)
      Setting.anthropic_api_key = hosting_params[:anthropic_api_key]
    end

    if hosting_params.key?(:llm_provider)
      Setting.llm_provider = hosting_params[:llm_provider]
    end

    if hosting_params.key?(:openai_access_token)
      Setting.openai_access_token = hosting_params[:openai_access_token]
    end

    if hosting_params.key?(:llm_model)
      Setting.llm_model = hosting_params[:llm_model]
    end

    redirect_to settings_hosting_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = t(".failure")
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  def clear_exchange_rate_cache
    # Clear ExchangeRate-API cache
    exchangerate_api_provider = Provider::Registry.get_provider(:exchangerate_api)
    exchangerate_api_provider&.clear_cache

    # Clear Synth cache (if it has one)
    synth_provider = Provider::Registry.get_provider(:synth)
    synth_provider&.clear_cache if synth_provider.respond_to?(:clear_cache)

    # Clear CryptoCompare cache
    crypto_compare_provider = Provider::Registry.get_provider(:crypto_compare)
    crypto_compare_provider&.clear_cache if crypto_compare_provider.respond_to?(:clear_cache)

    redirect_to settings_hosting_path, notice: t(".exchange_rate_cache_cleared")
  end

  private
    def hosting_params
      params.require(:setting).permit(:require_invite_for_signup, :require_email_confirmation, :synth_api_key, :finnhub_api_key, :exchangerate_api_key, :alpha_vantage_api_key, :crypto_compare_api_key, :exchange_rate_provider, :security_provider, :anthropic_api_key, :openai_access_token, :llm_provider, :llm_model)
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
