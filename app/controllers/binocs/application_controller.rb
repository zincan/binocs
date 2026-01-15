# frozen_string_literal: true

module Binocs
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "binocs/application"

    before_action :verify_access

    private

    def verify_access
      if Rails.env.production?
        render plain: "Binocs is not available in production.", status: :forbidden
        return
      end

      return unless Binocs.configuration.basic_auth_enabled?

      authenticate_or_request_with_http_basic("Binocs") do |username, password|
        ActiveSupport::SecurityUtils.secure_compare(username, Binocs.configuration.basic_auth_username) &
          ActiveSupport::SecurityUtils.secure_compare(password, Binocs.configuration.basic_auth_password)
      end
    end
  end
end
