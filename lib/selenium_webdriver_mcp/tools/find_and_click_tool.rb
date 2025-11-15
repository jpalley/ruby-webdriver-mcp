# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class FindAndClickTool < FastMcp::Tool
      tool_name "find_and_click"
      description "Find an element and click it atomically (prevents stale element errors). " \
                  "Strategies: id (recommended), css (#id, .class), xpath (use single quotes: " \
                  "\"//button[@id='submit']\"), link_text, partial_link_text. " \
                  "Common: id='submit-btn', css='button.primary', xpath=\"//button[text()='Submit']\", " \
                  "link_text='Click Here'"

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
        required(:strategy).filled(:string).description("Locator strategy: id, css, xpath, link_text, partial_link_text, tag_name, class, name")
        required(:value).filled(:string).description("Selector value. For xpath use single quotes inside: \"//button[@id='test']\". For css: \"button#test\", \".class-name\", \"[data-id='value']\"")
      end

      def call(session_id:, strategy:, value:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        driver_manager.find_and_click(strategy, value)
      end
    end
  end
end
