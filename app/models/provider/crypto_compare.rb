class Provider::CryptoCompare < Provider
  include ExchangeRateConcept

  # Subclass so errors caught in this provider are raised as Provider::CryptoCompare::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  RateLimitError = Class.new(Error)
  InvalidApiKeyError = Class.new(Error)

  BASE_URL = "https://min-api.cryptocompare.com"

  # Common crypto symbols that CryptoCompare supports
  CRYPTO_SYMBOLS = %w[BTC ETH LTC XRP BCH EOS XLM ADA DOT LINK UNI DOGE SOL AVAX MATIC BNB USDT USDC].freeze

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("/data/price", {
        fsym: "BTC",
        tsyms: "USD"
      })
      parsed = JSON.parse(response.body)
      parsed.key?("USD") && !parsed.key?("Message")
    end
  end

  def usage
    with_provider_response do
      # CryptoCompare free tier: 100,000 calls/month
      # We can query rate limit status from their stats endpoint
      response = client.get("/stats/rate/limit")
      parsed = JSON.parse(response.body)

      if parsed["Response"] == "Success"
        calls_made = parsed.dig("Data", "calls_made", "month") || 0
        calls_left = parsed.dig("Data", "calls_left", "month") || 100_000
        total_calls = calls_made + calls_left

        UsageData.new(
          used: calls_made,
          limit: total_calls,
          utilization: total_calls > 0 ? (calls_made.to_f / total_calls * 100).round(1) : 0.0,
          plan: "free"
        )
      else
        # Fallback if we can't get stats
        UsageData.new(
          used: 0,
          limit: 100_000,
          utilization: 0.0,
          plan: "free"
        )
      end
    end
  end

  def clear_cache
    Rails.cache.delete_matched("crypto_compare:*")
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      is_crypto_from = crypto_currency?(from)
      is_crypto_to = crypto_currency?(to)

      # CryptoCompare is specialized for crypto - at least one side should be crypto
      unless is_crypto_from || is_crypto_to
        raise InvalidExchangeRateError.new("CryptoCompare requires at least one cryptocurrency (#{from}/#{to})")
      end

      if date == Date.current || date > Date.current
        fetch_current_rate(from: from, to: to, date: date)
      else
        fetch_historical_rate(from: from, to: to, date: date)
      end
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      is_crypto_from = crypto_currency?(from)
      is_crypto_to = crypto_currency?(to)

      unless is_crypto_from || is_crypto_to
        raise InvalidExchangeRateError.new("CryptoCompare requires at least one cryptocurrency (#{from}/#{to})")
      end

      fetch_historical_rates(from: from, to: to, start_date: start_date, end_date: end_date)
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
        faraday.headers["Authorization"] = "Apikey #{api_key}" if api_key.present?
      end
    end

    def fetch_current_rate(from:, to:, date:)
      cache_key = "crypto_compare:current:#{from}:#{to}:#{Date.current}"
      cached_rate = Rails.cache.read(cache_key)

      if cached_rate.present?
        return Rate.new(date: date, from: from, to: to, rate: cached_rate)
      end

      # Determine which is crypto (CryptoCompare expects crypto as fsym)
      if crypto_currency?(from)
        fsym = from
        tsym = to
        invert = false
      else
        fsym = to
        tsym = from
        invert = true
      end

      response = client.get("/data/price", {
        fsym: fsym,
        tsyms: tsym
      })

      parsed = JSON.parse(response.body)
      handle_api_errors(parsed)

      rate = parsed[tsym].to_f
      raise InvalidExchangeRateError.new("No exchange rate returned for #{from}/#{to}") if rate.zero?

      rate = 1.0 / rate if invert

      # Cache for 5 minutes (crypto prices change frequently)
      Rails.cache.write(cache_key, rate, expires_in: 5.minutes)

      Rate.new(date: date, from: from, to: to, rate: rate)
    end

    def fetch_historical_rate(from:, to:, date:)
      cache_key = "crypto_compare:historical:#{from}:#{to}:#{date}"
      cached_rate = Rails.cache.read(cache_key)

      if cached_rate.present?
        return Rate.new(date: date, from: from, to: to, rate: cached_rate)
      end

      if crypto_currency?(from)
        fsym = from
        tsym = to
        invert = false
      else
        fsym = to
        tsym = from
        invert = true
      end

      timestamp = date.to_time.to_i

      response = client.get("/data/v2/histoday", {
        fsym: fsym,
        tsym: tsym,
        limit: 1,
        toTs: timestamp
      })

      parsed = JSON.parse(response.body)
      handle_api_errors(parsed)

      data = parsed.dig("Data", "Data")
      raise InvalidExchangeRateError.new("No historical data returned for #{from}/#{to}") if data.nil? || data.empty?

      # Use close price
      rate = data.last["close"].to_f
      raise InvalidExchangeRateError.new("Invalid historical rate for #{from}/#{to}") if rate.zero?

      rate = 1.0 / rate if invert

      # Cache historical data for 24 hours (it doesn't change)
      Rails.cache.write(cache_key, rate, expires_in: 24.hours)

      Rate.new(date: date, from: from, to: to, rate: rate)
    end

    def fetch_historical_rates(from:, to:, start_date:, end_date:)
      if crypto_currency?(from)
        fsym = from
        tsym = to
        invert = false
      else
        fsym = to
        tsym = from
        invert = true
      end

      days = (end_date - start_date).to_i
      timestamp = end_date.to_time.to_i

      response = client.get("/data/v2/histoday", {
        fsym: fsym,
        tsym: tsym,
        limit: [days, 2000].min, # CryptoCompare max is 2000
        toTs: timestamp
      })

      parsed = JSON.parse(response.body)
      handle_api_errors(parsed)

      data = parsed.dig("Data", "Data")
      raise InvalidExchangeRateError.new("No historical data returned for #{from}/#{to}") if data.nil? || data.empty?

      data.map do |day_data|
        rate = day_data["close"].to_f
        rate = 1.0 / rate if invert && rate > 0
        date = Time.at(day_data["time"]).to_date

        # Cache each historical rate
        cache_key = "crypto_compare:historical:#{from}:#{to}:#{date}"
        Rails.cache.write(cache_key, rate, expires_in: 24.hours) if rate > 0

        Rate.new(date: date, from: from, to: to, rate: rate)
      end.select { |r| r.rate > 0 }
    end

    def crypto_currency?(currency)
      CRYPTO_SYMBOLS.include?(currency.to_s.upcase)
    end

    def handle_api_errors(parsed_response)
      if parsed_response["Response"] == "Error"
        message = parsed_response["Message"] || "Unknown error"

        if message.include?("rate limit") || message.include?("limit")
          raise RateLimitError.new("CryptoCompare API rate limit exceeded")
        elsif message.include?("api_key") || message.include?("authorization")
          raise InvalidApiKeyError.new("Invalid CryptoCompare API key")
        else
          raise Error.new("CryptoCompare error: #{message}")
        end
      end
    end
end
