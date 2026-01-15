class BillPayment < ApplicationRecord
  include Monetizable

  belongs_to :recurring_bill
  belongs_to :matched_transaction, class_name: "Transaction", foreign_key: "transaction_id", optional: true

  has_many :rejected_bill_matches, dependent: :destroy

  monetize :expected_amount, :actual_amount

  validates :due_date, presence: true
  validates :expected_amount, presence: true

  enum :status, { pending: "pending", paid: "paid", overdue: "overdue", skipped: "skipped" }

  scope :for_month, ->(date) { where(due_date: date.beginning_of_month..date.end_of_month) }
  scope :unpaid, -> { where(status: %i[pending overdue]) }
  scope :due_soon, ->(days = 7) { pending.where(due_date: Date.current..(Date.current + days.days)) }

  def mark_paid!(txn)
    update!(
      matched_transaction: txn,
      actual_amount: txn.entry.amount.abs,
      status: :paid,
      paid_date: txn.entry.date
    )
  end

  def alert_level
    return nil if paid? || skipped?
    return :error if overdue? || due_date <= Date.current
    return :warning if due_date <= Date.current + 7.days
    nil
  end

  def family
    recurring_bill.family
  end
end
