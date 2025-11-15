# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Element Interaction Tools", type: :integration do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }
  let(:session_id) { session_manager.create_session }
  let(:driver) { session_manager.get_driver_manager(session_id) }

  before do
    driver.navigate_to(TestHtmlServer.url("/index.html"))
  end

  after do
    session_manager.destroy_all_sessions
  end

  describe "find_element" do
    it "finds element by ID" do
      element = driver.find_element(:id, "main-heading")

      expect(element[:element_id]).to eq("element_0")
      expect(element[:tag_name]).to eq("h1")
      expect(element[:text]).to eq("Welcome to Test Page")
      expect(element[:displayed]).to be true
      expect(element[:enabled]).to be true
    end

    it "finds element by CSS selector" do
      element = driver.find_element(:css, ".description")

      expect(element[:tag_name]).to eq("p")
      expect(element[:text]).to include("test page")
    end

    it "finds element by XPath" do
      element = driver.find_element(:xpath, "//button[@id='test-button']")

      expect(element[:tag_name]).to eq("button")
      expect(element[:text]).to eq("Click Me")
    end

    it "finds element by class name" do
      element = driver.find_element(:class, "description")

      expect(element[:tag_name]).to eq("p")
    end

    it "finds element by link text" do
      element = driver.find_element(:link_text, "Go to Form")

      expect(element[:tag_name]).to eq("a")
      expect(element[:element_id]).to be_a(String)
      expect(element[:element_id]).not_to be_empty
    end
  end

  describe "click_element" do
    it "clicks an element" do
      driver.navigate_to(TestHtmlServer.url("/form.html"))
      element = driver.find_element(:id, "username")

      result = driver.click_element(element[:element_id])

      expect(result[:success]).to be true
    end
  end

  describe "send_keys" do
    it "types text into an input field" do
      driver.navigate_to(TestHtmlServer.url("/form.html"))
      element = driver.find_element(:id, "username")

      result = driver.send_keys(element[:element_id], "testuser123")

      expect(result[:success]).to be true
    end

    it "types text into a textarea" do
      driver.navigate_to(TestHtmlServer.url("/form.html"))
      element = driver.find_element(:id, "comments")

      result = driver.send_keys(element[:element_id], "This is a test comment")

      expect(result[:success]).to be true
    end
  end
end
