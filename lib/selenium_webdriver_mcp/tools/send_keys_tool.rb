# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class SendKeysTool < FastMcp::Tool
      tool_name "send_keys"
      description "Type text into a previously found input element. First use find_element with " \
                  "strategy='name' or 'css' to find the input (e.g., name='username', css='input[type=\"email\"]'), " \
                  "then use the returned element_id here."

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
        required(:element_id).filled(:string).description("The element_id from find_element response (e.g., 'element_0')")
        required(:text).filled(:string).description("The text to type into the element. For special keys use Selenium key constants.")
      end

      def call(session_id:, element_id:, text:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        driver_manager.send_keys(element_id, text)
      end
    end
  end
end
