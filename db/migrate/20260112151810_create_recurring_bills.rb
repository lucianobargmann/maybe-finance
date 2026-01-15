class CreateRecurringBills < ActiveRecord::Migration[7.2]
  def change
    create_table :recurring_bills, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :merchant, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :expected_amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.integer :due_day, null: false
      t.string :status, default: "active", null: false
      t.date :start_date
      t.date :end_date
      t.text :notes
      t.timestamps

      t.index %i[family_id status]
      t.index %i[family_id due_day]
    end

    create_table :bill_payments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :recurring_bill, null: false, foreign_key: true, type: :uuid
      t.references :transaction, foreign_key: true, type: :uuid, index: false
      t.date :due_date, null: false
      t.decimal :expected_amount, precision: 19, scale: 4, null: false
      t.decimal :actual_amount, precision: 19, scale: 4
      t.string :currency, null: false
      t.string :status, default: "pending", null: false
      t.date :paid_date
      t.timestamps

      t.index %i[recurring_bill_id due_date], unique: true
      t.index :due_date
      t.index :status
      t.index :transaction_id, unique: true, where: "transaction_id IS NOT NULL", name: "index_bill_payments_on_transaction_id_unique"
    end

    create_table :rejected_bill_matches, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :bill_payment, null: false, foreign_key: true, type: :uuid
      t.references :transaction, null: false, foreign_key: true, type: :uuid
      t.timestamps

      t.index %i[bill_payment_id transaction_id], unique: true
    end
  end
end
