class CreditCard < ApplicationRecord
  include Accountable

  SUBTYPE_KEYS = %w[credit_card].freeze

  def self.subtypes
    SUBTYPE_KEYS.index_with do |key|
      {
        short: I18n.t("credit_card.subtypes.#{key}.short"),
        long: I18n.t("credit_card.subtypes.#{key}.long")
      }
    end
  end

  # For backwards compatibility
  SUBTYPES = SUBTYPE_KEYS.index_with do |key|
    {
      short: I18n.t("credit_card.subtypes.#{key}.short", locale: :en),
      long: I18n.t("credit_card.subtypes.#{key}.long", locale: :en)
    }
  end.freeze

  class << self
    def color
      "#F13636"
    end

    def icon
      "credit-card"
    end

    def classification
      "liability"
    end
  end

  def available_credit_money
    available_credit ? Money.new(available_credit, account.currency) : nil
  end

  def minimum_payment_money
    minimum_payment ? Money.new(minimum_payment, account.currency) : nil
  end

  def annual_fee_money
    annual_fee ? Money.new(annual_fee, account.currency) : nil
  end
end
