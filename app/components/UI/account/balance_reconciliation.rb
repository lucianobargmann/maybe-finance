class UI::Account::BalanceReconciliation < ApplicationComponent
  attr_reader :balance, :account

  def initialize(balance:, account:)
    @balance = balance
    @account = account
  end

  def reconciliation_items
    case account.accountable_type
    when "Depository", "OtherAsset", "OtherLiability"
      default_items
    when "CreditCard"
      credit_card_items
    when "Investment"
      investment_items
    when "Loan"
      loan_items
    when "Property", "Vehicle"
      asset_items
    when "Crypto"
      crypto_items
    else
      default_items
    end
  end

  private

    def default_items
      items = [
        { label: t(".start_balance"), value: balance.start_balance_money, tooltip: t(".start_balance_tooltip"), style: :start },
        { label: t(".net_cash_flow"), value: net_cash_flow, tooltip: t(".net_cash_flow_tooltip"), style: :flow }
      ]

      if has_adjustments?
        items << { label: t(".end_balance"), value: end_balance_before_adjustments, tooltip: t(".end_balance_tooltip"), style: :subtotal }
        items << { label: t(".adjustments"), value: total_adjustments, tooltip: t(".adjustments_tooltip"), style: :adjustment }
      end

      items << { label: t(".final_balance"), value: balance.end_balance_money, tooltip: t(".final_balance_tooltip"), style: :final }
      items
    end

    def credit_card_items
      items = [
        { label: t(".start_balance"), value: balance.start_balance_money, tooltip: t(".credit_card_start_tooltip"), style: :start },
        { label: t(".charges"), value: balance.cash_outflows_money, tooltip: t(".charges_tooltip"), style: :flow },
        { label: t(".payments"), value: balance.cash_inflows_money * -1, tooltip: t(".payments_tooltip"), style: :flow }
      ]

      if has_adjustments?
        items << { label: t(".end_balance"), value: end_balance_before_adjustments, tooltip: t(".end_balance_tooltip"), style: :subtotal }
        items << { label: t(".adjustments"), value: total_adjustments, tooltip: t(".adjustments_tooltip"), style: :adjustment }
      end

      items << { label: t(".final_balance"), value: balance.end_balance_money, tooltip: t(".credit_card_final_tooltip"), style: :final }
      items
    end

    def investment_items
      items = [
        { label: t(".start_balance"), value: balance.start_balance_money, tooltip: t(".investment_start_tooltip"), style: :start }
      ]

      # Change in brokerage cash (includes deposits, withdrawals, and cash from trades)
      items << { label: t(".change_in_brokerage_cash"), value: net_cash_flow, tooltip: t(".change_in_brokerage_cash_tooltip"), style: :flow }

      # Change in holdings from trading activity
      items << { label: t(".change_in_holdings_trades"), value: net_non_cash_flow, tooltip: t(".change_in_holdings_trades_tooltip"), style: :flow }

      # Market price changes
      items << { label: t(".change_in_holdings_market"), value: balance.net_market_flows_money, tooltip: t(".change_in_holdings_market_tooltip"), style: :flow }

      if has_adjustments?
        items << { label: t(".end_balance"), value: end_balance_before_adjustments, tooltip: t(".investment_end_tooltip"), style: :subtotal }
        items << { label: t(".adjustments"), value: total_adjustments, tooltip: t(".adjustments_tooltip"), style: :adjustment }
      end

      items << { label: t(".final_balance"), value: balance.end_balance_money, tooltip: t(".investment_final_tooltip"), style: :final }
      items
    end

    def loan_items
      items = [
        { label: t(".start_principal"), value: balance.start_balance_money, tooltip: t(".start_principal_tooltip"), style: :start },
        { label: t(".net_principal_change"), value: net_non_cash_flow, tooltip: t(".net_principal_change_tooltip"), style: :flow }
      ]

      if has_adjustments?
        items << { label: t(".end_principal"), value: end_balance_before_adjustments, tooltip: t(".end_principal_tooltip"), style: :subtotal }
        items << { label: t(".adjustments"), value: balance.non_cash_adjustments_money, tooltip: t(".loan_adjustments_tooltip"), style: :adjustment }
      end

      items << { label: t(".final_principal"), value: balance.end_balance_money, tooltip: t(".final_principal_tooltip"), style: :final }
      items
    end

    def asset_items # Property/Vehicle
      items = [
        { label: t(".start_value"), value: balance.start_balance_money, tooltip: t(".start_value_tooltip"), style: :start },
        { label: t(".net_value_change"), value: net_total_flow, tooltip: t(".net_value_change_tooltip"), style: :flow }
      ]

      if has_adjustments?
        items << { label: t(".end_value"), value: end_balance_before_adjustments, tooltip: t(".end_value_tooltip"), style: :subtotal }
        items << { label: t(".adjustments"), value: total_adjustments, tooltip: t(".asset_adjustments_tooltip"), style: :adjustment }
      end

      items << { label: t(".final_value"), value: balance.end_balance_money, tooltip: t(".final_value_tooltip"), style: :final }
      items
    end

    def crypto_items
      items = [
        { label: t(".start_balance"), value: balance.start_balance_money, tooltip: t(".crypto_start_tooltip"), style: :start }
      ]

      items << { label: t(".buys"), value: balance.cash_outflows_money * -1, tooltip: t(".buys_tooltip"), style: :flow } if balance.cash_outflows != 0
      items << { label: t(".sells"), value: balance.cash_inflows_money, tooltip: t(".sells_tooltip"), style: :flow } if balance.cash_inflows != 0
      items << { label: t(".market_changes"), value: balance.net_market_flows_money, tooltip: t(".market_changes_tooltip"), style: :flow } if balance.net_market_flows != 0

      if has_adjustments?
        items << { label: t(".end_balance"), value: end_balance_before_adjustments, tooltip: t(".crypto_end_tooltip"), style: :subtotal }
        items << { label: t(".adjustments"), value: total_adjustments, tooltip: t(".adjustments_tooltip"), style: :adjustment }
      end

      items << { label: t(".final_balance"), value: balance.end_balance_money, tooltip: t(".crypto_final_tooltip"), style: :final }
      items
    end

    def net_cash_flow
      balance.cash_inflows_money - balance.cash_outflows_money
    end

    def net_non_cash_flow
      balance.non_cash_inflows_money - balance.non_cash_outflows_money
    end

    def net_total_flow
      net_cash_flow + net_non_cash_flow + balance.net_market_flows_money
    end

    def total_adjustments
      balance.cash_adjustments_money + balance.non_cash_adjustments_money
    end

    def has_adjustments?
      balance.cash_adjustments != 0 || balance.non_cash_adjustments != 0
    end

    def end_balance_before_adjustments
      balance.end_balance_money - total_adjustments
    end
end
