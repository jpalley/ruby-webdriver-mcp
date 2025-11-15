# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class DestroySessionTool < FastMcp::Tool
      tool_name "destroy_session"
      description "Destroy a browser session and close the browser"

      arguments do
        required(:session_id).filled(:string).description("The session ID to destroy")
      end

      def call(session_id:)
        session_manager = SessionManager.instance
        success = session_manager.destroy_session(session_id)

        if success
          JSON.generate({
            success: true,
            message: "Session #{session_id} destroyed successfully"
          })
        else
          JSON.generate({
            success: false,
            error: "Session #{session_id} not found"
          })
        end
      end
    end
  end
end
