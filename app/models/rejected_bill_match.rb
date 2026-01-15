class RejectedBillMatch < ApplicationRecord
  belongs_to :bill_payment
  belongs_to :rejected_transaction, class_name: "Transaction", foreign_key: "transaction_id"
end
