# frozen_string_literal: true

require "fileutils"
require "json"

module SeleniumWebdriverMcp
  # Manages screenshot history for browser sessions
  # Stores screenshots to disk and tracks metadata
  class ScreenshotHistory
    MAX_SCREENSHOTS_PER_SESSION = 10

    def initialize(storage_dir: "public/screenshots")
      @storage_dir = storage_dir
      @history = {} # session_id => [{timestamp, url, filename}, ...]
      @mutex = Mutex.new
      ensure_storage_directory
    end

    # Save a screenshot for a session
    # @param session_id [String] The session ID
    # @param png_data [String] Raw PNG binary data
    # @param url [String] The current URL when screenshot was taken
    # @return [Hash] Screenshot metadata
    def save_screenshot(session_id, png_data, url)
      @mutex.synchronize do
        # Use millisecond precision to avoid filename collisions
        timestamp = (Time.now.to_f * 1000).to_i
        filename = "#{timestamp}.png"
        session_dir = File.join(@storage_dir, session_id)

        # Ensure session directory exists
        FileUtils.mkdir_p(session_dir)

        # Write PNG file
        filepath = File.join(session_dir, filename)
        File.binwrite(filepath, png_data)

        # Add to history
        @history[session_id] ||= []
        metadata = {
          timestamp: timestamp,
          url: url,
          filename: filename,
          path: "/screenshots/#{session_id}/#{filename}"
        }
        @history[session_id] << metadata

        # Cleanup old screenshots if exceeding limit
        cleanup_old_screenshots(session_id)

        metadata
      end
    end

    # Get screenshot history for a session
    # @param session_id [String] The session ID
    # @return [Array<Hash>] Array of screenshot metadata, newest first
    def get_history(session_id)
      @mutex.synchronize do
        (@history[session_id] || []).reverse
      end
    end

    # Get all sessions with screenshot history
    # @return [Array<String>] Array of session IDs
    def sessions_with_history
      @mutex.synchronize do
        @history.keys
      end
    end

    # Get count of screenshots for a session
    # @param session_id [String] The session ID
    # @return [Integer] Number of screenshots
    def get_screenshot_count(session_id)
      @mutex.synchronize do
        (@history[session_id] || []).length
      end
    end

    # Cleanup all screenshots for a session
    # @param session_id [String] The session ID
    def cleanup_session(session_id)
      @mutex.synchronize do
        session_dir = File.join(@storage_dir, session_id)
        FileUtils.rm_rf(session_dir) if File.directory?(session_dir)
        @history.delete(session_id)
      end
    end

    # Get a screenshot file path
    # @param session_id [String] The session ID
    # @param filename [String] The screenshot filename
    # @return [String, nil] Full path to screenshot file or nil if not found
    def get_screenshot_path(session_id, filename)
      filepath = File.join(@storage_dir, session_id, filename)
      File.exist?(filepath) ? filepath : nil
    end

    class << self
      # Get the singleton instance
      def instance
        @instance ||= new
      end
    end

    private

    def ensure_storage_directory
      FileUtils.mkdir_p(@storage_dir) unless File.directory?(@storage_dir)
    end

    def cleanup_old_screenshots(session_id)
      screenshots = @history[session_id]
      return if screenshots.length <= MAX_SCREENSHOTS_PER_SESSION

      # Remove oldest screenshots
      to_remove = screenshots.shift(screenshots.length - MAX_SCREENSHOTS_PER_SESSION)
      to_remove.each do |screenshot|
        filepath = File.join(@storage_dir, session_id, screenshot[:filename])
        File.delete(filepath) if File.exist?(filepath)
      end
    end
  end
end
