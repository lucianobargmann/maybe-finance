module AccountsHelper
  def summary_card(title:, &block)
    content = capture(&block)
    render "accounts/summary_card", title: title, content: content
  end

  def account_type_key(account)
    account.accountable_type.underscore
  end
end
