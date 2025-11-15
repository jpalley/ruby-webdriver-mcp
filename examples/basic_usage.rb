#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of using the Selenium WebDriver MCP gem programmatically

require "bundler/setup"
require "selenium_webdriver_mcp"

# Configure the gem
SeleniumWebdriverMcp.configure do |config|
  config.selenium_url = ENV.fetch("SELENIUM_URL", "http://localhost:4444/wd/hub")
  config.browser = :chrome
  config.headless = true
end

# Create a driver manager instance
driver_manager = SeleniumWebdriverMcp::DriverManager.new

begin
  # Start the browser
  puts "Starting browser..."
  driver_manager.start

  # Navigate to a URL
  puts "Navigating to https://example.com..."
  result = driver_manager.navigate_to("https://example.com")
  puts "Current URL: #{result[:url]}"

  # Find an element
  puts "\nFinding h1 element..."
  element = driver_manager.find_element(:tag_name, "h1")
  puts "Found element: #{element[:element_id]}"
  puts "Element text: #{element[:text]}"

  # Get page title
  puts "\nPage title: #{driver_manager.page_title}"

  # Execute JavaScript
  puts "\nExecuting JavaScript..."
  js_result = driver_manager.execute_script("return document.title")
  puts "JavaScript result: #{js_result[:result]}"

  # Take a screenshot
  puts "\nTaking screenshot..."
  screenshot = driver_manager.take_screenshot
  puts "Screenshot taken (base64 length: #{screenshot[:screenshot].length})"

  # Get console logs
  puts "\nGetting console logs..."
  logs = driver_manager.get_console_logs
  if logs[:logs].any?
    puts "Console logs:"
    logs[:logs].each do |log|
      puts "  [#{log[:level]}] #{log[:message]}"
    end
  else
    puts "No console logs found"
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  # Clean up
  puts "\nClosing browser..."
  driver_manager.quit
end

puts "\nDone!"
