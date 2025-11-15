# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class GetConsoleLogsTool < FastMcp::Tool
      tool_name "get_console_logs"
      description "Get browser console logs (Chrome/JS console output)"

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
      end

      def call(session_id:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        driver_manager.get_console_logs
      end
    end
  end
end
