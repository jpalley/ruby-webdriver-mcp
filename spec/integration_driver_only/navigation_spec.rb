# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Navigation Tools", type: :integration do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }
  let(:session_id) { session_manager.create_session }
  let(:driver) { session_manager.get_driver_manager(session_id) }

  after do
    session_manager.destroy_all_sessions
  end

  describe "navigate" do
    it "navigates to a URL and returns the current URL" do
      result = driver.navigate_to(TestHtmlServer.url("/index.html"))

      expect(result[:success]).to be true
      expect(result[:url]).to include("index.html")
    end

    it "updates the current URL" do
      driver.navigate_to(TestHtmlServer.url("/index.html"))

      current_url = driver.current_url

      expect(current_url).to include("index.html")
    end

    it "updates the page title" do
      driver.navigate_to(TestHtmlServer.url("/index.html"))

      title = driver.page_title

      expect(title).to eq("Test Page")
    end

    it "can navigate to multiple pages sequentially" do
      driver.navigate_to(TestHtmlServer.url("/index.html"))
      expect(driver.page_title).to eq("Test Page")

      driver.navigate_to(TestHtmlServer.url("/form.html"))
      expect(driver.page_title).to eq("Form Test Page")

      driver.navigate_to(TestHtmlServer.url("/javascript.html"))
      expect(driver.page_title).to eq("JavaScript Test Page")
    end
  end

  describe "current_url" do
    it "returns the current URL" do
      driver.navigate_to(TestHtmlServer.url("/index.html"))

      url = driver.current_url

      expect(url).to include("app")
      expect(url).to include("index.html")
    end
  end

  describe "page_title" do
    it "returns the page title" do
      driver.navigate_to(TestHtmlServer.url("/form.html"))

      title = driver.page_title

      expect(title).to eq("Form Test Page")
    end
  end
end
