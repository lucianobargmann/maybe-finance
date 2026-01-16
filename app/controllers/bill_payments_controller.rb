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

    respond_to do |format|
      format.html { redirect_to recurring_bills_path, notice: t("bill_payments.notices.transaction_added") }
      format.turbo_stream do
        flash.now[:notice] = t("bill_payments.notices.transaction_added")
        render turbo_stream: bill_payment_turbo_streams
      end
    end
  end

  def unmatch
    if params[:transaction_id].present?
      transaction = Current.family.transactions.find(params[:transaction_id])
      @bill_payment.remove_transaction!(transaction)
      notice = t("bill_payments.notices.transaction_removed")
    else
      # Remove all transactions
      @bill_payment.bill_payment_transactions.destroy_all
      @bill_payment.recalculate_totals!
      notice = t("bill_payments.notices.unmatched")
    end

    respond_to do |format|
      format.html { redirect_to recurring_bills_path, notice: notice }
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: bill_payment_turbo_streams
      end
    end
  end

  def skip
    @bill_payment.update!(status: :skipped)

    respond_to do |format|
      format.html { redirect_to recurring_bills_path, notice: t("bill_payments.notices.skipped") }
      format.turbo_stream do
        flash.now[:notice] = t("bill_payments.notices.skipped")
        render turbo_stream: bill_payment_turbo_streams
      end
    end
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

    def bill_payment_turbo_streams
      month = @bill_payment.due_date.beginning_of_month
      bill_payments = Current.family.bill_payments.for_month(month).includes(:recurring_bill)

      # Calculate summary
      pending_payments = bill_payments.select { |p| p.pending? || p.overdue? }
      paid_payments = bill_payments.select(&:paid?)
      summary = {
        to_pay: pending_payments.sum { |p| p.expected_amount_money },
        paid: paid_payments.sum { |p| p.actual_amount_money || p.expected_amount_money },
        pending_count: pending_payments.count,
        paid_count: paid_payments.count
      }

      [
        turbo_stream.update("bill_payments_list", partial: "recurring_bills/list", locals: { bill_payments: bill_payments }),
        turbo_stream.update("bill_summary", partial: "recurring_bills/summary", locals: { summary: summary, month: month }),
        turbo_stream.update("modal", ""),
        *flash_notification_stream_items
      ]
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
