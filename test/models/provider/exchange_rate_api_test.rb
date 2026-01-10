require "test_helper"

class Provider::ExchangeRateApiTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest

  setup do
    @subject = Provider::ExchangeRateApi.new("test_api_key")
  end

  test "initializes with api key" do
    provider = Provider::ExchangeRateApi.new("test_key")
    assert_equal "test_key", provider.send(:api_key)
  end

  test "healthy? returns true for successful response" do
    VCR.use_cassette("exchange_rate_api/health") do
      assert @subject.healthy?
    end
  end

  test "healthy? returns false for error response" do
    VCR.use_cassette("exchange_rate_api/health_error") do
      refute @subject.healthy?
    end
  end

  test "usage returns placeholder data" do
    usage = @subject.usage
    assert usage.success?
    assert_equal 0, usage.data.used
    assert_equal 0, usage.data.limit
    assert_equal 0.0, usage.data.utilization
    assert_equal "free", usage.data.plan
  end

  test "fetch_exchange_rate raises error for historical dates" do
    assert_raises(Provider::ExchangeRateApi::InvalidExchangeRateError) do
      @subject.fetch_exchange_rate(from: "USD", to: "EUR", date: 1.day.ago.to_date)
    end
  end

  test "fetch_exchange_rate handles invalid API key" do
    provider = Provider::ExchangeRateApi.new("invalid_key")
    
    VCR.use_cassette("exchange_rate_api/invalid_key") do
      response = provider.fetch_exchange_rate(from: "USD", to: "EUR", date: Date.current)
      
      refute response.success?
      assert_instance_of Provider::ExchangeRateApi::InvalidApiKeyError, response.error
    end
  end

  test "fetch_exchange_rate handles quota reached" do
    provider = Provider::ExchangeRateApi.new("quota_exceeded_key")
    
    VCR.use_cassette("exchange_rate_api/quota_reached") do
      response = provider.fetch_exchange_rate(from: "USD", to: "EUR", date: Date.current)
      
      refute response.success?
      assert_instance_of Provider::ExchangeRateApi::QuotaReachedError, response.error
    end
  end

  test "fetch_exchange_rate handles unsupported currency" do
    VCR.use_cassette("exchange_rate_api/unsupported_currency") do
      response = @subject.fetch_exchange_rate(from: "USD", to: "INVALID", date: Date.current)
      
      refute response.success?
      assert_instance_of Provider::ExchangeRateApi::InvalidExchangeRateError, response.error
    end
  end

  test "fetch_exchange_rates warns about historical data limitation" do
    Rails.logger.expects(:warn).with(regexp_matches(/ExchangeRate-API only provides current rates/))
    
    VCR.use_cassette("exchange_rate_api/exchange_rates") do
      response = @subject.fetch_exchange_rates(
        from: "USD", 
        to: "EUR", 
        start_date: 1.week.ago.to_date, 
        end_date: Date.current
      )
      
      assert response.success?
      assert_equal 1, response.data.count
    end
  end

  private
    def vcr_key_prefix
      "exchange_rate_api"
    end
end