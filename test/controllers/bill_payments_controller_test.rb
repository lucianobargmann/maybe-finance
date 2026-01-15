require "test_helper"

class BillPaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @payment = bill_payments(:electricity_jan)
  end

  test "show" do
    get bill_payment_url(@payment)
    assert_response :success
  end

  test "skip marks payment as skipped" do
    post skip_bill_payment_url(@payment)

    assert_redirected_to recurring_bills_url
    @payment.reload
    assert @payment.skipped?
  end

  test "unmatch clears transaction and resets to pending" do
    paid_payment = bill_payments(:internet_jan)
    assert paid_payment.paid?

    post unmatch_bill_payment_url(paid_payment)

    assert_redirected_to recurring_bills_url
    paid_payment.reload
    assert paid_payment.pending?
    assert_nil paid_payment.transaction_id
    assert_nil paid_payment.actual_amount
  end
end
