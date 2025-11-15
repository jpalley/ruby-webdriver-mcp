# frozen_string_literal: true

require "fast_mcp"
require "base64"

module SeleniumWebdriverMcp
  module Tools
    class SaveDesktopScreenshotTool < FastMcp::Tool
      tool_name "save_desktop_screenshot"
      description "Capture a screenshot at standard desktop resolution (1920x1080). " \
                  "Temporarily resizes the browser window to desktop size, captures the screenshot, " \
                  "then restores the original window size. " \
                  "Returns the screenshot as an embedded image."

      # Standard desktop resolution (Full HD)
      DESKTOP_WIDTH = 1920
      DESKTOP_HEIGHT = 1080

      arguments do
        required(:session_id).filled(:string).description("The browser session ID")
      end

      def call(session_id:)
        driver_manager = SessionManager.instance.get_driver_manager(session_id)

        # Get current URL
        current_url = driver_manager.current_url

        # Capture screenshot at desktop resolution
        result = driver_manager.screenshot_at_size(DESKTOP_WIDTH, DESKTOP_HEIGHT)
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
            resolution: "desktop",
            width: DESKTOP_WIDTH,
            height: DESKTOP_HEIGHT,
            url: current_url
          }
        }
      end
    end
  end
end
