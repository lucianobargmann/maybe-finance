class AddMultiTransactionToBillPayments < ActiveRecord::Migration[7.2]
  def change
    create_table :bill_payment_transactions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :bill_payment, null: false, foreign_key: true, type: :uuid
      t.references :transaction, null: false, foreign_key: true, type: :uuid
      t.timestamps

      t.index %i[bill_payment_id transaction_id], unique: true, name: "idx_bill_payment_transactions_unique"
    end

    # Migrate existing transaction_id data to the new join table
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO bill_payment_transactions (id, bill_payment_id, transaction_id, created_at, updated_at)
          SELECT gen_random_uuid(), id, transaction_id, NOW(), NOW()
          FROM bill_payments
          WHERE transaction_id IS NOT NULL
        SQL
      end
    end

    # Remove the transaction_id column from bill_payments
    remove_index :bill_payments, name: "index_bill_payments_on_transaction_id_unique", if_exists: true
    remove_reference :bill_payments, :transaction, foreign_key: true, type: :uuid
  end
end
