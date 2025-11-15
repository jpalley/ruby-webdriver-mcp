# Selenium WebDriver MCP Server

A containerized [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server for controlling Selenium WebDriver from Large Language Models (LLMs) and AI agents. Run browser automation through a simple HTTP API.

## Features

- **MCP Server Implementation**: Full MCP server using FastMCP with HTTP/SSE transport
- **Selenium WebDriver Integration**: Control Chrome, Firefox, or Edge browsers remotely
- **Docker Ready**: Containerized deployment with docker-compose
- **Comprehensive Browser Control**: Navigate, find elements, interact, execute JavaScript, and more
- **Console Logs**: Access browser console logs for debugging
- **Health Checks**: Built-in health endpoint for monitoring
- **Environment Configuration**: Fully configurable via environment variables

## Quick Start

### Docker Deployment (Recommended)

Run the MCP server with Docker:

```bash
# Quick start with docker-compose (includes Selenium)
docker-compose -f docker-compose.production.yml up

# Or build and run manually
docker build -t selenium-mcp-server .
docker run -p 4443:4443 \
  -e SELENIUM_URL=http://your-selenium:4444/wd/hub \
  selenium-mcp-server
```

**Test the server:**
```bash
# Health check
curl http://localhost:4443/health

# List available tools
curl -X POST http://localhost:4443/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

**Environment Variables:**
- `SELENIUM_URL` - Selenium server URL (default: `http://selenium:4444/wd/hub`)
- `SELENIUM_BROWSER` - Browser type: chrome, firefox, edge (default: `chrome`)
- `SELENIUM_HEADLESS` - Run headless: true/false (default: `true`)
- `PORT` - HTTP server port (default: `4443`)

See [DOCKER.md](DOCKER.md) for detailed Docker deployment guide.

### Development Setup

For local development without Docker:

```bash
# Install dependencies
bundle install

# Start Selenium (or use existing Selenium server)
docker run -d -p 4444:4444 selenium/standalone-chrome

# Start the MCP server
SELENIUM_URL=http://localhost:4444/wd/hub bundle exec rackup -p 4443

# Enable debug logging (see below for details)
DEBUG=true bundle exec rackup -p 4443

# Run tests
bundle exec rspec
```

**Debug Logging**:

Enable detailed MCP request/response logging with environment variables:

```bash
# Enable debug logging (shows all MCP requests, responses, and routing)
DEBUG=true bundle exec rackup

# Or set specific log level
LOG_LEVEL=DEBUG bundle exec rackup  # DEBUG, INFO, WARN, ERROR, FATAL
```

Debug output includes:
- Server startup information (registered tools and resources)
- Request routing (which paths go to MCP vs web app)
- MCP JSON-RPC request/response details
- Tool invocations and results

## Web Dashboard

A modern web interface is available at the root path for monitoring sessions and viewing screenshot history.

**Access**: Open `http://localhost:4443/` in your web browser

**Features**:
- View all active browser sessions in real-time
- Session details: current URL, page title, last activity
- Capture and view screenshot history (up to 10 per session)
- Auto-refresh every 5 seconds
- Responsive design with Tailwind CSS

**Screenshot Management**:
- Click "Capture Screenshot" to save current browser state
- View screenshot history in grid layout
- Click screenshots to view full-size
- Automatically limited to 10 most recent screenshots per session

See [WEB_DASHBOARD.md](WEB_DASHBOARD.md) for detailed documentation.

## Configuration

Configuration is done via environment variables (for Docker) or programmatically (for development):

```ruby
SeleniumWebdriverMcp.configure do |config|
  # URL of the Selenium WebDriver server
  config.selenium_url = ENV.fetch("SELENIUM_URL", "http://selenium:4444/wd/hub")

  # Browser to use (:chrome, :firefox, :edge)
  config.browser = :chrome

  # Run browser in headless mode
  config.headless = true

  # Timeouts (in seconds)
  config.implicit_wait = 10
  config.page_load_timeout = 30
  config.script_timeout = 30

  # Default window size [width, height]
  config.window_size = [1400, 1400]

  # Additional browser capabilities (optional)
  config.capabilities = {
    "goog:chromeOptions" => {
      "args" => ["--disable-gpu"]
    }
  }
end
```

## Architecture

```
┌──────────────────┐     ┌──────────────────┐
│   Web Browser    │     │   MCP Client     │
│   (Dashboard)    │     │   (Claude, LLM)  │
└────────┬─────────┘     └────────┬─────────┘
         │ HTTP                   │ HTTP
         └────────────┬───────────┘
                      ▼
       ┌──────────────────────────────────┐
       │   MCP Server (Port 4443)         │
       │   - / (Web Dashboard)            │
       │   - /mcp (JSON-RPC)              │
       │   - /sse (Server Events)         │
       │   - /api/* (Dashboard API)       │
       │   - /screenshots/* (Images)      │
       │   - /health                      │
       └──────────────┬───────────────────┘
                      │ WebDriver
                      ▼
       ┌────────────────────────┐
       │   Selenium (Port 4444) │
       │   - Chrome Browser     │
       └────────────────────────┘
```

## Session Management

**IMPORTANT:** All tools require a `session_id` parameter. You must create a session before using other tools.

### Session Tools
- `create_session` - Create a new browser session (returns a session_id)
  - `session_id` (string, optional): Custom session ID (auto-generated if not provided)
- `destroy_session` - Destroy a session and close the browser
  - `session_id` (string, required): The session ID to destroy
- `list_sessions` - List all active sessions

See [SESSION_MANAGEMENT.md](SESSION_MANAGEMENT.md) for detailed information on handling multiple concurrent clients.

## MCP Tools

The following MCP tools are available (all require `session_id`):

### Navigation
- `navigate` - Navigate to a URL
  - `session_id` (string, required): The browser session ID
  - `url` (string, required): The URL to navigate to

### Element Finding
- `find_element` - Find an element on the page
  - `session_id` (string, required): The browser session ID
  - `strategy` (string, required): Locator strategy (id, name, class, css, xpath, link_text, tag_name)
  - `value` (string, required): The value to search for
- `wait_for_element` - Wait for an element to appear
  - `session_id` (string, required): The browser session ID
  - `strategy` (string, required): Locator strategy
  - `value` (string, required): The value to search for
  - `timeout` (integer, optional): Maximum time to wait in seconds (default: 10)

### Element Interaction
- `click_element` - Click on an element
  - `session_id` (string, required): The browser session ID
  - `element_id` (string, required): Element ID from find_element
- `send_keys` - Type text into an element
  - `session_id` (string, required): The browser session ID
  - `element_id` (string, required): Element ID from find_element
  - `text` (string, required): Text to type

### Element Information
- `get_text` - Get the text content of an element
  - `session_id` (string, required): The browser session ID
  - `element_id` (string, required): Element ID from find_element
- `get_attribute` - Get an attribute value from an element
  - `session_id` (string, required): The browser session ID
  - `element_id` (string, required): Element ID from find_element
  - `attribute_name` (string, required): Name of the attribute

### JavaScript Execution
- `execute_script` - Execute JavaScript in the browser
  - `session_id` (string, required): The browser session ID
  - `script` (string, required): JavaScript code to execute

### Page Information
- `get_page_source` - Get the HTML source of the current page
  - `session_id` (string, required): The browser session ID
- `get_console_logs` - Get browser console logs (Chrome/JS console output)
  - `session_id` (string, required): The browser session ID

### Screenshot Management
- `save_screenshot` - Capture a screenshot and save it to history (max 10 per session)
  - `session_id` (string, required): The browser session ID
  - Returns: `{saved: true, timestamp, url, screenshot_url, message, total_screenshots}`
  - The `screenshot_url` is a full URL (e.g., `http://localhost:4443/screenshots/session_id/timestamp.png`) that reflects the host of the incoming request

**Note:** Current screenshots are also accessible via MCP Resources or HTTP endpoint (see below)

### Frame Switching
- `switch_frame` - Switch to a frame or iframe
  - `session_id` (string, required): The browser session ID
  - `frame_reference`: Frame index (integer), frame name (string), element_id, 'default', or 'parent'

## MCP Resources

The following MCP resources are available:

### Non-Templated Resources (accessible via `resources/list`)
- `browser://current_url` - The current URL of the browser
- `browser://page_title` - The title of the current page
- `browser://session_status` - WebDriver session status and information

### Templated Resources (accessed by URI)
- `screenshot://{session_id}` - PNG screenshot of the browser window for a session

### Accessing Screenshots

Screenshots can be accessed in two ways:

**1. Via MCP Resource Protocol:**
```json
{"method": "resources/read", "params": {"uri": "screenshot://session_abc123"}}
```
Returns base64-encoded PNG in a `blob` field with `mimeType: "image/png"`

**2. Via Direct HTTP Endpoint:**
```bash
curl http://localhost:4443/screenshots/session_abc123 > screenshot.png
```
Returns raw PNG binary data with `Content-Type: image/png` header

## Usage Example

Here's an example of how an LLM might use these tools via MCP:

1. Create a session:
   ```json
   {"tool": "create_session", "arguments": {}}
   ```
   Returns: `{"session_id": "session_abc123", ...}`

2. Navigate to a website:
   ```json
   {"tool": "navigate", "arguments": {"session_id": "session_abc123", "url": "https://example.com"}}
   ```

3. Find a search input:
   ```json
   {"tool": "find_element", "arguments": {"session_id": "session_abc123", "strategy": "name", "value": "q"}}
   ```
   Returns: `{"element_id": "element_0", "tag_name": "input", ...}`

4. Type into the search input:
   ```json
   {"tool": "send_keys", "arguments": {"session_id": "session_abc123", "element_id": "element_0", "text": "hello world"}}
   ```

5. Find and click the search button:
   ```json
   {"tool": "find_element", "arguments": {"session_id": "session_abc123", "strategy": "css", "value": "button[type=submit]"}}
   ```
   Returns: `{"element_id": "element_1", ...}`

   ```json
   {"tool": "click_element", "arguments": {"session_id": "session_abc123", "element_id": "element_1"}}
   ```

6. Get console logs:
   ```json
   {"tool": "get_console_logs", "arguments": {"session_id": "session_abc123"}}
   ```

7. Take a screenshot (via resource):
   ```json
   {"method": "resources/read", "params": {"uri": "screenshot://session_abc123"}}
   ```
   Or via HTTP: `GET /screenshots/session_abc123`

8. Clean up:
   ```json
   {"tool": "destroy_session", "arguments": {"session_id": "session_abc123"}}
   ```

## Development

After checking out the repo, run `bundle install` to install dependencies.

To run tests (when implemented):
```bash
bundle exec rspec
```

To run RuboCop:
```bash
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/brainpage/ruby-webdriver-mcp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Security

This gem provides programmatic control of a web browser. When exposing this via MCP:

- Only expose the MCP server to trusted LLM clients
- Be cautious about which websites you allow navigation to
- Consider implementing authentication for the MCP endpoints
- Use in isolated/sandboxed environments when possible
- Review and validate any JavaScript executed via `execute_script`

## Credits

Built with:
- [FastMCP](https://github.com/yjacquin/fast-mcp) - Ruby implementation of the Model Context Protocol
- [Selenium WebDriver](https://www.selenium.dev/documentation/webdriver/) - Browser automation framework
