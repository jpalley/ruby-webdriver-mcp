# frozen_string_literal: true

require "selenium-webdriver"

module SeleniumWebdriverMcp
  # Thread-safe HTTP client wrapper for Selenium WebDriver
  #
  # This class wraps Selenium's default HTTP client and adds thread-safety
  # by serializing all HTTP requests through a Mutex. This prevents the
  # "stream closed in another thread" error that occurs when multiple
  # threads try to use the same Net::HTTP connection concurrently.
  #
  # Background:
  # - WEBrick spawns a new thread for each HTTP request
  # - SessionManager stores DriverManager instances that persist across requests
  # - Each WebDriver instance caches a Net::HTTP connection
  # - Net::HTTP is NOT thread-safe - it has a single socket
  # - When Thread A (create_session) and Thread B (navigate) both use
  #   the same WebDriver instance, they share the same Net::HTTP socket
  # - This causes "stream closed in another thread" errors
  #
  # Solution:
  # - Use a Mutex to ensure only one thread can make HTTP requests at a time
  # - This serializes access to the underlying Net::HTTP connection
  # - Maintains connection reuse benefits while preventing concurrent access
  #
  # Usage:
  #   client = ThreadSafeHttpClient.new
  #   driver = Selenium::WebDriver.for(:remote, url: url, http_client: client)
  class ThreadSafeHttpClient < Selenium::WebDriver::Remote::Http::Default
    def initialize(open_timeout: nil, read_timeout: nil)
      super(open_timeout: open_timeout, read_timeout: read_timeout)
      @mutex = Mutex.new
    end

    def reconnect(open_timeout: nil, read_timeout: nil)
      @mutex.synchronize do
        close
        # Re-initialize the connection by calling the parent's constructor again
        # This is a bit of a hack, but it's the cleanest way to reset the state
        super(open_timeout: open_timeout, read_timeout: read_timeout)
      end
    end

    # Override the request method to add thread-safety
    def call(verb, url, command_hash)
      @mutex.synchronize do
        super(verb, url, command_hash)
      end
    end

    # Override close to ensure proper cleanup
    def close
      @mutex.synchronize do
        super
      end
    end
  end
end
