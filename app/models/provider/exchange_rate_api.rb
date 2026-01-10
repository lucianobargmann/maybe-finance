class Provider::ExchangeRateApi < Provider
  include ExchangeRateConcept

  # Subclass so errors caught in this provider are raised as Provider::ExchangeRateApi::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  QuotaReachedError = Class.new(Error)
  InvalidApiKeyError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("/v6/#{api_key}/latest/USD")
      parsed = JSON.parse(response.body)
      parsed["result"] == "success"
    end
  end

  def usage
    with_provider_response do
      # ExchangeRate-API doesn't provide usage information in their API
      # Return a placeholder response
      UsageData.new(
        used: 0,
        limit: 0,
        utilization: 0.0,
        plan: "free"
      )
    end
  end

  def clear_cache
    # Clear all ExchangeRate-API cache entries
    Rails.cache.delete_matched("exchange_rate_api:*")
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      # ExchangeRate-API only provides current rates, not historical
      # For historical data, we'll need to use a different approach
      if date != Date.current
        raise InvalidExchangeRateError.new("ExchangeRate-API only provides current exchange rates, not historical data for #{date}")
      end

      # Check cache first (24-hour cache)
      cache_key = "exchange_rate_api:#{from}:#{to}:#{Date.current}"
      cached_data = Rails.cache.read(cache_key)
      
      if cached_data.present?
        return Rate.new(date: date, from: from, to: to, rate: cached_data)
      end

      response = client.get("/v6/#{api_key}/latest/#{from}")
      parsed = JSON.parse(response.body)

      handle_api_response(parsed)

      conversion_rates = parsed["conversion_rates"]
      rate = conversion_rates[to]

      raise InvalidExchangeRateError.new("Currency #{to} not found in conversion rates") if rate.nil?

      # Cache the result for 24 hours
      Rails.cache.write(cache_key, rate, expires_in: 24.hours)

      Rate.new(date: date, from: from, to: to, rate: rate)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      # ExchangeRate-API doesn't support historical data in bulk
      # We'll fetch current rates and return them for the end_date
      if start_date != end_date
        Rails.logger.warn("ExchangeRate-API only provides current rates. Fetching current rate for #{end_date} instead of range #{start_date} to #{end_date}")
      end

      # Check cache first (24-hour cache)
      cache_key = "exchange_rate_api:#{from}:#{to}:#{Date.current}"
      cached_data = Rails.cache.read(cache_key)
      
      if cached_data.present?
        return [Rate.new(date: end_date, from: from, to: to, rate: cached_data)]
      end

      response = client.get("/v6/#{api_key}/latest/#{from}")
      parsed = JSON.parse(response.body)

      handle_api_response(parsed)

      conversion_rates = parsed["conversion_rates"]
      rate = conversion_rates[to]

      raise InvalidExchangeRateError.new("Currency #{to} not found in conversion rates") if rate.nil?

      # Cache the result for 24 hours
      Rails.cache.write(cache_key, rate, expires_in: 24.hours)

      [Rate.new(date: end_date, from: from, to: to, rate: rate)]
    end
  end

  private
    attr_reader :api_key

    def base_url
      "https://v6.exchangerate-api.com"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
        faraday.headers["User-Agent"] = "Maybe Finance App"
      end
    end

    def handle_api_response(parsed_response)
      case parsed_response["result"]
      when "error"
        error_type = parsed_response["error-type"]
        case error_type
        when "invalid-key"
          raise InvalidApiKeyError.new("Invalid API key for ExchangeRate-API")
        when "quota-reached"
          raise QuotaReachedError.new("API quota reached for ExchangeRate-API")
        when "unsupported-code"
          raise InvalidExchangeRateError.new("Unsupported currency code")
        when "malformed-request"
          raise InvalidExchangeRateError.new("Malformed request to ExchangeRate-API")
        when "inactive-account"
          raise InvalidApiKeyError.new("Inactive account for ExchangeRate-API")
        else
          raise Error.new("ExchangeRate-API error: #{error_type}")
        end
      when "success"
        # Success case - no action needed
      else
        raise Error.new("Unexpected response from ExchangeRate-API: #{parsed_response}")
      end
    end
end