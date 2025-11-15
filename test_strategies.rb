#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/selenium_webdriver_mcp'
require_relative 'spec/support/test_html_server'

# Start test server
TestHtmlServer.start

session_manager = SeleniumWebdriverMcp::SessionManager.instance
session_id = session_manager.create_session
driver_manager = session_manager.get_driver_manager(session_id)

# Navigate to test page
puts "Navigating to test page..."
driver_manager.navigate_to(TestHtmlServer.url('/index.html'))
puts "Page loaded"
puts

puts "Testing different locator strategies:"
puts "=" * 60
puts

# Test by ID
puts "1. By ID (id='test-button'):"
begin
  result = driver_manager.find_element('id', 'test-button')
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ✗ Failed: #{e.class} - #{e.message[0..100]}"
end
puts

# Test by XPath
puts "2. By XPath (//button[@id='test-button']):"
begin
  result = driver_manager.find_element('xpath', "//button[@id='test-button']")
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ✗ Failed: #{e.class} - #{e.message[0..100]}"
end
puts

# Test by CSS
puts "3. By CSS (button#test-button):"
begin
  result = driver_manager.find_element('css', 'button#test-button')
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ✗ Failed: #{e.class} - #{e.message[0..100]}"
end
puts

# Test by link_text
puts "4. By link_text ('Go to Form'):"
begin
  result = driver_manager.find_element('link_text', 'Go to Form')
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ✗ Failed: #{e.class} - #{e.message[0..100]}"
end
puts

# Test by tag_name
puts "5. By tag_name ('button'):"
begin
  result = driver_manager.find_element('tag_name', 'button')
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ✗ Failed: #{e.class} - #{e.message[0..100]}"
end
puts

# Test by class
puts "6. By class ('test-class') - if element has this class:"
begin
  result = driver_manager.find_element('class', 'test-class')
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ℹ Expected failure (no element with this class): #{e.class.name}"
end
puts

# Complex XPath
puts "7. By complex XPath (//button[contains(text(),'Click')]):"
begin
  result = driver_manager.find_element('xpath', "//button[contains(text(),'Click')]")
  puts "  ✓ Success: #{result[:element_id]}"
  puts "    Tag: #{result[:tag_name]}, Text: #{result[:text]}"
rescue => e
  puts "  ✗ Failed: #{e.class} - #{e.message[0..100]}"
end
puts

puts "=" * 60
puts "Test complete"

session_manager.destroy_session(session_id)
