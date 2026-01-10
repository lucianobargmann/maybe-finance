class Investment < ApplicationRecord
  include Accountable

  SUBTYPE_KEYS = %w[brokerage pension retirement 401k roth_401k 529_plan hsa mutual_fund ira roth_ira angel].freeze

  def self.subtypes
    SUBTYPE_KEYS.index_with do |key|
      {
        short: I18n.t("investment.subtypes.#{key}.short"),
        long: I18n.t("investment.subtypes.#{key}.long")
      }
    end
  end

  # For backwards compatibility
  SUBTYPES = SUBTYPE_KEYS.index_with do |key|
    {
      short: I18n.t("investment.subtypes.#{key}.short", locale: :en),
      long: I18n.t("investment.subtypes.#{key}.long", locale: :en)
    }
  end.freeze

  class << self
    def color
      "#1570EF"
    end

    def classification
      "asset"
    end

    def icon
      "line-chart"
    end
  end
end
