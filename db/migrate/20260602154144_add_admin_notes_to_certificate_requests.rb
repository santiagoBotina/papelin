class AddAdminNotesToCertificateRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :certificate_requests, :admin_notes, :text
  end
end
