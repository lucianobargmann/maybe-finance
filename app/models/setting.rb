# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :synth_api_key, type: :string, default: ENV["SYNTH_API_KEY"]
  field :finnhub_api_key, type: :string, default: ENV["FINNHUB_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :anthropic_api_key, type: :string, default: ENV["ANTHROPIC_API_KEY"]
  field :exchangerate_api_key, type: :string, default: ENV["EXCHANGERATE_API_KEY"]
  field :alpha_vantage_api_key, type: :string, default: ENV["ALPHA_VANTAGE_API_KEY"]
  field :crypto_compare_api_key, type: :string, default: ENV["CRYPTO_COMPARE_API_KEY"]
  field :exchange_rate_provider, type: :string, default: "exchangerate_api"
  field :security_provider, type: :string, default: "finnhub"
  field :llm_provider, type: :string, default: "anthropic"
  field :llm_model, type: :string, default: "claude-sonnet-4-20250514"

  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
