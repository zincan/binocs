# Playwright MCP Setup for Binocs

This guide explains how to install Playwright and configure the Playwright MCP server so that Claude Code agents (like `binocs-dashboard-architect`) can interact with the Binocs dashboard UI — taking screenshots, clicking elements, inspecting styles, and verifying `data-testid` attributes.

## Prerequisites

- Node.js 18+ (this project uses mise/asdf — check with `node --version`)
- A running Rails server with Binocs mounted (default: `http://localhost:4050/binocs`)

## 1. Install Playwright Globally

Since Binocs is a Rails project, Node packages should be installed globally to avoid polluting the gem's directory with `node_modules` or a `package.json`.

```bash
# Install the Playwright MCP package globally
npm install -g @playwright/mcp

# Install browser binaries (Chromium is sufficient for dashboard testing)
npx playwright install chromium
```

Verify the installation:

```bash
npx @playwright/mcp@latest --version
```

## 2. Configure Claude Code MCP Server

Use the `claude mcp add` command to register the Playwright MCP server.

### Project-level (recommended)

```bash
claude mcp add playwright -- npx @playwright/mcp@latest \
  --test-id-attribute data-testid \
  --viewport-size 1280x720
```

This writes the server config to `.claude/settings.local.json` automatically.

### User-level (applies to all projects)

```bash
claude mcp add -s user playwright -- npx @playwright/mcp@latest \
  --test-id-attribute data-testid \
  --viewport-size 1280x720
```

### Auto-approve Playwright tools (optional)

To let agents use Playwright tools without confirmation prompts, add a permission rule:

```bash
claude config add permissions.allow "mcp__playwright__*"
```

### Key flags explained

| Flag | Value | Purpose |
|------|-------|---------|
| `--test-id-attribute` | `data-testid` | Matches the Binocs convention for Playwright selectors (e.g., `data-testid="kpi-requests-today"`) |
| `--viewport-size` | `1280x720` | Standard desktop viewport for dashboard screenshots |

### Optional flags

| Flag | Example | Purpose |
|------|---------|---------|
| `--headless` | (no value) | Run without a visible browser window (default behavior) |
| `--save-trace` | (no value) | Save a Playwright Trace for debugging sessions |
| `--save-video` | `1280x720` | Record a video of the browser session |
| `--timeout-action` | `10000` | Increase action timeout (ms) for slow dev servers |
| `--timeout-navigation` | `120000` | Increase navigation timeout (ms) |
| `--storage-state` | `path/to/state.json` | Persist auth/cookies between sessions |

## 3. Verify the MCP Server Works

Restart Claude Code (or run `/mcp` to check status). You should see `playwright` listed as a connected MCP server.

The agent can then use Playwright tools like:

- `browser_navigate` — open the Binocs dashboard
- `browser_snapshot` — capture an accessibility snapshot of the current page
- `browser_screenshot` — take a PNG screenshot for visual inspection
- `browser_click` — click elements by `data-testid` or text
- `browser_type` — type into inputs (e.g., search/filter fields)

## 4. Example: Agent Analyzing the Dashboard

Once configured, the `binocs-dashboard-architect` agent can:

```
1. Navigate to http://localhost:4050/binocs
2. Take a snapshot to inspect the DOM structure and Tailwind classes
3. Click on a request row (data-testid="request-row-123")
4. Screenshot the detail view to verify the Visionary Dark theme
5. Check that all required data-testid attributes are present
```

## 5. Authentication (if Devise is enabled)

If your Binocs instance requires authentication, use `--storage-state` to provide pre-authenticated cookies:

1. Log in manually and export cookies to a JSON file
2. Pass the file: `"--storage-state", "/path/to/auth-state.json"`

Or temporarily disable authentication in your dev environment.

## Troubleshooting

### "Browser not found"

Run `npx playwright install chromium` to download browser binaries.

### MCP server not connecting

- Check that `npx @playwright/mcp@latest --help` works from your terminal
- Ensure Node.js is on your PATH (check with `which node`)
- Look at Claude Code's MCP status with `/mcp`

### Timeouts on navigation

If your dev server is slow to start, re-add with increased timeouts:

```bash
claude mcp remove playwright
claude mcp add playwright -- npx @playwright/mcp@latest \
  --test-id-attribute data-testid \
  --viewport-size 1280x720 \
  --timeout-navigation 120000 \
  --timeout-action 10000
```

### data-testid attributes not found

Verify the attribute exists in the HTML. Binocs uses `data-testid` (the default for Playwright), configured via `--test-id-attribute data-testid`.
