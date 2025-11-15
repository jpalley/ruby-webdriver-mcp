# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Session Management", type: :integration do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }

  before do
    # Clean up any existing sessions
    session_manager.destroy_all_sessions
  end

  after do
    # Clean up sessions after each test
    session_manager.destroy_all_sessions
  end

  describe "create_session" do
    it "creates a new session with auto-generated ID" do
      session_id = session_manager.create_session

      expect(session_id).to match(/^session_[a-f0-9]{32}$/)
      expect(session_manager.session_exists?(session_id)).to be true
    end

    it "creates a session with custom ID" do
      session_id = session_manager.create_session(session_id: "custom_session_123")

      expect(session_id).to eq("custom_session_123")
      expect(session_manager.session_exists?(session_id)).to be true
    end

    it "raises error if session ID already exists" do
      session_manager.create_session(session_id: "duplicate")

      expect do
        session_manager.create_session(session_id: "duplicate")
      end.to raise_error(SeleniumWebdriverMcp::Error, /already exists/)
    end
  end

  describe "multiple concurrent sessions" do
    it "maintains separate browser instances for each session" do
      session1 = session_manager.create_session
      session2 = session_manager.create_session

      driver1 = session_manager.get_driver_manager(session1)
      driver2 = session_manager.get_driver_manager(session2)

      # Navigate to different URLs
      driver1.navigate_to(TestHtmlServer.url("/index.html"))
      driver2.navigate_to(TestHtmlServer.url("/form.html"))

      # Verify they're on different pages
      expect(driver1.current_url).to include("index.html")
      expect(driver2.current_url).to include("form.html")
    end

    it "maintains separate element caches for each session" do
      session1 = session_manager.create_session
      session2 = session_manager.create_session

      driver1 = session_manager.get_driver_manager(session1)
      driver2 = session_manager.get_driver_manager(session2)

      # Navigate both to same page
      driver1.navigate_to(TestHtmlServer.url("/index.html"))
      driver2.navigate_to(TestHtmlServer.url("/index.html"))

      # Find elements in both sessions
      element1 = driver1.find_element(:id, "main-heading")
      element2 = driver2.find_element(:id, "main-heading")

      # Both should have element_0 but in different caches
      expect(element1[:element_id]).to eq("element_0")
      expect(element2[:element_id]).to eq("element_0")
      expect(element1[:text]).to eq("Welcome to Test Page")
      expect(element2[:text]).to eq("Welcome to Test Page")
    end
  end

  describe "list_sessions" do
    it "returns empty list when no sessions exist" do
      sessions = session_manager.list_sessions

      expect(sessions).to be_empty
    end

    it "returns all active sessions" do
      session1 = session_manager.create_session
      session2 = session_manager.create_session

      sessions = session_manager.list_sessions

      expect(sessions.size).to eq(2)
      expect(sessions.map { |s| s[:session_id] }).to contain_exactly(session1, session2)
    end

    it "includes session metadata" do
      session_id = session_manager.create_session

      sessions = session_manager.list_sessions
      session = sessions.first

      expect(session).to include(
        session_id: session_id,
        created_at: be_a(Time),
        last_accessed: be_a(Time),
        active: false # Not started yet
      )
    end
  end

  describe "destroy_session" do
    it "destroys a session and closes the browser" do
      session_id = session_manager.create_session
      driver = session_manager.get_driver_manager(session_id)
      driver.navigate_to(TestHtmlServer.url("/index.html"))

      result = session_manager.destroy_session(session_id)

      expect(result).to be true
      expect(session_manager.session_exists?(session_id)).to be false
    end

    it "returns false for non-existent session" do
      result = session_manager.destroy_session("non_existent")

      expect(result).to be false
    end
  end

  describe "thread safety" do
    it "handles concurrent session creation safely" do
      threads = 5.times.map do
        Thread.new do
          session_manager.create_session
        end
      end

      session_ids = threads.map(&:value)

      expect(session_ids.size).to eq(5)
      expect(session_ids.uniq.size).to eq(5) # All unique
      expect(session_manager.session_count).to eq(5)
    end

    it "handles concurrent access to different sessions" do
      session1 = session_manager.create_session
      session2 = session_manager.create_session

      threads = [
        Thread.new do
          driver = session_manager.get_driver_manager(session1)
          driver.navigate_to(TestHtmlServer.url("/index.html"))
          driver.page_title
        end,
        Thread.new do
          driver = session_manager.get_driver_manager(session2)
          driver.navigate_to(TestHtmlServer.url("/form.html"))
          driver.page_title
        end
      ]

      results = threads.map(&:value)

      expect(results).to contain_exactly("Test Page", "Form Test Page")
    end
  end
end
