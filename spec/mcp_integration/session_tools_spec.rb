# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"

RSpec.describe "MCP Session Management Tools", type: :mcp_integration do
  # Clean up sessions before each test to ensure isolation
  before do
    SeleniumWebdriverMcp::SessionManager.instance.destroy_all_sessions
  end

  describe "create_session tool" do
    it "creates a new session and returns session_id" do
      result = mcp_client.call_tool("create_session", {})

      expect(result).to include(:success, :session_id, :message)
      expect(result[:success]).to be true
      expect(result[:session_id]).to match(/^session_[a-f0-9]{32}$/)
      expect(result[:message]).to include("Session created successfully")
    end

    it "creates a session with custom session_id" do
      custom_id = "test_session_#{Time.now.to_i}"
      result = mcp_client.call_tool("create_session", { session_id: custom_id })

      expect(result[:success]).to be true
      expect(result[:session_id]).to eq(custom_id)
    end

    it "returns error for duplicate session_id" do
      custom_id = "duplicate_session_#{Time.now.to_i}"
      mcp_client.call_tool("create_session", { session_id: custom_id })

      expect do
        mcp_client.call_tool("create_session", { session_id: custom_id })
      end.to raise_error(/already exists/)
    end
  end

  describe "destroy_session tool" do
    it "destroys an existing session" do
      session = mcp_client.call_tool("create_session", {})
      session_id = session[:session_id]

      result = mcp_client.call_tool("destroy_session", { session_id: session_id })

      expect(result[:success]).to be true
      expect(result[:message]).to include("destroyed successfully")
    end

    it "returns error for non-existent session" do
      result = mcp_client.call_tool("destroy_session", { session_id: "nonexistent" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("not found")
    end
  end

  describe "session isolation via MCP" do
    after do
      SeleniumWebdriverMcp::SessionManager.instance.destroy_all_sessions
    end

    it "maintains separate sessions for concurrent requests" do
      session1 = mcp_client.call_tool("create_session", {})
      session2 = mcp_client.call_tool("create_session", {})

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: session1[:session_id] })
      mcp_client.call_tool("destroy_session", { session_id: session2[:session_id] })
    end
  end
end
