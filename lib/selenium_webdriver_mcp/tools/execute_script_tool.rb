# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class ExecuteScriptTool < FastMcp::Tool
      tool_name "execute_script"
      description "Execute JavaScript in the browser context"

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
        required(:script).filled(:string).description("The JavaScript code to execute")
      end

      def call(session_id:, script:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        driver_manager.execute_script(script)
      end
    end
  end
end
