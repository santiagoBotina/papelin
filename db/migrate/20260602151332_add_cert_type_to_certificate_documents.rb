class AddCertTypeToCertificateDocuments < ActiveRecord::Migration[7.2]
  def change
    add_column :documents, :cert_type, :integer
    add_index  :documents, :cert_type
  end
end
