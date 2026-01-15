require "test_helper"

class RecurringBillTest < ActiveSupport::TestCase
  setup do
    @bill = recurring_bills(:electricity)
  end

  test "validates presence of name" do
    @bill.name = nil
    assert_not @bill.valid?
    assert_includes @bill.errors[:name], "can't be blank"
  end

  test "validates presence of expected_amount" do
    @bill.expected_amount = nil
    assert_not @bill.valid?
  end

  test "validates expected_amount is greater than zero" do
    @bill.expected_amount = 0
    assert_not @bill.valid?

    @bill.expected_amount = -10
    assert_not @bill.valid?

    @bill.expected_amount = 100
    assert @bill.valid?
  end

  test "validates due_day is between 1 and 31" do
    @bill.due_day = 0
    assert_not @bill.valid?

    @bill.due_day = 32
    assert_not @bill.valid?

    @bill.due_day = 15
    assert @bill.valid?
  end

  test "due_date_for_month handles months with fewer days" do
    @bill.due_day = 31

    # February (non-leap year)
    feb_date = Date.new(2025, 2, 1)
    assert_equal Date.new(2025, 2, 28), @bill.due_date_for_month(feb_date)

    # April (30 days)
    apr_date = Date.new(2025, 4, 1)
    assert_equal Date.new(2025, 4, 30), @bill.due_date_for_month(apr_date)

    # January (31 days)
    jan_date = Date.new(2025, 1, 1)
    assert_equal Date.new(2025, 1, 31), @bill.due_date_for_month(jan_date)
  end

  test "ensure_payment_for_month creates payment if not exists" do
    month = Date.current + 2.months
    assert_difference "@bill.bill_payments.count", 1 do
      payment = @bill.ensure_payment_for_month(month)
      assert_equal @bill.due_date_for_month(month), payment.due_date
      assert_equal @bill.expected_amount, payment.expected_amount
      assert_equal @bill.currency, payment.currency
    end
  end

  test "ensure_payment_for_month returns existing payment" do
    month = Date.current
    existing = @bill.ensure_payment_for_month(month)

    assert_no_difference "@bill.bill_payments.count" do
      returned = @bill.ensure_payment_for_month(month)
      assert_equal existing.id, returned.id
    end
  end

  test "active scope returns only active bills" do
    active_bills = RecurringBill.active
    assert active_bills.include?(recurring_bills(:electricity))
    assert active_bills.include?(recurring_bills(:internet))
    assert_not active_bills.include?(recurring_bills(:car_insurance))
  end

  test "for_month scope filters by start and end dates" do
    @bill.update!(start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 6, 30))

    assert RecurringBill.for_month(Date.new(2025, 4, 1)).include?(@bill)
    assert_not RecurringBill.for_month(Date.new(2025, 1, 1)).include?(@bill)
    assert_not RecurringBill.for_month(Date.new(2025, 8, 1)).include?(@bill)
  end
end
