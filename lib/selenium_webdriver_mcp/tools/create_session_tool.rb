# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class CreateSessionTool < FastMcp::Tool
      tool_name "create_session"
      description "Create a new browser session. OPTIONAL: Sessions are auto-created if you provide a " \
                  "custom session_id to other tools (navigate, find_element, etc). Use this tool when you " \
                  "want an auto-generated session_id or need explicit control. Example: create_session() " \
                  "returns session_id, or skip and use navigate(session_id='my-session', url='...')"

      arguments do
        optional(:session_id).filled(:string).description("Optional custom session ID. If omitted, auto-generates like 'session_abc123'. If you provide a custom ID here and it doesn't exist, creates it. If you skip create_session entirely and use a custom ID in other tools, the session will be auto-created.")
      end

      def call(session_id: nil)
        session_manager = SessionManager.instance
        new_session_id = session_manager.create_session(session_id: session_id)

        # Return JSON string for consistent formatting
        JSON.generate({
          success: true,
          session_id: new_session_id,
          message: "Session created successfully. Use this session_id in subsequent tool calls."
        })
      rescue Error => e
        JSON.generate({
          success: false,
          error: e.message
        })
      end
    end
  end
end
