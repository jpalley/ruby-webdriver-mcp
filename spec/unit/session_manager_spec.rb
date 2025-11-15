# frozen_string_literal: true

require "spec_helper"

RSpec.describe SeleniumWebdriverMcp::SessionManager do
  let(:session_manager) { described_class.instance }

  before do
    session_manager.destroy_all_sessions
  end

  after do
    session_manager.destroy_all_sessions
  end

  describe ".instance" do
    it "returns a singleton instance" do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to be(instance2)
    end
  end

  describe "#create_session" do
    it "generates a session ID when not provided" do
      session_id = session_manager.create_session

      expect(session_id).to match(/^session_[a-f0-9]{32}$/)
    end

    it "uses provided session ID" do
      session_id = session_manager.create_session(session_id: "custom_123")

      expect(session_id).to eq("custom_123")
    end

    it "raises error for duplicate session ID" do
      session_manager.create_session(session_id: "duplicate")

      expect do
        session_manager.create_session(session_id: "duplicate")
      end.to raise_error(SeleniumWebdriverMcp::Error, /already exists/)
    end
  end

  describe "#session_exists?" do
    it "returns true for existing session" do
      session_id = session_manager.create_session

      expect(session_manager.session_exists?(session_id)).to be true
    end

    it "returns false for non-existent session" do
      expect(session_manager.session_exists?("nonexistent")).to be false
    end
  end

  describe "#get_driver_manager" do
    it "returns driver manager for session" do
      session_id = session_manager.create_session

      driver_manager = session_manager.get_driver_manager(session_id)

      expect(driver_manager).to be_a(SeleniumWebdriverMcp::DriverManager)
    end

    it "raises error for non-existent session when auto_create is false" do
      expect do
        session_manager.get_driver_manager("nonexistent", auto_create: false)
      end.to raise_error(SeleniumWebdriverMcp::Error, /not found/)
    end

    it "auto-creates session by default when session doesn't exist" do
      driver_manager = session_manager.get_driver_manager("auto_created")
      expect(driver_manager).to be_a(SeleniumWebdriverMcp::DriverManager)
      expect(session_manager.session_exists?("auto_created")).to be true
    end

    it "updates last_accessed timestamp" do
      session_id = session_manager.create_session
      original_time = session_manager.list_sessions.first[:last_accessed]

      sleep 0.1
      session_manager.get_driver_manager(session_id)

      new_time = session_manager.list_sessions.first[:last_accessed]
      expect(new_time).to be > original_time
    end
  end

  describe "#destroy_session" do
    it "destroys existing session" do
      session_id = session_manager.create_session

      result = session_manager.destroy_session(session_id)

      expect(result).to be true
      expect(session_manager.session_exists?(session_id)).to be false
    end

    it "returns false for non-existent session" do
      result = session_manager.destroy_session("nonexistent")

      expect(result).to be false
    end
  end

  describe "#list_sessions" do
    it "returns empty array when no sessions" do
      sessions = session_manager.list_sessions

      expect(sessions).to be_empty
    end

    it "returns all sessions" do
      session1 = session_manager.create_session
      session2 = session_manager.create_session

      sessions = session_manager.list_sessions

      expect(sessions.size).to eq(2)
      session_ids = sessions.map { |s| s[:session_id] }
      expect(session_ids).to contain_exactly(session1, session2)
    end

    it "includes session metadata" do
      session_id = session_manager.create_session

      sessions = session_manager.list_sessions
      session = sessions.first

      expect(session[:session_id]).to eq(session_id)
      expect(session[:created_at]).to be_a(Time)
      expect(session[:last_accessed]).to be_a(Time)
      expect([true, false]).to include(session[:active])
    end
  end

  describe "#session_count" do
    it "returns 0 when no sessions" do
      expect(session_manager.session_count).to eq(0)
    end

    it "returns correct count" do
      session_manager.create_session
      session_manager.create_session

      expect(session_manager.session_count).to eq(2)
    end
  end

  describe "#destroy_all_sessions" do
    it "destroys all sessions" do
      session_manager.create_session
      session_manager.create_session
      session_manager.create_session

      count = session_manager.destroy_all_sessions

      expect(count).to eq(3)
      expect(session_manager.session_count).to eq(0)
    end
  end
end
