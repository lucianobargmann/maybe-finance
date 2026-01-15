class AddReviewedToEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :entries, :reviewed, :boolean, default: false, null: false
  end
end
