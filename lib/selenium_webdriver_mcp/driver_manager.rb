# frozen_string_literal: true

require "selenium-webdriver"
require_relative "thread_safe_http_client"

module SeleniumWebdriverMcp
  class DriverManager
    attr_reader :driver

    NETWORK_ERROR_CLASSES = [
      Net::ReadTimeout,
      Net::OpenTimeout,
      Errno::ECONNRESET,
      Errno::EPIPE,
      EOFError,
      IOError
    ].freeze

    NETWORK_ERROR_MESSAGE_PATTERNS = [
      /timed out/i,
      /connection reset/i,
      /Failed to establish/i,
      /Broken pipe/i
    ].freeze

    def initialize(config = SeleniumWebdriverMcp.configuration)
      @config = config
      @driver = nil
      @element_cache = {}
      @driver_mutex = Mutex.new
      @http_client = nil
      @open_timeout = 60
      @read_timeout = 60
    end

    def start(retry_count: 0)
      return driver if driver

      thread_id = Thread.current.object_id
      warn "[Thread #{thread_id}] Starting WebDriver (connecting to #{@config.selenium_url})"

      begin
        # Create a thread-safe HTTP client to prevent "stream closed in another thread" errors
        # This is critical for multi-threaded environments like Rack/Sinatra/WEBrick
        @http_client = ThreadSafeHttpClient.new(
          open_timeout: @open_timeout,
          read_timeout: @read_timeout
        )

        @driver_mutex.synchronize do
          @driver = Selenium::WebDriver.for(
            :remote,
            url: @config.selenium_url,
            options: @config.browser_options,
            http_client: @http_client
          )

          # Set timeouts
          @driver.manage.timeouts.implicit_wait = @config.implicit_wait
          @driver.manage.timeouts.page_load = @config.page_load_timeout
          @driver.manage.timeouts.script_timeout = @config.script_timeout
        end

        warn "[Thread #{thread_id}] WebDriver started successfully (session_id: #{@driver.session_id})"
        driver
      rescue Selenium::WebDriver::Error::WebDriverError => e
        # Check if error indicates no available sessions
        if retry_count == 0 && session_capacity_error?(e)
          warn "[Thread #{thread_id}] Selenium has no available sessions. Running orphaned cleanup and retrying..."

          # Run orphaned cleanup to free up Selenium sessions
          cleanup_count = SessionManager.instance.cleanup_orphaned_sessions
          warn "[Thread #{thread_id}] Cleaned up #{cleanup_count} orphaned sessions"

          # Retry once
          return start(retry_count: 1)
        end

        # Re-raise if not a capacity error or already retried
        raise
      end
    end

    def quit
      return unless driver

      @driver_mutex.synchronize do
        driver&.quit
        @driver = nil
        @element_cache.clear
      end
    end

    def ensure_started
      start unless driver
      driver
    end

    # Navigation methods
    def navigate_to(url)
      thread_id = Thread.current.object_id
      start_time = Time.now
      warn "[Thread #{thread_id}] Navigating to: #{url}"

      with_crash_recovery("navigate_to(#{url})") do
        with_network_retries("navigate_to(#{url})") do
          ensure_started.navigate.to(url)
        end

        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Navigation successful: #{current_url} (took #{elapsed}s)"
        { success: true, url: current_url }
      rescue Selenium::WebDriver::Error::WebDriverError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Navigation FAILED after #{elapsed}s: #{e.class} - #{e.message}"
        warn "[Thread #{thread_id}] Browser session_id: #{@driver&.session_id}"
        warn "[Thread #{thread_id}] Active sessions: #{SessionManager.instance.session_count}"
        raise
      end
    end

    def current_url
      ensure_started.current_url
    end

    def page_title
      ensure_started.title
    end

    # Element finding methods
    def find_element(strategy, value)
      thread_id = Thread.current.object_id
      start_time = Time.now

      # Normalize strategy to handle common variations
      normalized_strategy = normalize_strategy(strategy)
      warn "[Thread #{thread_id}] Finding element: strategy=#{normalized_strategy}, value=#{value}"

      with_crash_recovery("find_element(#{normalized_strategy}, #{value})") do
        element = with_network_retries("find_element(#{normalized_strategy}, #{value})") do
          ensure_started.find_element(normalized_strategy, value)
        end
        element_id = cache_element(element)
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Element found: #{element_id} (took #{elapsed}s)"
        serialize_element(element, element_id)
      rescue Selenium::WebDriver::Error::InvalidSelectorError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] INVALID SELECTOR after #{elapsed}s"
        warn "[Thread #{thread_id}] Strategy: #{normalized_strategy}, Value: #{value}"
        warn "[Thread #{thread_id}] Error: #{e.message}"
        # Re-raise original error to preserve error type for proper handling
        raise e
      rescue Selenium::WebDriver::Error::NoSuchElementError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Element NOT FOUND after #{elapsed}s"
        warn "[Thread #{thread_id}] Strategy: #{normalized_strategy}, Value: #{value}"
        warn "[Thread #{thread_id}] Current URL: #{begin
          current_url
        rescue StandardError
          "unknown"
        end}"
        # Re-raise original error to preserve error type for proper handling
        raise e
      rescue Selenium::WebDriver::Error::WebDriverError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Find element FAILED after #{elapsed}s: #{e.class} - #{e.message}"
        warn "[Thread #{thread_id}] Strategy: #{normalized_strategy}, Value: #{value}"
        warn "[Thread #{thread_id}] Current URL: #{begin
          current_url
        rescue StandardError
          "unknown"
        end}"
        warn "[Thread #{thread_id}] Browser session_id: #{@driver&.session_id}"
        warn "[Thread #{thread_id}] Active sessions: #{SessionManager.instance.session_count}"
        raise
      end
    end

    def find_elements(strategy, value)
      elements = with_network_retries("find_elements(#{strategy}, #{value})") do
        ensure_started.find_elements(strategy.to_sym, value)
      end
      elements.map do |element|
        element_id = cache_element(element)
        serialize_element(element, element_id)
      end
    end

    # Element interaction methods
    def click_element(element_id)
      thread_id = Thread.current.object_id
      start_time = Time.now
      warn "[Thread #{thread_id}] Clicking element: #{element_id}"

      with_crash_recovery("click_element(#{element_id})") do
        element = get_cached_element(element_id)
        element.click
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Click successful (took #{elapsed}s)"
        { success: true }
      rescue Selenium::WebDriver::Error::WebDriverError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Click FAILED after #{elapsed}s: #{e.class} - #{e.message}"
        warn "[Thread #{thread_id}] Current URL: #{begin
          current_url
        rescue StandardError
          "unknown"
        end}"
        warn "[Thread #{thread_id}] Browser session_id: #{@driver&.session_id}"
        warn "[Thread #{thread_id}] Active sessions: #{SessionManager.instance.session_count}"
        raise
      end
    end

    # Combined find and click - avoids stale element errors
    def find_and_click(strategy, value)
      thread_id = Thread.current.object_id
      start_time = Time.now

      # Normalize strategy to handle common variations
      normalized_strategy = normalize_strategy(strategy)
      warn "[Thread #{thread_id}] Find-and-click: strategy=#{normalized_strategy}, value=#{value}"

      with_crash_recovery("find_and_click(#{normalized_strategy}, #{value})") do
        element_id = with_network_retries("find_and_click(#{normalized_strategy}, #{value})") do
          element = ensure_started.find_element(normalized_strategy, value)
          warn "[Thread #{thread_id}] Element found, now clicking..."
          element.click

          # Cache the element for potential future reference
          cache_element(element)
        end

        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Find-and-click successful: #{element_id} (took #{elapsed}s)"

        {
          success: true,
          element_id: element_id,
          message: "Element found and clicked successfully"
        }
      rescue Selenium::WebDriver::Error::InvalidSelectorError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] INVALID SELECTOR after #{elapsed}s"
        warn "[Thread #{thread_id}] Strategy: #{normalized_strategy}, Value: #{value}"
        # Re-raise original error to preserve error type for proper handling
        raise e
      rescue Selenium::WebDriver::Error::NoSuchElementError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Element NOT FOUND after #{elapsed}s"
        warn "[Thread #{thread_id}] Strategy: #{normalized_strategy}, Value: #{value}"
        # Re-raise original error to preserve error type for proper handling
        raise e
      rescue Selenium::WebDriver::Error::WebDriverError => e
        elapsed = (Time.now - start_time).round(2)
        warn "[Thread #{thread_id}] Find-and-click FAILED after #{elapsed}s: #{e.class} - #{e.message}"
        warn "[Thread #{thread_id}] Strategy: #{normalized_strategy}, Value: #{value}"
        warn "[Thread #{thread_id}] Current URL: #{begin
          current_url
        rescue StandardError
          "unknown"
        end}"
        warn "[Thread #{thread_id}] Browser session_id: #{@driver&.session_id}"
        warn "[Thread #{thread_id}] Active sessions: #{SessionManager.instance.session_count}"
        raise
      end
    end

    def send_keys(element_id, text)
      element = get_cached_element(element_id)
      element.send_keys(text)
      { success: true }
    end

    def clear_element(element_id)
      element = get_cached_element(element_id)
      element.clear
      { success: true }
    end

    def submit_element(element_id)
      element = get_cached_element(element_id)
      element.submit
      { success: true }
    end

    # Element information methods
    def element_displayed?(element_id)
      element = get_cached_element(element_id)
      { displayed: element.displayed? }
    end

    def element_enabled?(element_id)
      element = get_cached_element(element_id)
      { enabled: element.enabled? }
    end

    # JavaScript execution
    def execute_script(script, *args)
      result = ensure_started.execute_script(script, *args)
      { result: result }
    end

    # Console logs
    def get_console_logs
      logs = ensure_started.logs.get(:browser)
      {
        logs: logs.map do |log|
          {
            level: log.level,
            message: log.message,
            timestamp: log.timestamp
          }
        end
      }
    rescue Selenium::WebDriver::Error::WebDriverError => e
      { logs: [], error: "Console logs not available: #{e.message}" }
    end

    # Window management
    def get_window_size
      size = ensure_started.manage.window.size
      { width: size.width, height: size.height }
    end

    def set_window_size(width, height)
      ensure_started.manage.window.resize_to(width, height)
      { width: width, height: height }
    end

    # Screenshot with window resize
    def screenshot_at_size(width, height)
      # Get current window size
      original_size = ensure_started.manage.window.size

      begin
        # Resize to desired size
        ensure_started.manage.window.resize_to(width, height)

        # Wait a moment for resize to complete
        sleep 0.5

        # Take screenshot
        screenshot_base64 = ensure_started.screenshot_as(:base64)

        {
          screenshot: screenshot_base64,
          width: width,
          height: height
        }
      ensure
        # Restore original size
        ensure_started.manage.window.resize_to(original_size.width, original_size.height)
      end
    end

    # Forward the command to the Selenium WebDriver driver
    def forward(command_name, command_params)
      operation = "forward(#{command_name})"
      with_network_retries(operation) do
        method_name = command_name.respond_to?(:to_sym) ? command_name.to_sym : command_name
        params = command_params || {}
        ensure_started.public_send(method_name, **params)
      end
    end

    def create_session
      @driver.start_session
    end

    private

    def with_network_retries(operation_name, max_attempts: 2)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue StandardError => e
        raise unless network_error?(e)

        if attempts < max_attempts
          reset_driver_connection!(operation_name: operation_name, exception: e, attempt: attempts)
          retry
        else
          reset_driver_connection!(operation_name: operation_name, exception: e, attempt: attempts, restart: false)
          warn "[Thread #{Thread.current.object_id}] Network error during #{operation_name} exhausted retries: #{e.class} - #{e.message}"
          raise
        end
      end
    end

    def reset_driver_connection!(operation_name:, exception:, attempt:, restart: true)
      thread_id = Thread.current.object_id
      warn "[Thread #{thread_id}] Network issue during #{operation_name} (attempt #{attempt}): #{exception.class} - #{exception.message}"

      old_driver = nil

      @driver_mutex.synchronize do
        old_driver = @driver
        @driver = nil
        @element_cache.clear

        begin
          @http_client&.close
        rescue StandardError => e
          warn "[Thread #{thread_id}] Error closing HTTP client during reset: #{e.class} - #{e.message}"
        ensure
          @http_client = nil
        end
      end

      begin
        old_driver&.quit
      rescue StandardError => e
        warn "[Thread #{thread_id}] Error quitting driver during reset: #{e.class} - #{e.message}"
      end

      sleep 0.5
      start if restart
    end

    def network_error?(error)
      return true if NETWORK_ERROR_CLASSES.any? { |klass| error.is_a?(klass) }

      message = error.respond_to?(:message) ? error.message : nil
      return true if message && NETWORK_ERROR_MESSAGE_PATTERNS.any? { |pattern| message.match?(pattern) }

      cause = error.respond_to?(:cause) ? error.cause : nil
      cause && cause != error && network_error?(cause)
    end

    # Normalize locator strategy to handle common variations
    # Selenium supports: :id, :name, :class, :class_name, :css, :tag_name, :xpath, :link_text, :partial_link_text
    def normalize_strategy(strategy)
      strategy_str = strategy.to_s.downcase.strip

      # Map common variations to Selenium's expected symbols
      case strategy_str
      when "css_selector", "cssselector"
        :css
      when "class_name", "classname"
        :class_name
      when "link", "linktext"
        :link_text
      when "partial_link", "partiallinktext", "partial_link_text"
        :partial_link_text
      when "tag", "tagname", "tag_name"
        :tag_name
      when "id", "name", "class", "css", "xpath"
        strategy_str.to_sym
      else
        # Try as-is if not recognized, let Selenium handle validation
        warn "  ⚠️  Unrecognized strategy '#{strategy}', passing through to Selenium"
        strategy_str.to_sym
      end
    end

    # Check if the error indicates Selenium has no available sessions
    def session_capacity_error?(error)
      error.message.match?(/session.*not.*created|cannot.*create.*session|session.*limit|exhausted|no.*session.*available/i)
    end

    # Check if the error is a tab crash or resource exhaustion
    def tab_crash_or_resource_error?(error)
      return false unless error.is_a?(Selenium::WebDriver::Error::WebDriverError)

      error.message.match?(/tab crashed|renderer.*unresponsive|out of memory|session.*deleted|session.*not.*exist|disconnected|chrome.*crashed|process.*crash/i)
    end

    # Execute an operation with automatic retry on tab crash
    # On crash: triggers aggressive cleanup and retries once
    def with_crash_recovery(operation_name)
      thread_id = Thread.current.object_id
      attempts = 0
      max_attempts = 2

      begin
        attempts += 1
        yield
      rescue Selenium::WebDriver::Error::WebDriverError => e
        if tab_crash_or_resource_error?(e) && attempts < max_attempts
          warn "[Thread #{thread_id}] 💥 TAB CRASH DETECTED during #{operation_name}!"
          warn "[Thread #{thread_id}] Error: #{e.class} - #{e.message}"
          warn "[Thread #{thread_id}] Triggering aggressive cleanup and retry (attempt #{attempts}/#{max_attempts})..."

          # Trigger aggressive cleanup
          cleanup_result = SessionManager.instance.aggressive_cleanup!
          warn "[Thread #{thread_id}] Cleanup result: #{cleanup_result.inspect}"

          # Mark our driver as nil since it's been cleaned up
          @driver_mutex.synchronize do
            @driver = nil
            @element_cache.clear
          end

          # Wait for things to settle
          sleep 3

          # Retry the operation
          warn "[Thread #{thread_id}] Retrying #{operation_name}..."
          retry
        else
          # Either not a tab crash or we've exhausted retries
          if attempts >= max_attempts
            warn "[Thread #{thread_id}] ❌ #{operation_name} failed after #{attempts} attempts, giving up"
          end
          raise
        end
      end
    end

    def cache_element(element)
      @driver_mutex.synchronize do
        element_id = "element_#{@element_cache.size}"
        @element_cache[element_id] = element
        element_id
      end
    end

    def get_cached_element(element_id)
      @driver_mutex.synchronize do
        element = @element_cache[element_id]
        raise Error, "Element not found in cache: #{element_id}" unless element

        element
      end
    end

    def serialize_element(element, element_id)
      {
        element_id: element_id,
        tag_name: element.tag_name,
        text: element.text,
        displayed: element.displayed?,
        enabled: element.enabled?
      }
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      { element_id: element_id, stale: true }
    end
  end
end
