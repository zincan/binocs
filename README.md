# Binocs

A Laravel Telescope-inspired request monitoring dashboard for Rails applications. Binocs provides real-time visibility into HTTP requests through both a web interface and a terminal UI with vim-style navigation, making debugging and development easier whether you prefer the browser or the command line.

## Features

- **Real-time Request Monitoring**: Watch requests stream in as they happen via ActionCable/Turbo Streams
- **Comprehensive Request Details**: View params, headers, request/response bodies, logs, and exceptions
- **Powerful Filtering**: Filter by HTTP method, status code, path, controller, and more
- **Exception Tracking**: Quickly identify and debug errors with full backtrace
- **Performance Insights**: Track request duration and memory usage
- **Dark Theme UI**: Beautiful, modern interface built with Tailwind CSS
- **Terminal UI (TUI)**: Vim-style keyboard navigation for console-based monitoring
- **Swagger Integration**: View OpenAPI documentation for requests and jump to Swagger UI
- **Production Safe**: Automatically disabled in production environments

## Requirements

- Ruby 3.0+
- Rails 7.0+
- ActionCable (for real-time updates)
- ncurses development libraries (for TUI - typically pre-installed on macOS/Linux)

## Installation

### 1. Add Binocs to your Gemfile

```ruby
# Gemfile
gem 'binocs', path: 'path/to/binocs'  # For local development

# Or from GitHub (once published)
# gem 'binocs', github: 'zincan/binocs'
```

### 2. Install the gem

```bash
bundle install
```

### 3. Run the install generator

```bash
bin/rails generate binocs:install
```

This will:
- Copy the migration file
- Create an initializer at `config/initializers/binocs.rb`
- Add the route to mount the engine

### 4. Run migrations

```bash
bin/rails db:migrate
```

### 5. Ensure ActionCable is configured

If you haven't set up ActionCable yet, add to your `config/cable.yml`:

```yaml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
```

### 6. Start your Rails server

```bash
bin/rails server
```

### 7. Visit the dashboard

Open your browser and navigate to: `http://localhost:3000/binocs`

## Configuration

Customize Binocs behavior in `config/initializers/binocs.rb`:

```ruby
Binocs.configure do |config|
  # Enable/disable Binocs (automatically disabled in production)
  config.enabled = true

  # How long to keep request records (default: 24 hours)
  config.retention_period = 24.hours

  # Maximum request/response body size to store (default: 64KB)
  config.max_body_size = 64.kilobytes

  # Paths to ignore (assets, cable, etc.)
  config.ignored_paths = %w[/assets /packs /binocs /cable]

  # Content types to ignore (images, videos, etc.)
  config.ignored_content_types = %w[image/ video/ audio/ font/]

  # Maximum number of requests to store (oldest are deleted)
  config.max_requests = 1000

  # Whether to record request/response bodies
  config.record_request_body = true
  config.record_response_body = true

  # Optional: Protect the dashboard with basic auth
  config.basic_auth_username = ENV['BINOCS_USERNAME']
  config.basic_auth_password = ENV['BINOCS_PASSWORD']

  # Swagger/OpenAPI integration (for TUI)
  config.swagger_spec_url = '/api-docs/v1/swagger.yaml'  # OpenAPI spec endpoint
  config.swagger_ui_url = '/api-docs/index.html'         # Swagger UI URL

  # Devise authentication (recommended if using Devise with ActionCable)
  # config.authentication_method = :authenticate_user!

  # Login path for authentication prompts (auto-detected for Devise)
  # config.login_path = '/users/sign_in'
end
```

### Devise Integration

If your application uses Devise for authentication, you can require users to be logged in before accessing Binocs. This ensures the ActionCable WebSocket connection works properly.

```ruby
# config/initializers/binocs.rb
Binocs.configure do |config|
  # Require Devise authentication (recommended)
  config.authentication_method = :authenticate_user!

  # Or for admin users:
  # config.authentication_method = :authenticate_admin!

  # Or use a custom proc for more control:
  # config.authentication_method = -> { authenticate_user! || authenticate_admin! }
end
```

With this configured, unauthenticated users will be redirected to your login page, then back to `/binocs` after signing in.

**Fallback behavior**: If authentication is not configured but ActionCable requires it, Binocs will detect the WebSocket failure and display a banner prompting users to sign in. You can customize the login path:

```ruby
config.login_path = '/users/sign_in'  # Auto-detected from Devise if not set
```

### Swagger Deep Linking (rswag)

To enable jumping directly to specific endpoints in Swagger UI, add deep linking to your rswag configuration:

```ruby
# config/initializers/rswag_ui.rb
Rswag::Ui.configure do |c|
  c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1 Docs'

  # Enable deep linking to specific operations
  c.config_object['deepLinking'] = true
end
```

With this enabled, pressing `o` in the TUI detail view will open Swagger UI and expand the matching endpoint.

## Usage

### Dashboard Overview

The main dashboard shows a list of all recorded requests with:

- HTTP method (GET, POST, PUT, PATCH, DELETE)
- Status code (color-coded by type)
- Request path
- Controller#action
- Duration
- Timestamp

### Filtering Requests

Use the filter bar to narrow down requests:

- **Search**: Search by path, controller, or action
- **Method**: Filter by HTTP method
- **Status**: Filter by status code range (2xx, 3xx, 4xx, 5xx)
- **Controller**: Filter by controller name
- **Has Exception**: Show only requests with exceptions

### Request Details

Click on any request to see full details including:

- **Overview**: Method, path, status, duration, memory usage
- **Params**: Filtered request parameters
- **Headers**: Request and response headers
- **Body**: Request and response bodies (with JSON formatting)
- **Logs**: Captured log entries from the request
- **Exception**: Full exception details with backtrace (if applicable)

### Real-time Updates

Requests appear in the dashboard in real-time as they're made to your application. The dashboard uses Turbo Streams over ActionCable for instant updates without page refresh.

## Terminal UI (TUI)

Binocs includes a full-featured terminal interface for monitoring requests directly from your console. Run it alongside your Rails server for a vim-style debugging experience.

### Starting the TUI

From your Rails application directory:

```bash
bundle exec binocs
```

Or if you're in the binocs gem directory:

```bash
cd /path/to/your/rails/app
bundle exec binocs
```

### Keyboard Navigation

**List View:**

| Key | Action |
|-----|--------|
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `g` / `Home` | Go to top |
| `G` / `End` | Go to bottom |
| `Ctrl+d` / `PgDn` | Page down |
| `Ctrl+u` / `PgUp` | Page up |
| `Enter` / `l` | View request details |
| `/` | Search by path |
| `f` | Open filter menu |
| `c` | Clear all filters |
| `r` | Refresh list |
| `d` | Delete selected request |
| `D` | Delete all requests |
| `?` | Show help |
| `q` | Quit |

**Detail View:**

| Key | Action |
|-----|--------|
| `Tab` / `]` / `L` | Next tab |
| `Shift+Tab` / `[` / `H` | Previous tab |
| `1`-`8` | Jump to tab by number |
| `j` / `↓` | Scroll down |
| `k` / `↑` | Scroll up |
| `n` | Next request |
| `p` | Previous request |
| `o` | Open Swagger docs in browser |
| `h` / `Esc` | Go back to list |

### TUI Features

- **Split-screen layout**: List on left, detail on right when viewing a request
- **Tabbed detail view**: Overview, Params, Headers, Body, Response, Logs, Exception, Swagger
- **Swagger integration**: View OpenAPI docs for any request and open in browser with `o`
- **Color-coded**: HTTP methods and status codes are highlighted by type
- **Auto-refresh**: List automatically updates every 2 seconds
- **Filtering**: Same filtering capabilities as the web interface
- **Responsive**: Adapts to terminal size changes

## Rake Tasks

```bash
# Clear all recorded requests
bin/rails binocs:clear

# Prune old requests (based on retention_period)
bin/rails binocs:prune

# Show statistics
bin/rails binocs:stats
```

## Security

### Production Safety

Binocs is automatically disabled in production environments. Even if mounted, accessing `/binocs` in production will return a 403 Forbidden response.

### Basic Authentication

For additional security in development/staging, enable basic auth:

```ruby
# config/initializers/binocs.rb
Binocs.configure do |config|
  config.basic_auth_username = 'admin'
  config.basic_auth_password = 'secret'
end
```

### Sensitive Data

Binocs uses Rails' parameter filtering, so sensitive params (like `password`) are automatically masked. Cookies are not stored for security reasons.

## Git Ignore

When using the AI Agent feature, Binocs creates temporary files in your project directory that should be added to your `.gitignore`:

```gitignore
# Binocs AI Agent files
.binocs-context.md
.binocs-prompt.md
```

If you use the worktree mode for agents, the default location is `../binocs-agents/` (a sibling directory to your project), so it won't affect your repo. However, if you configure a custom worktree path inside your project, add that path to `.gitignore` as well.

## Troubleshooting

### Requests not appearing

1. Ensure Binocs is enabled: Check `Binocs.enabled?` returns `true`
2. Check the path isn't ignored: Verify the path isn't in `config.ignored_paths`
3. Verify migrations ran: Check the `binocs_requests` table exists

### Real-time updates not working

1. Ensure ActionCable is configured and running
2. Check browser console for WebSocket errors
3. Verify you have `turbo_stream_from "binocs_requests"` in the layout

### High memory usage

1. Reduce `config.retention_period`
2. Lower `config.max_requests`
3. Set `config.record_response_body = false` if you don't need response bodies

## Development

### Running Tests

```bash
cd binocs
bundle install
bundle exec rspec
```

### Building the Gem

```bash
gem build binocs.gemspec
```

## License

MIT License. See [MIT-LICENSE](MIT-LICENSE) for details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
