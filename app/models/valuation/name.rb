class Valuation::Name
  def initialize(valuation_kind, accountable_type)
    @valuation_kind = valuation_kind
    @accountable_type = accountable_type
  end

  def to_s
    type_key = accountable_type.underscore
    I18n.t(
      "valuation.names.#{valuation_kind}.#{type_key}",
      default: I18n.t("valuation.names.#{valuation_kind}.default")
    )
  end

  private
    attr_reader :valuation_kind, :accountable_type
end
