class Loan < ApplicationRecord
  include Accountable

  SUBTYPE_KEYS = %w[mortgage student auto other].freeze

  def self.subtypes
    SUBTYPE_KEYS.index_with do |key|
      {
        short: I18n.t("loan.subtypes.#{key}.short"),
        long: I18n.t("loan.subtypes.#{key}.long")
      }
    end
  end

  # For backwards compatibility
  SUBTYPES = SUBTYPE_KEYS.index_with do |key|
    {
      short: I18n.t("loan.subtypes.#{key}.short", locale: :en),
      long: I18n.t("loan.subtypes.#{key}.long", locale: :en)
    }
  end.freeze

  def monthly_payment
    return nil if term_months.nil? || interest_rate.nil? || rate_type.nil? || rate_type != "fixed"
    return Money.new(0, account.currency) if account.loan.original_balance.amount.zero? || term_months.zero?

    annual_rate = interest_rate / 100.0
    monthly_rate = annual_rate / 12.0

    if monthly_rate.zero?
      payment = account.loan.original_balance.amount / term_months
    else
      payment = (account.loan.original_balance.amount * monthly_rate * (1 + monthly_rate)**term_months) / ((1 + monthly_rate)**term_months - 1)
    end

    Money.new(payment.round, account.currency)
  end

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  class << self
    def color
      "#D444F1"
    end

    def icon
      "hand-coins"
    end

    def classification
      "liability"
    end
  end
end
