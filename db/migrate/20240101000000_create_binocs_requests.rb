# frozen_string_literal: true

class CreateBinocsRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :binocs_requests do |t|
      t.string :uuid, null: false, index: { unique: true }
      t.string :method, null: false
      t.string :path, null: false
      t.text :full_url
      t.string :controller_name
      t.string :action_name
      t.string :route_name
      t.text :params
      t.text :request_headers
      t.text :response_headers
      t.text :request_body
      t.text :response_body
      t.integer :status_code
      t.float :duration_ms
      t.string :ip_address
      t.string :session_id
      t.text :logs
      t.text :exception
      t.integer :memory_delta
      t.string :content_type

      t.timestamps
    end

    add_index :binocs_requests, :method
    add_index :binocs_requests, :status_code
    add_index :binocs_requests, :controller_name
    add_index :binocs_requests, :created_at
    add_index :binocs_requests, :duration_ms
  end
end
