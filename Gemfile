# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Development dependencies only - used for testing the engine with a dummy Rails app.
# The engine itself has no database dependency and will use whatever database
# the host Rails application is configured with (PostgreSQL, MySQL, SQLite, etc.)
group :development, :test do
  gem "sqlite3"
  gem "puma"
  gem "debug"
end
