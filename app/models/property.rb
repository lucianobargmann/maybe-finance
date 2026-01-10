class Property < ApplicationRecord
  include Accountable

  SUBTYPE_KEYS = %w[single_family_home multi_family_home condominium townhouse investment_property second_home].freeze

  def self.subtypes
    SUBTYPE_KEYS.index_with do |key|
      {
        short: I18n.t("property.subtypes.#{key}.short"),
        long: I18n.t("property.subtypes.#{key}.long")
      }
    end
  end

  # For backwards compatibility
  SUBTYPES = SUBTYPE_KEYS.index_with do |key|
    {
      short: I18n.t("property.subtypes.#{key}.short", locale: :en),
      long: I18n.t("property.subtypes.#{key}.long", locale: :en)
    }
  end.freeze

  has_one :address, as: :addressable, dependent: :destroy

  accepts_nested_attributes_for :address

  attribute :area_unit, :string, default: "sqft"

  class << self
    def icon
      "home"
    end

    def color
      "#06AED4"
    end

    def classification
      "asset"
    end
  end

  def area
    Measurement.new(area_value, area_unit) if area_value.present?
  end

  def purchase_price
    first_valuation_amount
  end

  def trend
    Trend.new(current: account.balance_money, previous: first_valuation_amount)
  end

  def balance_display_name
    "market value"
  end

  def opening_balance_display_name
    "original purchase price"
  end

  private
    def first_valuation_amount
      account.entries.valuations.order(:date).first&.amount_money || account.balance_money
    end
end
