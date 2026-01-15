# frozen_string_literal: true

# Binocs Configuration
# For more options, see: https://github.com/zincan/binocs

Binocs.configure do |config|
  # Enable/disable Binocs (automatically disabled in production)
  config.enabled = true

  # How long to keep request records
  config.retention_period = 24.hours

  # Maximum request/response body size to store
  config.max_body_size = 64.kilobytes

  # Paths to ignore
  config.ignored_paths = %w[/assets /packs /binocs /cable]

  # Maximum number of requests to store
  config.max_requests = 1000

  # Optional: Protect dashboard with basic auth
  # config.basic_auth_username = ENV['BINOCS_USERNAME']
  # config.basic_auth_password = ENV['BINOCS_PASSWORD']
end
