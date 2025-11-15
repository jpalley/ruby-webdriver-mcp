# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "json"
require "support/test_html_server"

RSpec.describe SeleniumWebdriverMcp::WebApp, type: :integration_driver_only do
  include Rack::Test::Methods

  let(:app) { described_class.new }
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }
  let(:screenshot_history) { SeleniumWebdriverMcp::ScreenshotHistory.instance }

  before do
    # Clean up any existing sessions
    session_manager.list_sessions.each do |session_info|
      session_manager.destroy_session(session_info[:session_id])
    end
  end

  after do
    # Clean up sessions and screenshots
    session_manager.list_sessions.each do |session_info|
      session_id = session_info[:session_id]
      session_manager.destroy_session(session_id)
      screenshot_history.cleanup_session(session_id)
    end
  end

  describe "GET /" do
    it "returns the dashboard HTML" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")
      expect(last_response.body).to include("Selenium WebDriver MCP Dashboard")
    end

    it "includes Tailwind CSS" do
      get "/"

      expect(last_response.body).to include("tailwindcss.com")
    end

    it "includes JavaScript for auto-refresh" do
      get "/"

      expect(last_response.body).to include("fetchSessions()")
      expect(last_response.body).to include("setInterval")
    end

    it "includes API endpoint references" do
      get "/"

      expect(last_response.body).to include("/api/sessions")
    end
  end

  describe "GET /api/sessions" do
    it "returns an empty array when no sessions exist" do
      get "/api/sessions"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data).to eq([])
    end

    it "returns session information" do
      # Create a session
      session_id = session_manager.create_session
      driver_manager = session_manager.get_driver_manager(session_id)

      # Navigate to set current_url and page_title
      test_url = TestHtmlServer.url("/simple.html")
      driver_manager.navigate_to(test_url)

      get "/api/sessions"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body, symbolize_names: true)

      expect(data).to be_an(Array)
      expect(data.length).to eq(1)

      session_data = data.first
      expect(session_data).to include(
        session_id: session_id,
        created_at: be_a(Integer),
        last_accessed: be_a(Integer),
        current_url: test_url,
        page_title: "Simple Test Page",
        screenshot_count: 0
      )
    end

    it "includes screenshot count" do
      # Create a session
      session_id = session_manager.create_session
      driver_manager = session_manager.get_driver_manager(session_id)

      test_url = TestHtmlServer.url("/simple.html")
      driver_manager.navigate_to(test_url)

      # Save some screenshots
      png_data = driver_manager.ensure_started.screenshot_as(:base64)
      png_binary = Base64.decode64(png_data)
      3.times do |i|
        # Use unique timestamp for each
        allow(Time).to receive(:now).and_return(Time.at(7000000 + i))
        screenshot_history.save_screenshot(session_id, png_binary, test_url)
      end
      allow(Time).to receive(:now).and_call_original

      get "/api/sessions"

      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data.first[:screenshot_count]).to eq(3)
    end

    it "returns multiple sessions sorted by last activity" do
      # Create three sessions with different last_accessed times
      session1 = session_manager.create_session
      sleep 0.1
      session2 = session_manager.create_session
      sleep 0.1
      session3 = session_manager.create_session

      # Access session2 to make it most recent
      session_manager.get_driver_manager(session2)

      get "/api/sessions"

      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data.length).to eq(3)

      # Should be sorted by last_accessed (most recent first)
      session_ids = data.map { |s| s[:session_id] }
      expect(session_ids.first).to eq(session2)
    end
  end

  describe "GET /api/sessions/:id/screenshots" do
    let(:session_id) { @session_id }

    before do
      @session_id = session_manager.create_session
      driver_manager = session_manager.get_driver_manager(session_id)

      @test_url = TestHtmlServer.url("/simple.html")
      driver_manager.navigate_to(@test_url)
    end

    it "returns an empty array when no screenshots exist" do
      get "/api/sessions/#{session_id}/screenshots"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data).to eq([])
    end

    it "returns screenshot metadata" do
      # Save a screenshot
      driver_manager = session_manager.get_driver_manager(session_id)
      png_data = driver_manager.ensure_started.screenshot_as(:base64)
      png_binary = Base64.decode64(png_data)
      screenshot_history.save_screenshot(session_id, png_binary, @test_url)

      get "/api/sessions/#{session_id}/screenshots"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body, symbolize_names: true)

      expect(data).to be_an(Array)
      expect(data.length).to eq(1)

      screenshot = data.first
      expect(screenshot).to include(
        timestamp: be_a(Integer),
        url: @test_url,
        filename: match(/\d+\.png/),
        path: match(%r{/screenshots/#{session_id}/\d+\.png})
      )
    end

    it "returns screenshots in reverse chronological order" do
      driver_manager = session_manager.get_driver_manager(session_id)
      png_data = driver_manager.ensure_started.screenshot_as(:base64)
      png_binary = Base64.decode64(png_data)

      # Save 3 screenshots with unique timestamps
      urls = []
      3.times do |i|
        url = "https://example.com/page#{i}"
        urls << url
        allow(Time).to receive(:now).and_return(Time.at(8000000 + i))
        screenshot_history.save_screenshot(session_id, png_binary, url)
      end
      allow(Time).to receive(:now).and_call_original

      get "/api/sessions/#{session_id}/screenshots"

      data = JSON.parse(last_response.body, symbolize_names: true)

      # Should be newest first
      expect(data[0][:url]).to eq("https://example.com/page2")
      expect(data[1][:url]).to eq("https://example.com/page1")
      expect(data[2][:url]).to eq("https://example.com/page0")
    end

    it "returns 404 for non-existent session" do
      get "/api/sessions/invalid_session/screenshots"

      expect(last_response.status).to eq(404)
      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data[:error]).to include("Session not found")
    end
  end

  describe "POST /api/sessions/:id/screenshot" do
    let(:session_id) { @session_id }

    before do
      @session_id = session_manager.create_session
      driver_manager = session_manager.get_driver_manager(session_id)

      @test_url = TestHtmlServer.url("/simple.html")
      driver_manager.navigate_to(@test_url)
    end

    it "captures and saves a screenshot" do
      post "/api/sessions/#{session_id}/screenshot"

      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body, symbolize_names: true)

      expect(data[:success]).to be true
      expect(data[:screenshot]).to include(
        timestamp: be_a(Integer),
        url: @test_url,
        path: match(%r{/screenshots/#{session_id}/\d+\.png})
      )
    end

    it "creates a PNG file on disk" do
      post "/api/sessions/#{session_id}/screenshot"

      data = JSON.parse(last_response.body, symbolize_names: true)
      path = data[:screenshot][:path]
      filename = File.basename(path)

      file_path = File.join("public", "screenshots", session_id, filename)
      expect(File.exist?(file_path)).to be true

      png_data = File.binread(file_path)
      expect(png_data).to start_with("\x89PNG".dup.force_encoding("ASCII-8BIT"))
    end

    it "increments the screenshot history" do
      # Initial count should be 0
      expect(screenshot_history.get_screenshot_count(session_id)).to eq(0)

      # Capture screenshot
      post "/api/sessions/#{session_id}/screenshot"

      # Count should be 1
      expect(screenshot_history.get_screenshot_count(session_id)).to eq(1)
    end

    it "returns 404 for non-existent session" do
      post "/api/sessions/invalid_session/screenshot"

      expect(last_response.status).to eq(404)
      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data[:success]).to be false
      expect(data[:error]).to match(/Session.*not found/)
    end

    it "captures the current page URL" do
      # Navigate to a different page
      driver_manager = session_manager.get_driver_manager(session_id)
      different_url = TestHtmlServer.url("/form.html")
      driver_manager.navigate_to(different_url)

      post "/api/sessions/#{session_id}/screenshot"

      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data[:screenshot][:url]).to eq(different_url)
    end
  end

  describe "404 handling" do
    it "returns 404 for unmatched routes" do
      get "/some/other/path"

      expect(last_response.status).to eq(404)
    end

    it "returns 404 for /mcp endpoint (handled by FastMCP middleware in production)" do
      # Sinatra app doesn't define /mcp route - it's handled by FastMCP middleware
      post "/mcp"

      expect(last_response.status).to eq(404)
    end
  end

  describe "error handling" do
    it "handles exceptions gracefully in screenshot capture" do
      # Create a session but destroy it immediately to cause an error
      session_id = session_manager.create_session
      session_manager.destroy_session(session_id)

      post "/api/sessions/#{session_id}/screenshot"

      expect(last_response.status).to eq(404)
      data = JSON.parse(last_response.body, symbolize_names: true)
      expect(data[:success]).to be false
      expect(data[:error]).to be_a(String)
    end
  end

  describe "CORS headers" do
    it "includes appropriate CORS headers" do
      get "/api/sessions"

      # Check for CORS headers if needed in your implementation
      # This is a placeholder - adjust based on your CORS requirements
      expect(last_response.headers).to include("Content-Type")
    end
  end
end
