# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Find and Click Integration", type: :integration_driver_only do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }
  let(:session_id) { @session_id }

  before do
    @session_id = session_manager.create_session
    @driver_manager = session_manager.get_driver_manager(@session_id)
    @driver_manager.navigate_to(TestHtmlServer.url("/index.html"))
  end

  after do
    session_manager.destroy_session(@session_id) if @session_id
  end

  describe "#find_and_click" do
    it "finds and clicks an element by ID" do
      result = @driver_manager.find_and_click(:id, "test-button")

      expect(result[:success]).to be true
      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:message]).to include("clicked successfully")
    end

    it "finds and clicks an element by CSS selector" do
      result = @driver_manager.find_and_click(:css, "button#test-button")

      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)
    end

    it "finds and clicks an element by XPath" do
      result = @driver_manager.find_and_click(:xpath, "//button[@id='test-button']")

      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)
    end

    it "finds and clicks an element by class name" do
      # Navigate to a page with a button with class
      @driver_manager.navigate_to(TestHtmlServer.url("/form.html"))

      result = @driver_manager.find_and_click(:css, "input[type='text']")

      expect(result[:success]).to be true
    end

    it "raises error for non-existent element" do
      expect {
        @driver_manager.find_and_click(:id, "does-not-exist-at-all")
      }.to raise_error(Selenium::WebDriver::Error::NoSuchElementError)
    end

    it "returns element_id in response" do
      result = @driver_manager.find_and_click(:id, "test-button")
      element_id = result[:element_id]

      # Should return a valid element_id
      expect(element_id).to match(/^element_\d+$/)
      expect(element_id).not_to be_nil
    end

    it "works with link elements" do
      result = @driver_manager.find_and_click(:link_text, "Go to Form")

      expect(result[:success]).to be true
      # Link click should navigate to form.html
      expect(@driver_manager.current_url).to include("/form.html")
    end
  end
end
