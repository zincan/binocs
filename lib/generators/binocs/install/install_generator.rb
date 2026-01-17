# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Binocs
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_migrations
        migration_template "create_binocs_requests.rb", "db/migrate/create_binocs_requests.rb"
      end

      def create_initializer
        template "initializer.rb", "config/initializers/binocs.rb"
      end

      def add_route
        route "mount Binocs::Engine => '/binocs' unless Rails.env.production?"
      end

      def update_gitignore
        gitignore_path = Rails.root.join(".gitignore")
        return unless File.exist?(gitignore_path)

        gitignore_entries = <<~GITIGNORE

          # Binocs AI Agent files
          .binocs-context.md
          .binocs-prompt.md
        GITIGNORE

        gitignore_content = File.read(gitignore_path)

        # Check if already added
        return if gitignore_content.include?(".binocs-context.md")

        append_to_file ".gitignore", gitignore_entries
        say "Updated .gitignore with Binocs entries", :green
      end

      def show_readme
        say ""
        say "Binocs installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. Run migrations: bin/rails db:migrate"
        say "  2. Start your server: bin/rails server"
        say "  3. Visit: http://localhost:3000/binocs"
        say ""
      end
    end
  end
end
