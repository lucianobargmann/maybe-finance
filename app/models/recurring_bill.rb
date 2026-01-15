class RecurringBill < ApplicationRecord
  include Monetizable

  belongs_to :family
  belongs_to :merchant, optional: true

  has_many :bill_payments, dependent: :destroy

  monetize :expected_amount

  validates :name, presence: true
  validates :expected_amount, presence: true, numericality: { greater_than: 0 }
  validates :due_day, presence: true, inclusion: { in: 1..31 }
  validates :currency, presence: true

  enum :status, { active: "active", paused: "paused", cancelled: "cancelled" }

  scope :active, -> { where(status: "active") }
  scope :for_month, ->(date) {
    where("start_date IS NULL OR start_date <= ?", date.end_of_month)
      .where("end_date IS NULL OR end_date >= ?", date.beginning_of_month)
  }

  def due_date_for_month(date)
    day = [ due_day, date.end_of_month.day ].min
    Date.new(date.year, date.month, day)
  end

  def ensure_payment_for_month(date)
    due_date = due_date_for_month(date)
    bill_payments.find_or_create_by!(due_date: due_date) do |payment|
      payment.expected_amount = expected_amount
      payment.currency = currency
    end
  end
end
