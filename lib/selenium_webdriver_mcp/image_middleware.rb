# frozen_string_literal: true

require "base64"

module SeleniumWebdriverMcp
  # Rack middleware for serving screenshots as PNG images via HTTP
  # Provides direct browser access to screenshots at GET /screenshots/{session_id}
  class ImageMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      # Check if request is for a screenshot
      if env["PATH_INFO"] =~ %r{^/screenshots/([^/]+)/([^/]+\.png)$}
        # Historical screenshot: /screenshots/{session_id}/{filename}.png
        session_id = ::Regexp.last_match(1)
        filename = ::Regexp.last_match(2)
        serve_historical_screenshot(session_id, filename)
      elsif env["PATH_INFO"] =~ %r{^/screenshots/([^/]+)$}
        # Current screenshot: /screenshots/{session_id}
        session_id = ::Regexp.last_match(1)
        serve_current_screenshot(session_id)
      else
        # Pass through to the next middleware/app
        @app.call(env)
      end
    end

    private

    def serve_current_screenshot(session_id)
      # Get the driver manager for this session
      driver_manager = SessionManager.instance.get_driver_manager(session_id)

      # Get screenshot as base64 from Selenium and decode to binary PNG
      screenshot_base64 = driver_manager.ensure_started.screenshot_as(:base64)
      png_data = Base64.decode64(screenshot_base64)

      # Return raw PNG with proper content type
      [200,
       {
         "content-type" => "image/png",
         "content-length" => png_data.bytesize.to_s,
         "cache-control" => "no-cache"
       },
       [png_data]]
    rescue Error => e
      # Session not found or other application error
      [404,
       { "content-type" => "text/plain" },
       ["Screenshot not found: #{e.message}"]]
    rescue StandardError => e
      # Unexpected error
      [500,
       { "content-type" => "text/plain" },
       ["Error capturing screenshot: #{e.message}"]]
    end

    def serve_historical_screenshot(session_id, filename)
      # Get screenshot from history
      filepath = ScreenshotHistory.instance.get_screenshot_path(session_id, filename)

      unless filepath
        return [404,
                { "content-type" => "text/plain" },
                ["Screenshot not found"]]
      end

      # Read and serve the PNG file
      png_data = File.binread(filepath)

      [200,
       {
         "content-type" => "image/png",
         "content-length" => png_data.bytesize.to_s,
         "cache-control" => "public, max-age=31536000" # Historical screenshots are immutable
       },
       [png_data]]
    rescue StandardError => e
      [500,
       { "content-type" => "text/plain" },
       ["Error serving screenshot: #{e.message}"]]
    end
  end
end
