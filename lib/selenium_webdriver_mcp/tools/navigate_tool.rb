# frozen_string_literal: true

require "fast_mcp"

module SeleniumWebdriverMcp
  module Tools
    class NavigateTool < FastMcp::Tool
      tool_name "navigate"
      description "Navigate the browser to a URL"

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
        required(:url).filled(:string).description("The URL to navigate to")
      end

      def call(session_id:, url:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)
        rewritten_url = rewrite_localhost(url)
        driver_manager.navigate_to(rewritten_url)
      end

      private

      def rewrite_localhost(url)
        # Get the rewrite target from configuration
        rewrite_target = SeleniumWebdriverMcp.configuration.rewrite_localhost_to
        return url if rewrite_target.nil? || rewrite_target.empty?

        # Rewrite localhost and 127.0.0.1 to the configured host
        url.gsub(%r{//localhost(:|/)}, "//#{rewrite_target}\\1")
           .gsub(%r{//127\.0\.0\.1(:|/)}, "//#{rewrite_target}\\1")
      end
    end
  end
end
