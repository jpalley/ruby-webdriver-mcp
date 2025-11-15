# frozen_string_literal: true

module SeleniumWebdriverMcp
  class Configuration
    attr_accessor :selenium_url, :browser, :headless, :implicit_wait, :page_load_timeout,
                  :script_timeout, :window_size, :capabilities, :rewrite_localhost_to

    def initialize
      @selenium_url = ENV.fetch("SELENIUM_URL", "http://localhost:4444/wd/hub")
      @browser = :chrome
      @headless = true
      @implicit_wait = 10 # seconds
      @page_load_timeout = 30 # seconds
      @script_timeout = 30 # seconds
      @window_size = [1400, 1400]
      @capabilities = {}
      @rewrite_localhost_to = ENV.fetch("REWRITE_LOCALHOST_TO", nil)
    end

    def browser_options
      options_class = case browser
                      when :chrome
                        Selenium::WebDriver::Chrome::Options
                      when :firefox
                        Selenium::WebDriver::Firefox::Options
                      when :edge
                        Selenium::WebDriver::Edge::Options
                      else
                        raise Error, "Unsupported browser: #{browser}"
                      end

      options = options_class.new
      options.add_argument("--headless") if headless
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--window-size=#{window_size.join(",")}")

      # Additional stability flags to prevent tab crashes
      options.add_argument("--disable-gpu") if headless
      options.add_argument("--disable-software-rasterizer")
      options.add_argument("--disable-extensions")
      options.add_argument("--disable-background-networking")
      options.add_argument("--disable-background-timer-throttling")
      options.add_argument("--disable-backgrounding-occluded-windows")
      options.add_argument("--disable-breakpad")
      options.add_argument("--disable-component-extensions-with-background-pages")
      options.add_argument("--disable-features=TranslateUI,BlinkGenPropertyTrees")
      options.add_argument("--disable-ipc-flooding-protection")
      options.add_argument("--disable-renderer-backgrounding")
      options.add_argument("--enable-features=NetworkService,NetworkServiceInProcess")
      options.add_argument("--force-color-profile=srgb")
      options.add_argument("--hide-scrollbars")
      options.add_argument("--metrics-recording-only")
      options.add_argument("--mute-audio")

      # Memory management
      options.add_argument("--disable-features=site-per-process")
      options.add_argument("--js-flags=--max-old-space-size=512")

      # Merge custom capabilities
      capabilities.each do |key, value|
        options.add_option(key, value)
      end

      options
    end
  end
end
