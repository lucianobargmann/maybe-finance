module ImportsHelper
  def mapping_label(mapping_class)
    {
      "Import::AccountTypeMapping" => I18n.t("imports.mappings.account_type"),
      "Import::AccountMapping" => I18n.t("imports.mappings.account"),
      "Import::CategoryMapping" => I18n.t("imports.mappings.category"),
      "Import::MerchantMapping" => I18n.t("imports.mappings.merchant"),
      "Import::TagMapping" => I18n.t("imports.mappings.tag")
    }.fetch(mapping_class.name)
  end

  def import_col_label(key)
    {
      date: I18n.t("imports.columns.date"),
      amount: I18n.t("imports.columns.amount"),
      name: I18n.t("imports.columns.name"),
      currency: I18n.t("imports.columns.currency"),
      category: I18n.t("imports.columns.category"),
      merchant: I18n.t("imports.columns.merchant"),
      tags: I18n.t("imports.columns.tags"),
      account: I18n.t("imports.columns.account"),
      notes: I18n.t("imports.columns.notes"),
      qty: I18n.t("imports.columns.qty"),
      ticker: I18n.t("imports.columns.ticker"),
      exchange: I18n.t("imports.columns.exchange"),
      price: I18n.t("imports.columns.price"),
      entity_type: I18n.t("imports.columns.entity_type")
    }[key]
  end

  def dry_run_resource(key)
    map = {
      transactions: DryRunResource.new(label: I18n.t("imports.ready.transactions"), icon: "credit-card", text_class: "text-cyan-500", bg_class: "bg-cyan-500/5"),
      accounts: DryRunResource.new(label: I18n.t("imports.ready.accounts"), icon: "layers", text_class: "text-orange-500", bg_class: "bg-orange-500/5"),
      categories: DryRunResource.new(label: I18n.t("imports.ready.categories"), icon: "shapes", text_class: "text-blue-500", bg_class: "bg-blue-500/5"),
      tags: DryRunResource.new(label: I18n.t("imports.ready.tags"), icon: "tags", text_class: "text-violet-500", bg_class: "bg-violet-500/5")
    }

    map[key]
  end

  def permitted_import_configuration_path(import)
    if permitted_import_types.include?(import.type.underscore)
      "import/configurations/#{import.type.underscore}"
    else
      raise "Unknown import type: #{import.type}"
    end
  end

  def cell_class(row, field)
    base = "bg-container text-sm focus:ring-gray-900 theme-dark:focus:ring-gray-100 focus:border-solid w-full max-w-full disabled:text-subdued"

    row.valid? # populate errors

    border = row.errors.key?(field) ? "border-destructive" : "border-transparent"

    [ base, border ].join(" ")
  end

  def cell_is_valid?(row, field)
    row.valid? # populate errors
    !row.errors.key?(field)
  end

  def ai_configured?
    provider_name = Setting.llm_provider&.to_sym || :anthropic
    Provider::Registry.get_provider(provider_name).present?
  end

  private
    def permitted_import_types
      %w[transaction_import trade_import account_import mint_import]
    end

    DryRunResource = Struct.new(:label, :icon, :text_class, :bg_class, keyword_init: true)
end
