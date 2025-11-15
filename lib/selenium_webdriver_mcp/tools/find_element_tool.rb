# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class FindElementTool < FastMcp::Tool
      tool_name "find_element"
      description "Find an element on the page. Returns element_id for use with other tools. " \
                  "Strategies: id (fast), css (#id, .class, tag[attr='val']), xpath (use single quotes: " \
                  "\"//button[@id='btn']\"), link_text, partial_link_text, tag_name, class, name. " \
                  "XPath examples: //div[@class='container']//button, //button[contains(text(),'Click')]"

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
        required(:strategy).filled(:string).description("Locator strategy: id, css, xpath, link_text, partial_link_text, tag_name, class, name")
        required(:value).filled(:string).description("Selector value. For xpath use single quotes inside: \"//button[@id='test']\". For css use standard syntax: \"button#test\" or \".class-name\"")
      end

      def call(session_id:, strategy:, value:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        driver_manager.find_element(strategy, value)
      end
    end
  end
end
