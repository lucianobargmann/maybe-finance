class Merchant::DropdownsController < ApplicationController
  before_action :set_from_params

  def show
    @merchants = merchants_scope.to_a.excluding(@selected_merchant).prepend(@selected_merchant).compact
  end

  private
    def set_from_params
      if params[:merchant_id]
        @selected_merchant = merchants_scope.find(params[:merchant_id])
      end

      if params[:transaction_id]
        @transaction = Current.family.transactions.find(params[:transaction_id])
      end
    end

    def merchants_scope
      Current.family.merchants.alphabetically
    end
end
