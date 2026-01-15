class BillStatusUpdaterJob < ApplicationJob
  queue_as :low_priority

  def perform
    Family.find_each do |family|
      # Update overdue status for pending bills past their due date
      family.bill_payments.pending.where("due_date < ?", Date.current).update_all(status: :overdue)

      # Ensure current month payments exist for all active bills
      family.recurring_bills.active.find_each do |bill|
        bill.ensure_payment_for_month(Date.current)
      end

      # Try to auto-match unpaid bills with transactions
      family.auto_match_bills!
    end
  end
end
