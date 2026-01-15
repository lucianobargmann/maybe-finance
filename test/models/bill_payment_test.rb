require "test_helper"

class BillPaymentTest < ActiveSupport::TestCase
  setup do
    @payment = bill_payments(:electricity_jan)
  end

  test "validates presence of due_date" do
    @payment.due_date = nil
    assert_not @payment.valid?
  end

  test "validates presence of expected_amount" do
    @payment.expected_amount = nil
    assert_not @payment.valid?
  end

  test "alert_level returns nil for paid payments" do
    @payment.status = :paid
    assert_nil @payment.alert_level
  end

  test "alert_level returns nil for skipped payments" do
    @payment.status = :skipped
    assert_nil @payment.alert_level
  end

  test "alert_level returns error for overdue payments" do
    @payment.status = :overdue
    assert_equal :error, @payment.alert_level
  end

  test "alert_level returns error for pending payments due today" do
    @payment.status = :pending
    @payment.due_date = Date.current
    assert_equal :error, @payment.alert_level
  end

  test "alert_level returns warning for pending payments due within 7 days" do
    @payment.status = :pending
    @payment.due_date = Date.current + 3.days
    assert_equal :warning, @payment.alert_level
  end

  test "alert_level returns nil for pending payments more than 7 days out" do
    @payment.status = :pending
    @payment.due_date = Date.current + 10.days
    assert_nil @payment.alert_level
  end

  test "for_month scope returns payments for given month" do
    month = Date.current
    payments = BillPayment.for_month(month)
    assert payments.any?
    payments.each do |payment|
      assert_equal month.month, payment.due_date.month
    end
  end

  test "unpaid scope returns pending and overdue payments" do
    unpaid = BillPayment.unpaid
    unpaid.each do |payment|
      assert payment.pending? || payment.overdue?
    end
  end

  test "due_soon scope returns pending payments due within specified days" do
    @payment.update!(status: :pending, due_date: Date.current + 3.days)
    assert BillPayment.due_soon(7).include?(@payment)

    @payment.update!(due_date: Date.current + 10.days)
    assert_not BillPayment.due_soon(7).include?(@payment)
  end
end
