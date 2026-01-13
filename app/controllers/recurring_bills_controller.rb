class RecurringBillsController < ApplicationController
  before_action :set_recurring_bill, only: %i[edit update destroy]

  def index
    @month = params[:month] ? Date.parse(params[:month]) : Date.current
    @recurring_bills = Current.family.recurring_bills.active.for_month(@month)

    @recurring_bills.each { |bill| bill.ensure_payment_for_month(@month) }

    @bill_payments = Current.family.bill_payments.for_month(@month).includes(:recurring_bill)
    @calendar_data = RecurringBill::CalendarBuilder.new(Current.family, @month).build
    @alerts = RecurringBill::AlertBuilder.new(Current.family).build
    @cashflow_projection = RecurringBill::CashflowProjection.new(Current.family).build

    # Summary data
    pending_payments = @bill_payments.select { |p| p.pending? || p.overdue? }
    paid_payments = @bill_payments.select(&:paid?)
    @summary = {
      to_pay: pending_payments.sum { |p| p.expected_amount_money },
      paid: paid_payments.sum { |p| p.actual_amount_money || p.expected_amount_money },
      pending_count: pending_payments.count,
      paid_count: paid_payments.count
    }
  end

  def new
    @recurring_bill = Current.family.recurring_bills.build(currency: Current.family.currency)

    if params[:from_transaction].present?
      transaction = Current.family.transactions.find_by(id: params[:from_transaction])
      if transaction
        @recurring_bill.name = transaction.entry.name
        @recurring_bill.expected_amount = transaction.entry.amount.abs
        @recurring_bill.currency = transaction.entry.currency
        @recurring_bill.due_day = transaction.entry.date.day
        @recurring_bill.merchant_id = transaction.merchant_id
      end
    end
  end

  def create
    @recurring_bill = Current.family.recurring_bills.build(recurring_bill_params)
    if @recurring_bill.save
      redirect_to recurring_bills_path, notice: "Bill created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recurring_bill.update(recurring_bill_params)
      redirect_to recurring_bills_path, notice: "Bill updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_bill.destroy
    redirect_to recurring_bills_path, notice: "Bill deleted"
  end

  def picker
    render partial: "recurring_bills/picker", locals: {
      family: Current.family,
      year: params[:year].to_i.nonzero? || Date.current.year
    }
  end

  private

    def set_recurring_bill
      @recurring_bill = Current.family.recurring_bills.find(params[:id])
    end

    def recurring_bill_params
      params.require(:recurring_bill).permit(
        :name, :expected_amount, :currency, :due_day,
        :merchant_id, :status, :start_date, :end_date, :notes
      )
    end
end
