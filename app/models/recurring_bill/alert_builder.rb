class RecurringBill::AlertBuilder
  def initialize(family)
    @family = family
    @today = Time.current.in_time_zone(family.timezone).to_date
  end

  def build
    # Alerts should always be relative to TODAY, regardless of which month is being viewed
    {
      overdue: @family.bill_payments.overdue.where("due_date < ?", @today).includes(:recurring_bill),
      due_today: @family.bill_payments.pending.where(due_date: @today).includes(:recurring_bill),
      due_soon: @family.bill_payments.pending.where(due_date: (@today + 1.day)..(@today + 7.days)).includes(:recurring_bill)
    }
  end
end
