class BillPaymentsController < ApplicationController
  before_action :set_bill_payment, only: %i[show update match unmatch skip]

  def show
    @match_candidates = Current.family.bill_match_candidates(@bill_payment)
  end

  def update
    if @bill_payment.update(bill_payment_params)
      redirect_back fallback_location: recurring_bills_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  def match
    transaction = Current.family.transactions.find(params[:transaction_id])
    @bill_payment.mark_paid!(transaction)
    redirect_to recurring_bills_path, notice: t("bill_payments.notices.marked_paid")
  end

  def unmatch
    @bill_payment.update!(matched_transaction: nil, actual_amount: nil, status: :pending, paid_date: nil)
    redirect_to recurring_bills_path, notice: t("bill_payments.notices.unmatched")
  end

  def skip
    @bill_payment.update!(status: :skipped)
    redirect_to recurring_bills_path, notice: t("bill_payments.notices.skipped")
  end

  def reject_match
    bill_payment = Current.family.bill_payments.find(params[:bill_payment_id])
    txn = Current.family.transactions.find(params[:transaction_id])
    RejectedBillMatch.create!(bill_payment: bill_payment, rejected_transaction: txn)
    redirect_back fallback_location: recurring_bills_path
  end

  private

    def set_bill_payment
      @bill_payment = Current.family.bill_payments.find(params[:id])
    end

    def bill_payment_params
      params.require(:bill_payment).permit(:status)
    end
end
