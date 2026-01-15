# frozen_string_literal: true

module Binocs
  class Configuration
    attr_accessor :enabled,
                  :retention_period,
                  :max_body_size,
                  :ignored_paths,
                  :ignored_content_types,
                  :basic_auth_username,
                  :basic_auth_password,
                  :max_requests,
                  :record_request_body,
                  :record_response_body

    def initialize
      @enabled = true
      @retention_period = 24.hours
      @max_body_size = 64.kilobytes
      @ignored_paths = %w[/assets /packs /binocs /cable]
      @ignored_content_types = %w[image/ video/ audio/ font/]
      @basic_auth_username = nil
      @basic_auth_password = nil
      @max_requests = 1000
      @record_request_body = true
      @record_response_body = true
    end

    def basic_auth_enabled?
      basic_auth_username.present? && basic_auth_password.present?
    end
  end
end
