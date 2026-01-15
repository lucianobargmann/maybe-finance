class AddTextPasteFieldsToImports < ActiveRecord::Migration[7.2]
  def change
    add_column :imports, :source, :string, default: "csv"
    add_column :imports, :original_text_preview, :text
  end
end
