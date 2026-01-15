module Family::AutoBillMatchable
  extend ActiveSupport::Concern

  def bill_payments
    BillPayment.joins(:recurring_bill).where(recurring_bills: { family_id: id })
  end

  def bill_match_candidates(bill_payment)
    due_date = bill_payment.due_date
    expected_amount = bill_payment.expected_amount
    recurring_bill = bill_payment.recurring_bill

    min_amount = expected_amount * 0.80
    max_amount = expected_amount * 1.20
    date_start = due_date - 7.days
    date_end = due_date + 7.days

    candidates = transactions
      .visible
      .joins(:entry)
      .where(entries: { date: date_start..date_end })
      .where("entries.amount > 0") # Expenses are positive amounts
      .where("entries.amount BETWEEN ? AND ?", min_amount, max_amount)
      .where.not(id: BillPaymentTransaction.select(:transaction_id))
      .where.not(id: RejectedBillMatch.where(bill_payment_id: bill_payment.id).select(:transaction_id))

    if recurring_bill.merchant_id.present?
      candidates = candidates.where(merchant_id: recurring_bill.merchant_id)
    end

    candidates.order(Arel.sql("ABS(entries.date - '#{due_date}'::date)"))
  end

  def auto_match_bills!
    ActiveRecord::Base.transaction do
      bill_payments.unpaid.includes(:recurring_bill).find_each do |payment|
        candidates = bill_match_candidates(payment)
        payment.mark_paid!(candidates.first) if candidates.any?
      end
    end
  end
end
