# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP Navigation Tools", type: :mcp_integration do
  let(:session_result) { mcp_client.call_tool("create_session", {}) }
  let(:session_id) { session_result[:session_id] }

  after do
    mcp_client.call_tool("destroy_session", { session_id: session_id }) if session_id
  end

  describe "navigate tool" do
    it "navigates to a URL via MCP" do
      result = mcp_client.call_tool("navigate", {
                                      session_id: session_id,
                                      url: TestHtmlServer.url("/index.html")
                                    })

      expect(result[:success]).to be true
      expect(result[:url]).to include("index.html")
    end

    it "returns error when session_id is missing" do
      expect do
        mcp_client.call_tool("navigate", {
                               url: TestHtmlServer.url("/index.html")
                             })
      end.to raise_error(/session_id/)
    end

    it "auto-creates session for non-existent session_id" do
      result = mcp_client.call_tool("navigate", {
                                      session_id: "auto_created_session",
                                      url: TestHtmlServer.url("/index.html")
                                    })

      expect(result[:url]).to include("index.html")
      expect(result[:success]).to be true

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: "auto_created_session" })
    end

    it "can navigate to multiple pages" do
      # Navigate to first page
      result1 = mcp_client.call_tool("navigate", {
                                       session_id: session_id,
                                       url: TestHtmlServer.url("/index.html")
                                     })
      expect(result1[:url]).to include("index.html")

      # Navigate to second page
      result2 = mcp_client.call_tool("navigate", {
                                       session_id: session_id,
                                       url: TestHtmlServer.url("/form.html")
                                     })
      expect(result2[:url]).to include("form.html")
    end
  end
end
