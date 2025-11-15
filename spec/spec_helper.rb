# frozen_string_literal: true

require "selenium_webdriver_mcp"
require "base64"

# Configure for integration tests
SeleniumWebdriverMcp.configure do |config|
  config.selenium_url = ENV.fetch("SELENIUM_URL", "http://localhost:4444/wd/hub")
  config.browser = :chrome
  config.headless = true
  config.implicit_wait = 5
  config.page_load_timeout = 30
  config.script_timeout = 30
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter integration tests
  config.filter_run_when_matching :focus

  # Clean up sessions between test files
  config.before(:suite) do
    SeleniumWebdriverMcp::SessionManager.instance.destroy_all_sessions
  end

  config.after(:suite) do
    SeleniumWebdriverMcp::SessionManager.instance.destroy_all_sessions
  end
end
