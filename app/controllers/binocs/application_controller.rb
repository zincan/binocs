# frozen_string_literal: true

module Binocs
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "binocs/application"

    before_action :verify_access
    before_action :authenticate_binocs_user

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

    def authenticate_binocs_user
      auth_method = Binocs.configuration.authentication_method
      return unless auth_method

      # Store the current URL for redirect after login (Devise integration)
      store_location_for_binocs

      case auth_method
      when Symbol
        # Call the method by name (e.g., :authenticate_user!)
        send(auth_method)
      when Proc
        # Call the proc with the controller instance
        instance_exec(&auth_method)
      when String
        # Call the method by name as string
        send(auth_method.to_sym)
      end
    end

    def store_location_for_binocs
      # Determine the Devise scope from the authentication method
      auth_method = Binocs.configuration.authentication_method.to_s
      match = auth_method.match(/authenticate_(\w+)!/)
      scope = match ? match[1] : 'user'

      # Check if user is already signed in (don't overwrite return URL)
      signed_in_method = "#{scope}_signed_in?"
      return if respond_to?(signed_in_method, true) && send(signed_in_method)

      # Store directly in session using Devise's expected key format
      # Devise looks for session["#{scope}_return_to"] after sign in
      session["#{scope}_return_to"] = request.fullpath
    end
  end
end
