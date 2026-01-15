class RecurringBill::CashflowProjection
  PROJECTION_MONTHS = 12

  def initialize(family)
    @family = family
  end

  def build
    estimated_income = @family.income_statement.median_income(interval: "month")

    PROJECTION_MONTHS.times.map do |i|
      month = Date.current + i.months
      month_start = month.beginning_of_month

      bills = @family.recurring_bills.active.for_month(month_start)
      total_bills = bills.sum(:expected_amount)

      {
        month: month_start,
        month_name: month_start.strftime("%b %Y"),
        total_bills: total_bills,
        estimated_income: estimated_income,
        net_cashflow: estimated_income - total_bills,
        bills_count: bills.count
      }
    end
  end
end
