# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Find Element Strategies", type: :integration_driver_only do
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

  describe "locator strategies" do
    it "finds element by id" do
      result = @driver_manager.find_element("id", "test-button")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
      expect(result[:text]).to include("Click Me")
    end

    it "finds element by xpath with attribute" do
      result = @driver_manager.find_element("xpath", "//button[@id='test-button']")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
      expect(result[:text]).to include("Click Me")
    end

    it "finds element by xpath with text content" do
      result = @driver_manager.find_element("xpath", "//button[contains(text(),'Click')]")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by xpath with complex path" do
      result = @driver_manager.find_element("xpath", "//body/button")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by xpath with descendant" do
      result = @driver_manager.find_element("xpath", "//div[@id='content']//span")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("span")
      expect(result[:text]).to eq("Item 1")
    end

    it "finds element by css selector" do
      result = @driver_manager.find_element("css", "button#test-button")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by css class" do
      result = @driver_manager.find_element("css", ".description")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("p")
    end

    it "finds element by link_text" do
      result = @driver_manager.find_element("link_text", "Go to Form")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("a")
    end

    it "finds element by partial_link_text" do
      result = @driver_manager.find_element("partial_link_text", "Go to")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("a")
    end

    it "finds element by tag_name" do
      result = @driver_manager.find_element("tag_name", "button")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by class name" do
      result = @driver_manager.find_element("class", "description")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("p")
    end

    it "finds element by class_name" do
      result = @driver_manager.find_element("class_name", "description")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("p")
    end

    it "finds element by name attribute" do
      # Navigate to form page which has name attributes
      @driver_manager.navigate_to(TestHtmlServer.url("/form.html"))

      result = @driver_manager.find_element("name", "username")

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("input")
    end
  end

  describe "error handling" do
    it "raises error for non-existent element with xpath" do
      expect {
        @driver_manager.find_element("xpath", "//button[@id='does-not-exist']")
      }.to raise_error(Selenium::WebDriver::Error::NoSuchElementError)
    end

    it "raises error for invalid xpath syntax" do
      expect {
        @driver_manager.find_element("xpath", "//button[@id='test-button'") # Missing closing bracket
      }.to raise_error(Selenium::WebDriver::Error::WebDriverError)
    end

    it "raises error for non-existent element with css" do
      expect {
        @driver_manager.find_element("css", "#does-not-exist")
      }.to raise_error(Selenium::WebDriver::Error::NoSuchElementError)
    end
  end
end
