# frozen_string_literal: true

module Binocs
  class Request < ApplicationRecord
    self.table_name = "binocs_requests"

    serialize :params, coder: JSON
    serialize :request_headers, coder: JSON
    serialize :response_headers, coder: JSON
    serialize :logs, coder: JSON
    serialize :exception, coder: JSON

    validates :uuid, presence: true, uniqueness: true
    validates :method, presence: true
    validates :path, presence: true

    # Scopes for filtering
    scope :by_method, ->(method) { where(method: method.upcase) if method.present? }
    scope :by_status, ->(status) { where(status_code: status) if status.present? }
    scope :by_status_range, ->(range) {
      case range
      when "2xx" then where(status_code: 200..299)
      when "3xx" then where(status_code: 300..399)
      when "4xx" then where(status_code: 400..499)
      when "5xx" then where(status_code: 500..599)
      end
    }
    scope :by_path, ->(path) { where("path LIKE ?", "%#{path}%") if path.present? }
    scope :by_controller, ->(controller) { where(controller_name: controller) if controller.present? }
    scope :by_action, ->(action) { where(action_name: action) if action.present? }
    scope :with_exception, -> { where.not(exception: nil) }
    scope :without_exception, -> { where(exception: nil) }
    scope :slow, ->(threshold_ms = 1000) { where("duration_ms > ?", threshold_ms) }
    scope :by_ip, ->(ip) { where(ip_address: ip) if ip.present? }
    scope :recent, -> { order(created_at: :desc) }
    scope :today, -> { where("created_at >= ?", Time.current.beginning_of_day) }
    scope :last_hour, -> { where("created_at >= ?", 1.hour.ago) }
    scope :search, ->(query) {
      return all if query.blank?

      where("path LIKE :q OR controller_name LIKE :q OR action_name LIKE :q", q: "%#{query}%")
    }

    # Instance methods
    def success?
      status_code.present? && status_code >= 200 && status_code < 300
    end

    def redirect?
      status_code.present? && status_code >= 300 && status_code < 400
    end

    def client_error?
      status_code.present? && status_code >= 400 && status_code < 500
    end

    def server_error?
      status_code.present? && status_code >= 500
    end

    def has_exception?
      exception.present?
    end

    def status_class
      return "error" if server_error? || has_exception?
      return "warning" if client_error?
      return "redirect" if redirect?

      "success"
    end

    def method_class
      case method.upcase
      when "GET" then "method-get"
      when "POST" then "method-post"
      when "PUT", "PATCH" then "method-put"
      when "DELETE" then "method-delete"
      else "method-other"
      end
    end

    def formatted_duration
      return "N/A" unless duration_ms

      if duration_ms < 1
        "< 1ms"
      elsif duration_ms < 1000
        "#{duration_ms.round(1)}ms"
      else
        "#{(duration_ms / 1000).round(2)}s"
      end
    end

    def formatted_memory_delta
      return "N/A" unless memory_delta

      if memory_delta.abs < 1024
        "#{memory_delta} B"
      elsif memory_delta.abs < 1024 * 1024
        "#{(memory_delta / 1024.0).round(2)} KB"
      else
        "#{(memory_delta / (1024.0 * 1024)).round(2)} MB"
      end
    end

    def short_path
      return path if path.length <= 50

      "#{path[0, 47]}..."
    end

    def controller_action
      return nil unless controller_name && action_name

      "#{controller_name}##{action_name}"
    end

    # Class methods for statistics
    def self.average_duration
      average(:duration_ms)&.round(2)
    end

    def self.error_rate
      return 0 if count.zero?

      ((with_exception.count + by_status_range("5xx").count).to_f / count * 100).round(2)
    end

    def self.methods_breakdown
      group(:method).count
    end

    def self.status_breakdown
      group(:status_code).count
    end

    def self.controllers_list
      distinct.pluck(:controller_name).compact.sort
    end
  end
end
