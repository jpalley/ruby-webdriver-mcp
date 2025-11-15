# frozen_string_literal: true

require "securerandom"

module SeleniumWebdriverMcp
  class SessionManager
    attr_reader :sessions

    MAX_SESSIONS = 10 # Maximum concurrent sessions to prevent resource exhaustion

    def initialize
      @sessions = {}
      @mutex = Mutex.new
      @session_timeout = 3600 # 1 hour default
    end

    # Create a new session
    def create_session(session_id: nil)
      session_id ||= generate_session_id
      thread_id = Thread.current.object_id

      warn "[Thread #{thread_id}] Creating session #{session_id} (current count: #{session_count})"

      # Cleanup if we're approaching the limit
      cleanup_if_needed

      @mutex.synchronize do
        raise Error, "Session #{session_id} already exists" if @sessions.key?(session_id)

        @sessions[session_id] = {
          driver_manager: DriverManager.new,
          created_at: Time.now,
          last_accessed: Time.now
        }
      end

      warn "[Thread #{thread_id}] Session #{session_id} created successfully (new count: #{session_count})"
      session_id
    end

    # Get a driver manager for a session
    # If auto_create is true (default), creates the session if it doesn't exist
    def get_driver_manager(session_id, auto_create: true)
      @mutex.synchronize do
        session = @sessions[session_id]

        # Auto-create session if it doesn't exist
        if !session && auto_create
          thread_id = Thread.current.object_id
          warn "[Thread #{thread_id}] Session #{session_id} not found, auto-creating..."

          # Create session without mutex (we're already inside it)
          @sessions[session_id] = {
            driver_manager: DriverManager.new,
            created_at: Time.now,
            last_accessed: Time.now
          }

          warn "[Thread #{thread_id}] Session #{session_id} auto-created successfully"
          session = @sessions[session_id]
        elsif !session && !auto_create
          raise Error, "Session #{session_id} not found"
        end

        session[:last_accessed] = Time.now
        session[:driver_manager]
      end
    end

    # Check if session exists
    def session_exists?(session_id)
      @mutex.synchronize do
        @sessions.key?(session_id)
      end
    end

    # Destroy a session
    def destroy_session(session_id)
      @mutex.synchronize do
        session = @sessions.delete(session_id)
        return false unless session

        # Clean up the driver
        begin
          session[:driver_manager].quit
        rescue StandardError => e
          warn "Error closing driver for session #{session_id}: #{e.message}"
        end

        true
      end
    end

    # List all sessions
    def list_sessions
      @mutex.synchronize do
        @sessions.map do |session_id, session|
          {
            session_id: session_id,
            created_at: session[:created_at],
            last_accessed: session[:last_accessed],
            active: session[:driver_manager].driver ? true : false
          }
        end
      end
    end

    # Clean up expired sessions
    def cleanup_expired_sessions
      expired_session_ids = []

      @mutex.synchronize do
        @sessions.each do |session_id, session|
          age = Time.now - session[:last_accessed]
          expired_session_ids << session_id if age > @session_timeout
        end
      end

      expired_session_ids.each do |session_id|
        warn "Cleaning up expired session: #{session_id}"
        destroy_session(session_id)
      end

      expired_session_ids.size
    end

    # Get session count
    def session_count
      @mutex.synchronize do
        @sessions.size
      end
    end

    # Destroy all sessions
    def destroy_all_sessions
      session_ids = @mutex.synchronize { @sessions.keys.dup }
      session_ids.each { |session_id| destroy_session(session_id) }
      session_ids.size
    end

    # Get all active Selenium sessions (from Selenium Grid)
    def get_selenium_sessions
      require "net/http"
      require "json"

      uri = URI(SeleniumWebdriverMcp.configuration.selenium_url.sub("/wd/hub", "/status"))

      # Use a fresh HTTP connection to avoid interfering with WebDriver's connection pool
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri.path.empty? ? "/status" : uri.path)
      response = http.request(request)
      status = JSON.parse(response.body)

      # Extract session information from Selenium Grid status
      sessions = []
      if status["value"] && status["value"]["nodes"]
        status["value"]["nodes"].each do |node|
          node["slots"].each do |slot|
            if slot["session"]
              sessions << {
                selenium_session_id: slot["session"]["sessionId"],
                capabilities: slot["session"]["capabilities"]
              }
            end
          end
        end
      end

      sessions
    rescue StandardError => e
      warn "Failed to get Selenium sessions: #{e.message}"
      []
    end

    # Cleanup orphaned Selenium sessions (not in our local store)
    def cleanup_orphaned_sessions
      selenium_sessions = get_selenium_sessions
      our_selenium_ids = []

      # Get all Selenium session IDs from our local sessions
      @mutex.synchronize do
        @sessions.each_value do |session|
          driver = session[:driver_manager].driver
          our_selenium_ids << driver.session_id if driver
        rescue StandardError
          # Ignore errors getting session ID
          nil
        end
      end

      # Find and cleanup orphaned sessions
      orphaned_count = 0
      selenium_sessions.each do |session|
        selenium_id = session[:selenium_session_id]
        next if our_selenium_ids.include?(selenium_id)

        # This is an orphaned session - delete it from Selenium
        begin
          delete_selenium_session(selenium_id)
          orphaned_count += 1
          warn "Cleaned up orphaned Selenium session: #{selenium_id}"
        rescue StandardError => e
          warn "Failed to cleanup orphaned session #{selenium_id}: #{e.message}"
        end
      end

      orphaned_count
    end

    # AGGRESSIVE cleanup - closes ALL Selenium sessions and resets our local state
    # Used for recovery from tab crashes and resource exhaustion
    def aggressive_cleanup!
      thread_id = Thread.current.object_id
      warn "[Thread #{thread_id}] ⚠️  AGGRESSIVE CLEANUP TRIGGERED - Closing ALL Selenium sessions"

      # Get all Selenium sessions before we start cleanup
      selenium_sessions = get_selenium_sessions
      total_selenium_sessions = selenium_sessions.size
      warn "[Thread #{thread_id}] Found #{total_selenium_sessions} active Selenium sessions"

      # Close ALL Selenium sessions (including orphaned ones)
      closed_count = 0
      selenium_sessions.each do |session|
        selenium_id = session[:selenium_session_id]
        begin
          delete_selenium_session(selenium_id)
          closed_count += 1
          warn "[Thread #{thread_id}] ✓ Closed Selenium session: #{selenium_id}"
        rescue StandardError => e
          warn "[Thread #{thread_id}] ✗ Failed to close Selenium session #{selenium_id}: #{e.message}"
        end
      end

      # Destroy all our local sessions
      local_sessions_destroyed = destroy_all_sessions
      warn "[Thread #{thread_id}] Destroyed #{local_sessions_destroyed} local sessions"

      # Wait a moment for Selenium to clean up
      sleep 2

      # Verify cleanup
      remaining = get_selenium_sessions.size
      warn "[Thread #{thread_id}] Aggressive cleanup complete: closed #{closed_count}/#{total_selenium_sessions} Selenium sessions, #{remaining} remain"

      {
        selenium_sessions_closed: closed_count,
        local_sessions_destroyed: local_sessions_destroyed,
        remaining_selenium_sessions: remaining
      }
    rescue StandardError => e
      warn "[Thread #{thread_id}] Error during aggressive cleanup: #{e.message}"
      warn e.backtrace.first(5).join("\n")
      { error: e.message }
    end

    # Delete a session directly from Selenium
    def delete_selenium_session(selenium_session_id)
      require "net/http"

      uri = URI("#{SeleniumWebdriverMcp.configuration.selenium_url}/session/#{selenium_session_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Delete.new(uri.path)
      response = http.request(request)

      # Ensure connection is properly closed
      http.finish if http.started?
      response
    rescue StandardError => e
      http.finish if http.started? rescue nil
      raise e
    end

    # Cleanup if we're approaching session limits
    # NOTE: This method is called during session creation and MUST NOT make HTTP calls
    # to avoid interfering with WebDriver's HTTP connection pool, which causes
    # "stream closed in another thread" errors (see GitHub SeleniumHQ/selenium#8413)
    def cleanup_if_needed
      current_count = session_count
      thread_id = Thread.current.object_id

      # If we're at or above 80% capacity, cleanup expired sessions first
      if current_count >= (MAX_SESSIONS * 0.8)
        warn "[Thread #{thread_id}] Approaching session limit (#{current_count}/#{MAX_SESSIONS}), cleaning up..."

        # Start with expired sessions (no HTTP calls, safe)
        expired_count = cleanup_expired_sessions
        warn "[Thread #{thread_id}] Cleaned up #{expired_count} expired sessions" if expired_count > 0

        # If still too high, cleanup oldest sessions (also no HTTP calls, safe)
        if session_count >= MAX_SESSIONS
          oldest_count = cleanup_oldest_sessions(session_count - MAX_SESSIONS + 1)
          warn "[Thread #{thread_id}] Cleaned up #{oldest_count} old sessions" if oldest_count > 0
        end

        # NOTE: We do NOT cleanup orphaned sessions here because it makes HTTP calls
        # to Selenium Grid which interfere with WebDriver's connection pool.
        # Use cleanup_orphaned_sessions() manually if needed (e.g., via background job).
        if session_count >= MAX_SESSIONS
          warn "[Thread #{thread_id}] Still at capacity (#{session_count}/#{MAX_SESSIONS}). " \
               "Cannot create new session. Consider calling cleanup_orphaned_sessions() manually."
        end
      end
    end

    # Cleanup the oldest sessions by last access time
    def cleanup_oldest_sessions(count)
      sessions_to_remove = []

      @mutex.synchronize do
        sorted_sessions = @sessions.sort_by { |_id, session| session[:last_accessed] }
        sessions_to_remove = sorted_sessions.first(count).map(&:first)
      end

      sessions_to_remove.each do |session_id|
        warn "Cleaning up old session due to capacity: #{session_id}"
        destroy_session(session_id)
      end

      sessions_to_remove.size
    end

    private

    def generate_session_id
      "session_#{SecureRandom.hex(16)}"
    end

    # Singleton instance
    class << self
      attr_writer :instance

      def instance
        @instance ||= new
      end

      def reset!
        @instance&.destroy_all_sessions
        @instance = new
      end
    end
  end
end
