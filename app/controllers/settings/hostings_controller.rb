class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: [:clear_cache, :clear_exchange_rate_cache]

  def show
    synth_provider = Provider::Registry.get_provider(:synth)
    @synth_usage = synth_provider&.usage

    exchangerate_api_provider = Provider::Registry.get_provider(:exchangerate_api)
    @exchangerate_api_usage = exchangerate_api_provider&.usage
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

    if hosting_params.key?(:exchangerate_api_key)
      Setting.exchangerate_api_key = hosting_params[:exchangerate_api_key]
    end

    if hosting_params.key?(:exchange_rate_provider)
      Setting.exchange_rate_provider = hosting_params[:exchange_rate_provider]
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

    redirect_to settings_hosting_path, notice: t(".exchange_rate_cache_cleared")
  end

  private
    def hosting_params
      params.require(:setting).permit(:require_invite_for_signup, :require_email_confirmation, :synth_api_key, :exchangerate_api_key, :exchange_rate_provider)
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
