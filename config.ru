# frozen_string_literal: true

require_relative "lib/selenium_webdriver_mcp"

# Configure Selenium connection from environment variables
SeleniumWebdriverMcp.configure do |config|
  config.selenium_url = ENV.fetch("SELENIUM_URL", "http://localhost:4444/wd/hub")
  config.browser = ENV.fetch("SELENIUM_BROWSER", "chrome").to_sym
  config.headless = ENV.fetch("SELENIUM_HEADLESS", "true") == "true"
end

# Enable debug logging with DEBUG=true or LOG_LEVEL=DEBUG
# Example: DEBUG=true bundle exec rackup
# Levels: DEBUG, INFO, WARN, ERROR, FATAL

# Create the MCP server and get the Rack app
server = SeleniumWebdriverMcp::Server.new(
  name: "selenium-webdriver-mcp",
  version: SeleniumWebdriverMcp::VERSION
)

# Health check middleware
class HealthCheckMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/health"
      # Rack 3.x requires lowercase header names
      [200, { "content-type" => "application/json" }, ['{"status":"ok","version":"' + SeleniumWebdriverMcp::VERSION + '"}']]
    else
      @app.call(env)
    end
  end
end

# Wrap the MCP app with health check
use HealthCheckMiddleware

# Run the Rack app with MCP middleware
# Endpoints will be available at:
#   - / (Web Dashboard - HTML interface)
#   - /mcp (MCP JSON-RPC over HTTP)
#   - /sse (MCP Server-Sent Events)
#   - /api/sessions (Dashboard API - JSON)
#   - /api/sessions/{id}/screenshots (Dashboard API - JSON)
#   - /api/sessions/{id}/screenshot (Dashboard API - POST)
#   - /screenshots/{session_id} (Current screenshot - PNG)
#   - /screenshots/{session_id}/{timestamp}.png (Historical screenshot - PNG)
#   - /health (Health check)
run server.rack_app(localhost_only: false)
