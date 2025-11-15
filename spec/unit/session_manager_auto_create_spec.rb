# frozen_string_literal: true

require "spec_helper"

RSpec.describe SeleniumWebdriverMcp::SessionManager do
  let(:session_manager) { described_class.instance }

  before do
    # Reset the singleton for each test
    described_class.reset!
  end

  describe "#get_driver_manager with auto_create" do
    context "when session doesn't exist" do
      it "auto-creates the session by default" do
        session_id = "auto_created_session"

        expect(session_manager.session_exists?(session_id)).to be false

        # Should auto-create
        driver_manager = session_manager.get_driver_manager(session_id)

        expect(driver_manager).to be_a(SeleniumWebdriverMcp::DriverManager)
        expect(session_manager.session_exists?(session_id)).to be true
        expect(session_manager.session_count).to eq(1)
      end

      it "logs auto-creation" do
        session_id = "logged_session"

        # Just verify it doesn't raise an error and creates the session
        expect {
          session_manager.get_driver_manager(session_id)
        }.not_to raise_error

        expect(session_manager.session_exists?(session_id)).to be true
      end

      it "raises error when auto_create is false" do
        session_id = "non_existent"

        expect {
          session_manager.get_driver_manager(session_id, auto_create: false)
        }.to raise_error(SeleniumWebdriverMcp::Error, /Session #{session_id} not found/)
      end

      it "auto-creates with the provided session_id" do
        custom_id = "my_custom_session_id"

        driver_manager = session_manager.get_driver_manager(custom_id)

        sessions = session_manager.list_sessions
        expect(sessions.size).to eq(1)
        expect(sessions.first[:session_id]).to eq(custom_id)
      end
    end

    context "when session already exists" do
      it "returns existing session without creating new one" do
        session_id = session_manager.create_session

        expect(session_manager.session_count).to eq(1)

        # Should return existing
        driver_manager = session_manager.get_driver_manager(session_id)

        expect(driver_manager).to be_a(SeleniumWebdriverMcp::DriverManager)
        expect(session_manager.session_count).to eq(1) # Still just 1
      end

      it "updates last_accessed timestamp" do
        session_id = session_manager.create_session
        sessions_before = session_manager.list_sessions.first

        sleep 0.1

        session_manager.get_driver_manager(session_id)
        sessions_after = session_manager.list_sessions.first

        expect(sessions_after[:last_accessed]).to be > sessions_before[:last_accessed]
      end
    end

    context "with multiple concurrent requests" do
      it "auto-creates sessions thread-safely" do
        threads = 5.times.map do |i|
          Thread.new do
            session_id = "concurrent_session_#{i}"
            session_manager.get_driver_manager(session_id)
          end
        end

        threads.each(&:join)

        expect(session_manager.session_count).to eq(5)
      end
    end
  end

  describe "MCP tool integration" do
    it "allows tools to work without explicit create_session call" do
      # Simulate what an MCP tool does
      session_id = "tool_session"

      # Tool calls get_driver_manager directly
      driver_manager = session_manager.get_driver_manager(session_id)

      expect(driver_manager).to be_a(SeleniumWebdriverMcp::DriverManager)
      expect(session_manager.session_exists?(session_id)).to be true
    end

    it "works seamlessly with explicit create_session" do
      # User explicitly creates session
      session_id = session_manager.create_session(session_id: "explicit_session")

      expect(session_manager.session_count).to eq(1)

      # Tool uses the same session
      driver_manager = session_manager.get_driver_manager(session_id)

      expect(driver_manager).to be_a(SeleniumWebdriverMcp::DriverManager)
      expect(session_manager.session_count).to eq(1) # Still just 1
    end
  end
end
