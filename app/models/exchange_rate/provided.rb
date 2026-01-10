module ExchangeRate::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:exchange_rates)
      
      # Try to get the preferred provider from settings, fallback to synth
      preferred_provider = Setting.exchange_rate_provider&.to_sym
      
      if preferred_provider.present?
        begin
          registry.get_provider(preferred_provider)
        rescue Provider::Registry::Error
          Rails.logger.warn("Configured exchange rate provider '#{preferred_provider}' not available, falling back to synth")
          registry.get_provider(:synth)
        end
      else
        # Default to synth if no preference is set
        registry.get_provider(:synth)
      end
    end

    def available_providers
      registry = Provider::Registry.for_concept(:exchange_rates)
      registry.providers.compact
    end

    def find_or_fetch_rate(from:, to:, date: Date.current, cache: true)
      rate = find_by(from_currency: from, to_currency: to, date: date)
      return rate if rate.present?

      return nil unless provider.present? # No provider configured (some self-hosted apps)

      response = provider.fetch_exchange_rate(from: from, to: to, date: date)

      return nil unless response.success? # Provider error

      rate = response.data
      ExchangeRate.find_or_create_by!(
        from_currency: rate.from,
        to_currency: rate.to,
        date: rate.date,
        rate: rate.rate
      ) if cache
      rate
    end

    # @return [Integer] The number of exchange rates synced
    def import_provider_rates(from:, to:, start_date:, end_date:, clear_cache: false)
      unless provider.present?
        Rails.logger.warn("No provider configured for ExchangeRate.import_provider_rates")
        return 0
      end

      ExchangeRate::Importer.new(
        exchange_rate_provider: provider,
        from: from,
        to: to,
        start_date: start_date,
        end_date: end_date,
        clear_cache: clear_cache
      ).import_provider_rates
    end
  end
end
