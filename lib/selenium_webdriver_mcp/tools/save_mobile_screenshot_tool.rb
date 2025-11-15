# frozen_string_literal: true

require "fast_mcp"
require "base64"

module SeleniumWebdriverMcp
  module Tools
    class SaveMobileScreenshotTool < FastMcp::Tool
      tool_name "save_mobile_screenshot"
      description "Capture a screenshot at standard mobile resolution (375x667, iPhone SE size). " \
                  "Temporarily resizes the browser window to mobile size, captures the screenshot, " \
                  "then restores the original window size. " \
                  "Returns the screenshot as an embedded image."

      # Standard mobile resolution (iPhone SE, iPhone 8)
      MOBILE_WIDTH = 375
      MOBILE_HEIGHT = 667

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
      end

      def call(session_id:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)

        # Get current URL
        current_url = driver_manager.current_url

        # Capture screenshot at mobile resolution
        result = driver_manager.screenshot_at_size(MOBILE_WIDTH, MOBILE_HEIGHT)
        screenshot_base64 = result[:screenshot]
        png_data = Base64.decode64(screenshot_base64)

        # Save to history
        ScreenshotHistory.instance.save_screenshot(session_id, png_data, current_url)

        # Return screenshot as embedded image
        {
          content: [{
            type: "image",
            data: screenshot_base64,
            mimeType: "image/png"
          }],
          metadata: {
            resolution: "mobile",
            width: MOBILE_WIDTH,
            height: MOBILE_HEIGHT,
            url: current_url
          }
        }
      end
    end
  end
end
