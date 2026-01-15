class BillPaymentsController < ApplicationController
  before_action :set_bill_payment, only: %i[show update match unmatch skip]

  def show
    @match_candidates = Current.family.bill_match_candidates(@bill_payment)

    # Handle transaction search
    if params[:search].present? || params[:start_date].present? || params[:end_date].present?
      @search_results = search_transactions
      @searching = true
    end
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
    @bill_payment.add_transaction!(transaction)
    redirect_to bill_payment_path(@bill_payment), notice: t("bill_payments.notices.transaction_added")
  end

  def unmatch
    if params[:transaction_id].present?
      transaction = Current.family.transactions.find(params[:transaction_id])
      @bill_payment.remove_transaction!(transaction)
      redirect_to bill_payment_path(@bill_payment), notice: t("bill_payments.notices.transaction_removed")
    else
      # Remove all transactions
      @bill_payment.bill_payment_transactions.destroy_all
      @bill_payment.recalculate_totals!
      redirect_to recurring_bills_path, notice: t("bill_payments.notices.unmatched")
    end
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
      params.require(:bill_payment).permit(:status, :expected_amount)
    end

    def search_transactions
      scope = Current.family.transactions
        .visible
        .joins(:entry)
        .where("entries.amount > 0") # Expenses only
        .where.not(id: BillPaymentTransaction.select(:transaction_id))

      if params[:search].present?
        scope = scope.where("entries.name ILIKE ?", "%#{params[:search]}%")
      end

      if params[:start_date].present?
        scope = scope.where("entries.date >= ?", params[:start_date])
      end

      if params[:end_date].present?
        scope = scope.where("entries.date <= ?", params[:end_date])
      end

      scope.order("entries.date DESC").limit(20)
    end
end
