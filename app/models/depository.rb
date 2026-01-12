class Depository < ApplicationRecord
  include Accountable

  SUBTYPE_KEYS = %w[checking savings hsa cd money_market].freeze

  def self.subtypes
    SUBTYPE_KEYS.index_with do |key|
      {
        short: I18n.t("depository.subtypes.#{key}.short"),
        long: I18n.t("depository.subtypes.#{key}.long")
      }
    end
  end

  # For backwards compatibility
  SUBTYPES = SUBTYPE_KEYS.index_with do |key|
    {
      short: I18n.t("depository.subtypes.#{key}.short", locale: :en),
      long: I18n.t("depository.subtypes.#{key}.long", locale: :en)
    }
  end.freeze

  class << self
    def color
      "#875BF7"
    end

    def classification
      "asset"
    end

    def icon
      "landmark"
    end
  end
end
