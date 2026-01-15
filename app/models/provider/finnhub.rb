class Provider::Finnhub < Provider
  include SecurityConcept

  # Subclass so errors caught in this provider are raised as Provider::Finnhub::Error
  Error = Class.new(Provider::Error)
  InvalidSecurityPriceError = Class.new(Error)
  ApiLimitError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("/api/v1/stock/profile2", symbol: "AAPL")
      parsed = JSON.parse(response.body)
      parsed["ticker"].present?
    end
  end

  def usage
    with_provider_response do
      # Finnhub doesn't provide usage info via API
      UsageData.new(
        used: 0,
        limit: 60,
        utilization: 0.0,
        plan: "free"
      )
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(query, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      response = client.get("/api/v1/search", q: query)
      parsed = JSON.parse(response.body)

      results = parsed["result"] || []

      results.first(25).map do |security|
        Security.new(
          symbol: security["symbol"],
          name: security["description"],
          logo_url: nil, # Finnhub doesn't provide logo in search
          exchange_operating_mic: extract_mic_from_symbol(security["symbol"]),
          country_code: country_code || "US"
        )
      end
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      response = client.get("/api/v1/stock/profile2", symbol: normalize_symbol(symbol))
      data = JSON.parse(response.body)

      return nil if data.empty?

      SecurityInfo.new(
        symbol: symbol,
        name: data["name"],
        links: data["weburl"],
        logo_url: data["logo"],
        description: data["finnhubIndustry"],
        kind: data["finnhubIndustry"],
        exchange_operating_mic: data["exchange"] || exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      prices_response = fetch_security_prices(
        symbol: symbol,
        exchange_operating_mic: exchange_operating_mic,
        start_date: date,
        end_date: date
      )

      if prices_response.success? && prices_response.data.any?
        prices_response.data.first
      else
        # If no data for exact date, try to get the most recent available
        prices_response = fetch_security_prices(
          symbol: symbol,
          exchange_operating_mic: exchange_operating_mic,
          start_date: date - 7.days,
          end_date: date
        )

        raise InvalidSecurityPriceError.new("No prices found for #{symbol}") unless prices_response.success? && prices_response.data.any?

        prices_response.data.last
      end
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      normalized_symbol = normalize_symbol(symbol)

      # Finnhub uses Unix timestamps
      from_timestamp = start_date.to_time.to_i
      to_timestamp = (end_date + 1.day).to_time.to_i # Add 1 day to include end_date

      response = client.get("/api/v1/stock/candle") do |req|
        req.params["symbol"] = normalized_symbol
        req.params["resolution"] = "D" # Daily
        req.params["from"] = from_timestamp
        req.params["to"] = to_timestamp
      end

      parsed = JSON.parse(response.body)

      # Handle "no_data" status
      if parsed["s"] == "no_data" || parsed["c"].nil?
        return []
      end

      # Finnhub returns arrays: c (close), h (high), l (low), o (open), t (timestamp), v (volume)
      closes = parsed["c"] || []
      timestamps = parsed["t"] || []

      # Get currency from profile (Finnhub doesn't include it in candle data)
      currency = fetch_currency_for_symbol(normalized_symbol)

      timestamps.each_with_index.map do |timestamp, index|
        date = Time.at(timestamp).to_date
        price = closes[index]

        next if price.nil?

        Price.new(
          symbol: symbol,
          date: date,
          price: price,
          currency: currency,
          exchange_operating_mic: exchange_operating_mic
        )
      end.compact
    end
  end

  private
    attr_reader :api_key

    def base_url
      "https://finnhub.io"
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
        faraday.headers["X-Finnhub-Token"] = api_key
      end
    end

    def normalize_symbol(symbol)
      # Remove exchange suffix if present (e.g., "AAPL.US" -> "AAPL")
      symbol.to_s.split(".").first.upcase
    end

    def extract_mic_from_symbol(symbol)
      # Finnhub uses suffixes like .HK, .L, etc.
      parts = symbol.to_s.split(".")
      if parts.length > 1
        suffix_to_mic(parts.last)
      else
        "XNAS" # Default to NASDAQ for US stocks
      end
    end

    def suffix_to_mic(suffix)
      # Map common Finnhub suffixes to MIC codes
      {
        "US" => "XNAS",
        "L" => "XLON",
        "HK" => "XHKG",
        "T" => "XTKS",
        "DE" => "XETR",
        "PA" => "XPAR",
        "AS" => "XAMS",
        "SW" => "XSWX",
        "TO" => "XTSE",
        "AX" => "XASX"
      }[suffix.upcase] || "XNAS"
    end

    def fetch_currency_for_symbol(symbol)
      # Cache currency lookups
      cache_key = "finnhub:currency:#{symbol}"
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?

      begin
        response = client.get("/api/v1/stock/profile2", symbol: symbol)
        parsed = JSON.parse(response.body)
        currency = parsed["currency"] || "USD"
        Rails.cache.write(cache_key, currency, expires_in: 7.days)
        currency
      rescue => e
        Rails.logger.warn("Failed to fetch currency for #{symbol}: #{e.message}")
        "USD"
      end
    end
end
