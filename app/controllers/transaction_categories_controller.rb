class TransactionCategoriesController < ApplicationController
  include ActionView::RecordIdentifier

  def update
    @entry = Current.family.entries.transactions.find(params[:transaction_id])
    transaction = @entry.transaction
    previous_category_id = transaction.category_id

    @entry.update!(entry_params)
    transaction.reload

    if needs_rule_notification?(transaction, previous_category_id)
      flash[:cta] = {
        type: "category_rule",
        category_id: transaction.category_id,
        category_name: transaction.category.name
      }
    end

    transaction.lock_saved_attributes!
    @entry.lock_saved_attributes!

    respond_to do |format|
      format.html { redirect_back_or_to transaction_path(@entry) }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(transaction, :category_menu),
            partial: "categories/menu",
            locals: { transaction: transaction }
          ),
          *flash_notification_stream_items
        ]
      end
    end
  end

  private
    def entry_params
      params.require(:entry).permit(:entryable_type, entryable_attributes: [ :id, :category_id ])
    end

    def needs_rule_notification?(transaction, previous_category_id)
      return false if Current.user.rule_prompts_disabled

      if Current.user.rule_prompt_dismissed_at.present?
        time_since_last_rule_prompt = Time.current - Current.user.rule_prompt_dismissed_at
        return false if time_since_last_rule_prompt < 1.day
      end

      category_changed = transaction.category_id != previous_category_id
      category_changed && transaction.category_id.present? &&
      transaction.eligible_for_category_rule?
    end
end
