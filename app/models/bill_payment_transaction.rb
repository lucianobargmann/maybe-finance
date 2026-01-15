class BillPaymentTransaction < ApplicationRecord
  belongs_to :bill_payment
  belongs_to :linked_transaction, class_name: "Transaction", foreign_key: "transaction_id"

  validates :bill_payment_id, uniqueness: { scope: :transaction_id }
end
