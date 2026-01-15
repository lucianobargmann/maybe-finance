class AddPdfFieldsToImports < ActiveRecord::Migration[7.2]
  def change
    add_column :imports, :pdf_processing_status, :string
    add_column :imports, :pdf_error_message, :string
    add_column :imports, :original_pdf_filename, :string
  end
end
