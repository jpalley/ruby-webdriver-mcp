# frozen_string_literal: true

# Example config.ru for mounting Selenium WebDriver MCP in a Rails app
# Place this in your Rails root directory as config.ru (or merge with existing)

require_relative "config/environment"
require "selenium_webdriver_mcp"

# Configure Selenium WebDriver MCP
SeleniumWebdriverMcp.configure do |config|
  config.selenium_url = ENV.fetch("SELENIUM_URL", "http://selenium:4444/wd/hub")
  config.browser = :chrome
  config.headless = true
end

# Mount the MCP server middleware
use SeleniumWebdriverMcp::RackMiddleware

run Rails.application
Rails.application.load_server
