# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class ClickTool < FastMcp::Tool
      tool_name "click_element"
      description "Click a previously found element. Note: For better reliability, use find_and_click instead. " \
                  "Requires element_id from find_element (format: 'element_0', 'element_1', etc). " \
                  "May fail with stale element error if page changed since find_element was called."

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
        required(:element_id).filled(:string).description("The element_id from find_element response (e.g., 'element_0'). Use find_and_click for atomic operations.")
      end

      def call(session_id:, element_id:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        driver_manager.click_element(element_id)
      end
    end
  end
end
