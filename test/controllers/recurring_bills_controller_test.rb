require "test_helper"

class RecurringBillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @bill = recurring_bills(:electricity)
  end

  test "index" do
    get recurring_bills_url
    assert_response :success
  end

  test "index with month parameter" do
    get recurring_bills_url(month: "2025-03-01")
    assert_response :success
  end

  test "new" do
    get new_recurring_bill_url
    assert_response :success
  end

  test "create" do
    assert_difference "RecurringBill.count", 1 do
      post recurring_bills_url, params: {
        recurring_bill: {
          name: "New Bill",
          expected_amount: 100.00,
          currency: "USD",
          due_day: 15,
          status: "active"
        }
      }
    end

    assert_redirected_to recurring_bills_url
  end

  test "create fails with invalid params" do
    assert_no_difference "RecurringBill.count" do
      post recurring_bills_url, params: {
        recurring_bill: {
          name: "",
          expected_amount: 0,
          currency: "USD",
          due_day: 15
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "edit" do
    get edit_recurring_bill_url(@bill)
    assert_response :success
  end

  test "update" do
    patch recurring_bill_url(@bill), params: {
      recurring_bill: {
        name: "Updated Bill Name",
        expected_amount: 200.00
      }
    }

    assert_redirected_to recurring_bills_url
    @bill.reload
    assert_equal "Updated Bill Name", @bill.name
    assert_equal 200.00, @bill.expected_amount
  end

  test "destroy" do
    assert_difference "RecurringBill.count", -1 do
      delete recurring_bill_url(@bill)
    end

    assert_redirected_to recurring_bills_url
  end

  test "picker" do
    get picker_recurring_bills_url(year: 2025)
    assert_response :success
  end
end
