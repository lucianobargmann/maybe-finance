class Provider::AlphaVantage < Provider
  include ExchangeRateConcept

  # Subclass so errors caught in this provider are raised as Provider::AlphaVantage::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  RateLimitError = Class.new(Error)
  InvalidApiKeyError = Class.new(Error)

  BASE_URL = "https://www.alphavantage.co"

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      # Test with a simple forex rate request
      response = client.get("/query", {
        function: "CURRENCY_EXCHANGE_RATE",
        from_currency: "USD",
        to_currency: "EUR",
        apikey: api_key
      })
      parsed = JSON.parse(response.body)
      !parsed.key?("Error Message") && !parsed.key?("Note")
    end
  end

  def usage
    with_provider_response do
      # Alpha Vantage free tier: 25 requests/day
      # Premium tiers vary - we can't query this via API
      UsageData.new(
        used: 0,
        limit: 25,
        utilization: 0.0,
        plan: "free"
      )
    end
  end

  def clear_cache
    Rails.cache.delete_matched("alpha_vantage:*")
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      # Determine if this is a crypto or fiat currency
      is_crypto_from = crypto_currency?(from)
      is_crypto_to = crypto_currency?(to)

      if is_crypto_from || is_crypto_to
        fetch_crypto_rate(from: from, to: to, date: date)
      else
        fetch_forex_rate(from: from, to: to, date: date)
      end
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      # For simplicity, fetch current rate and return it
      # Alpha Vantage historical data requires premium for bulk access
      rate = fetch_exchange_rate(from: from, to: to, date: end_date)
      [rate]
    end
  end

  private
    attr_reader :api_key

    def client
      @client ||= Faraday.new(url: BASE_URL) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2
        })
        faraday.response :raise_error
        faraday.headers["User-Agent"] = "Maybe Finance App"
      end
    end

    def fetch_forex_rate(from:, to:, date:)
      cache_key = "alpha_vantage:forex:#{from}:#{to}:#{Date.current}"
      cached_rate = Rails.cache.read(cache_key)

      if cached_rate.present?
        return Rate.new(date: date, from: from, to: to, rate: cached_rate)
      end

      response = client.get("/query", {
        function: "CURRENCY_EXCHANGE_RATE",
        from_currency: from,
        to_currency: to,
        apikey: api_key
      })

      parsed = JSON.parse(response.body)
      handle_api_errors(parsed)

      rate_data = parsed["Realtime Currency Exchange Rate"]
      raise InvalidExchangeRateError.new("No exchange rate data returned for #{from}/#{to}") if rate_data.nil?

      rate = rate_data["5. Exchange Rate"].to_f
      raise InvalidExchangeRateError.new("Invalid exchange rate for #{from}/#{to}") if rate.zero?

      # Cache for 1 hour (Alpha Vantage has strict rate limits)
      Rails.cache.write(cache_key, rate, expires_in: 1.hour)

      Rate.new(date: date, from: from, to: to, rate: rate)
    end

    def fetch_crypto_rate(from:, to:, date:)
      cache_key = "alpha_vantage:crypto:#{from}:#{to}:#{Date.current}"
      cached_rate = Rails.cache.read(cache_key)

      if cached_rate.present?
        return Rate.new(date: date, from: from, to: to, rate: cached_rate)
      end

      # Determine which is the crypto currency
      crypto_symbol = crypto_currency?(from) ? from : to
      market = crypto_currency?(from) ? to : from

      response = client.get("/query", {
        function: "CURRENCY_EXCHANGE_RATE",
        from_currency: crypto_symbol,
        to_currency: market,
        apikey: api_key
      })

      parsed = JSON.parse(response.body)
      handle_api_errors(parsed)

      rate_data = parsed["Realtime Currency Exchange Rate"]
      raise InvalidExchangeRateError.new("No crypto exchange rate data returned for #{from}/#{to}") if rate_data.nil?

      rate = rate_data["5. Exchange Rate"].to_f
      raise InvalidExchangeRateError.new("Invalid crypto exchange rate for #{from}/#{to}") if rate.zero?

      # If we queried to->from, we need to invert
      if crypto_currency?(to)
        rate = 1.0 / rate
      end

      # Cache for 15 minutes (crypto prices change faster)
      Rails.cache.write(cache_key, rate, expires_in: 15.minutes)

      Rate.new(date: date, from: from, to: to, rate: rate)
    end

    def crypto_currency?(currency)
      # Common crypto symbols - Alpha Vantage uses standard crypto symbols
      %w[BTC ETH LTC XRP BCH EOS XLM ADA DOT LINK UNI DOGE SOL AVAX MATIC].include?(currency.to_s.upcase)
    end

    def handle_api_errors(parsed_response)
      if parsed_response.key?("Error Message")
        error_msg = parsed_response["Error Message"]
        if error_msg.include?("Invalid API call") || error_msg.include?("apikey")
          raise InvalidApiKeyError.new("Invalid Alpha Vantage API key")
        else
          raise Error.new("Alpha Vantage error: #{error_msg}")
        end
      end

      if parsed_response.key?("Note")
        # Rate limit exceeded
        raise RateLimitError.new("Alpha Vantage API rate limit exceeded. Please wait and try again.")
      end

      if parsed_response.key?("Information")
        info = parsed_response["Information"]
        if info.include?("API key")
          raise InvalidApiKeyError.new("Invalid or missing Alpha Vantage API key")
        end
      end
    end
end
