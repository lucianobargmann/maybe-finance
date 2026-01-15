class RecurringBill::CalendarBuilder
  def initialize(family, month)
    @family = family
    @month = month
  end

  def build
    days = {}

    @family.bill_payments.for_month(@month).includes(:recurring_bill).each do |payment|
      day = payment.due_date.day
      days[day] ||= []
      days[day] << {
        id: payment.id,
        name: payment.recurring_bill.name,
        amount: payment.expected_amount,
        status: payment.status,
        alert_level: payment.alert_level
      }
    end

    days
  end
end
