# frozen_string_literal: true

require_relative "selenium_webdriver_mcp/version"
require_relative "selenium_webdriver_mcp/configuration"
require_relative "selenium_webdriver_mcp/driver_manager"
require_relative "selenium_webdriver_mcp/session_manager"
require_relative "selenium_webdriver_mcp/fast_mcp_patch" # Patch FastMCP 1.6.0 RackTransport bug
require_relative "selenium_webdriver_mcp/server"

module SeleniumWebdriverMcp
  class Error < StandardError; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
