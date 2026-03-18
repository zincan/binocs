# frozen_string_literal: true

class AddClientIdentifierToBinocsRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :binocs_requests, :client_identifier, :string
    add_index :binocs_requests, :client_identifier
  end
end
