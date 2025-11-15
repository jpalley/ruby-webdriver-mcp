# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "JavaScript Tools", type: :integration do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }
  let(:session_id) { session_manager.create_session }
  let(:driver) { session_manager.get_driver_manager(session_id) }

  before do
    driver.navigate_to(TestHtmlServer.url("/javascript.html"))
  end

  after do
    session_manager.destroy_all_sessions
  end

  describe "execute_script" do
    it "executes JavaScript and returns result" do
      result = driver.execute_script("return 2 + 2")

      expect(result[:result]).to eq(4)
    end

    it "executes JavaScript that returns a string" do
      result = driver.execute_script("return document.title")

      expect(result[:result]).to eq("JavaScript Test Page")
    end

    it "executes JavaScript that manipulates the DOM" do
      result = driver.execute_script(
        "document.getElementById('dynamic-content').textContent = 'Changed by JS'; " \
        "return document.getElementById('dynamic-content').textContent"
      )

      expect(result[:result]).to eq("Changed by JS")
    end

    it "executes JavaScript function defined on the page" do
      result = driver.execute_script("return addNumbers(5, 7)")

      expect(result[:result]).to eq(12)
    end

    it "executes JavaScript that returns complex objects" do
      result = driver.execute_script("return {name: 'test', value: 42}")

      expect(result[:result]).to eq("name" => "test", "value" => 42)
    end

    it "executes JavaScript that returns arrays" do
      result = driver.execute_script("return [1, 2, 3, 4, 5]")

      expect(result[:result]).to eq([1, 2, 3, 4, 5])
    end
  end

  describe "get_console_logs" do
    it "retrieves console logs" do
      # Give time for console logs to appear
      sleep 0.5

      result = driver.get_console_logs

      expect(result[:logs]).to be_an(Array)
      # Should have at least warning and error logs
      expect(result[:logs].size).to be >= 2

      # Check for expected log messages (console.warn and console.error are captured)
      messages = result[:logs].map { |log| log[:message] }
      expect(messages.join(" ")).to include("This is a warning")
    end

    it "includes different log levels" do
      sleep 0.5

      result = driver.get_console_logs

      levels = result[:logs].map { |log| log[:level] }.uniq
      # Should have WARNING and SEVERE (error) levels
      # Note: console.log() (INFO level) is not captured by recent Chrome versions
      expect(levels).to include("WARNING")
      expect(levels).to include("SEVERE")
    end

    it "includes timestamps" do
      sleep 0.5

      result = driver.get_console_logs

      result[:logs].each do |log|
        expect(log[:timestamp]).to be_a(Integer)
        expect(log[:timestamp]).to be > 0
      end
    end
  end
end
