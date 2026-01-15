class Provider::Registry
  include ActiveModel::Validations

  Error = Class.new(StandardError)

  CONCEPTS = %i[exchange_rates securities llm]

  validates :concept, inclusion: { in: CONCEPTS }

  class << self
    def for_concept(concept)
      new(concept.to_sym)
    end

    def get_provider(name)
      send(name)
    rescue NoMethodError
      raise Error.new("Provider '#{name}' not found in registry")
    end

    def plaid_provider_for_region(region)
      region.to_sym == :us ? plaid_us : plaid_eu
    end

    private
      def stripe
        secret_key = ENV["STRIPE_SECRET_KEY"]
        webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

        return nil unless secret_key.present? && webhook_secret.present?

        Provider::Stripe.new(secret_key:, webhook_secret:)
      end

      def synth
        api_key = ENV["SYNTH_API_KEY"].presence || Setting.synth_api_key

        return nil unless api_key.present?

        Provider::Synth.new(api_key)
      end

      def plaid_us
        config = Rails.application.config.plaid

        return nil unless config.present?

        Provider::Plaid.new(config, region: :us)
      end

      def plaid_eu
        config = Rails.application.config.plaid_eu

        return nil unless config.present?

        Provider::Plaid.new(config, region: :eu)
      end

      def github
        Provider::Github.new
      end

      def openai
        access_token = ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token

        return nil unless access_token.present?

        Provider::Openai.new(access_token)
      end

      def anthropic
        api_key = ENV["ANTHROPIC_API_KEY"].presence || Setting.anthropic_api_key

        return nil unless api_key.present?

        Provider::Anthropic.new(api_key)
      end

      def exchangerate_api
        api_key = ENV["EXCHANGERATE_API_KEY"].presence || Setting.exchangerate_api_key

        return nil unless api_key.present?

        Provider::ExchangeRateApi.new(api_key)
      end

      def finnhub
        api_key = ENV["FINNHUB_API_KEY"].presence || Setting.finnhub_api_key

        return nil unless api_key.present?

        Provider::Finnhub.new(api_key)
      end

      def alpha_vantage
        api_key = ENV["ALPHA_VANTAGE_API_KEY"].presence || Setting.alpha_vantage_api_key

        return nil unless api_key.present?

        Provider::AlphaVantage.new(api_key)
      end

      def crypto_compare
        api_key = ENV["CRYPTO_COMPARE_API_KEY"].presence || Setting.crypto_compare_api_key

        return nil unless api_key.present?

        Provider::CryptoCompare.new(api_key)
      end
  end

  def initialize(concept)
    @concept = concept
    validate!
  end

  def providers
    available_providers.map { |p| self.class.send(p) }
  end

  def get_provider(name)
    provider_method = available_providers.find { |p| p == name.to_sym }

    raise Error.new("Provider '#{name}' not found for concept: #{concept}") unless provider_method.present?

    self.class.send(provider_method)
  end

  private
    attr_reader :concept

    def available_providers
      case concept
      when :exchange_rates
        %i[synth exchangerate_api alpha_vantage crypto_compare]
      when :securities
        %i[synth finnhub alpha_vantage]
      when :llm
        %i[openai anthropic]
      else
        %i[synth finnhub plaid_us plaid_eu github openai anthropic exchangerate_api alpha_vantage crypto_compare]
      end
    end
end
