class FamilyMerchantsController < ApplicationController
  before_action :set_merchant, only: %i[show edit update destroy]
  before_action :set_transaction, only: :create

  def index
    @breadcrumbs = [ [ I18n.t("breadcrumbs.home"), root_path ], [ I18n.t("breadcrumbs.merchants"), nil ] ]

    @family_merchants = Current.family.merchants.alphabetically

    render layout: "settings"
  end

  def show
    @breadcrumbs = [
      [ I18n.t("breadcrumbs.home"), root_path ],
      [ I18n.t("breadcrumbs.merchants"), family_merchants_path ],
      [ @family_merchant.name, nil ]
    ]

    @transactions = Current.family.transactions
      .where(merchant_id: @family_merchant.id)
      .includes(:entry)
      .order("entries.date DESC")
      .limit(100)

    render layout: "settings"
  end

  def new
    @family_merchant = FamilyMerchant.new(family: Current.family)
  end

  def create
    @family_merchant = FamilyMerchant.new(merchant_params.merge(family: Current.family))

    if @family_merchant.save
      @transaction.update(merchant_id: @family_merchant.id) if @transaction

      flash[:notice] = t(".success")

      redirect_target_url = request.referer || family_merchants_path
      respond_to do |format|
        format.html { redirect_back_or_to family_merchants_path, notice: t(".success") }
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, redirect_target_url) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @family_merchant.update!(merchant_params)
    respond_to do |format|
      format.html { redirect_to family_merchants_path, notice: t(".success") }
      format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, family_merchants_path) }
    end
  end

  def destroy
    @family_merchant.destroy!
    redirect_to family_merchants_path, notice: t(".success")
  end

  private
    def set_merchant
      @family_merchant = Current.family.merchants.find(params[:id])
    end

    def set_transaction
      if params[:transaction_id].present?
        @transaction = Current.family.transactions.find(params[:transaction_id])
      end
    end

    def merchant_params
      params.require(:family_merchant).permit(:name, :color)
    end
end
