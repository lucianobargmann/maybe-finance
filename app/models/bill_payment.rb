class BillPayment < ApplicationRecord
  include Monetizable

  belongs_to :recurring_bill

  has_many :bill_payment_transactions, dependent: :destroy
  has_many :matched_transactions, through: :bill_payment_transactions, source: :linked_transaction
  has_many :rejected_bill_matches, dependent: :destroy

  monetize :expected_amount, :actual_amount

  validates :due_date, presence: true
  validates :expected_amount, presence: true

  enum :status, { pending: "pending", paid: "paid", overdue: "overdue", skipped: "skipped" }

  scope :for_month, ->(date) { where(due_date: date.beginning_of_month..date.end_of_month) }
  scope :unpaid, -> { where(status: %i[pending overdue]) }
  scope :due_soon, ->(days = 7) { pending.where(due_date: Date.current..(Date.current + days.days)) }

  def add_transaction!(txn)
    bill_payment_transactions.find_or_create_by!(transaction: txn)
    recalculate_totals!
  end

  def remove_transaction!(txn)
    bill_payment_transactions.find_by(transaction: txn)&.destroy
    recalculate_totals!
  end

  def recalculate_totals!
    if matched_transactions.any?
      total = matched_transactions.sum { |t| t.entry.amount.abs }
      latest_date = matched_transactions.map { |t| t.entry.date }.max
      update!(
        actual_amount: total,
        status: :paid,
        paid_date: latest_date
      )
    else
      update!(
        actual_amount: nil,
        status: :pending,
        paid_date: nil
      )
    end
  end

  # Legacy method for backwards compatibility
  def mark_paid!(txn)
    add_transaction!(txn)
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
