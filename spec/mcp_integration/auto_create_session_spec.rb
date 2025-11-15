# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP Auto-Create Session", type: :mcp_integration do
  describe "calling tools without create_session" do
    it "auto-creates session when navigating without explicit create" do
      custom_session_id = "my_custom_session"

      # Navigate without calling create_session first
      result = mcp_client.call_tool("navigate", {
                                      session_id: custom_session_id,
                                      url: TestHtmlServer.url("/index.html")
                                    })

      expect(result[:success]).to be true
      expect(result[:url]).to include("/index.html")

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: custom_session_id })
    end

    it "auto-creates session when finding element without explicit create" do
      custom_session_id = "find_element_session"

      # Navigate first
      mcp_client.call_tool("navigate", {
                             session_id: custom_session_id,
                             url: TestHtmlServer.url("/index.html")
                           })

      # Find element - session was auto-created by navigate
      result = mcp_client.call_tool("find_element", {
                                      session_id: custom_session_id,
                                      strategy: "id",
                                      value: "test-button"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: custom_session_id })
    end

    it "auto-creates session when using find_and_click without explicit create" do
      custom_session_id = "click_session"

      # Navigate
      mcp_client.call_tool("navigate", {
                             session_id: custom_session_id,
                             url: TestHtmlServer.url("/index.html")
                           })

      # Find and click
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: custom_session_id,
                                      strategy: "id",
                                      value: "test-button"
                                    })

      expect(result[:success]).to be true
      expect(result[:element_id]).to match(/^element_\d+$/)

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: custom_session_id })
    end

    it "works seamlessly with explicit create_session too" do
      # Explicit create
      result = mcp_client.call_tool("create_session", {})
      session_id = result[:session_id]

      # Use the session
      nav_result = mcp_client.call_tool("navigate", {
                                          session_id: session_id,
                                          url: TestHtmlServer.url("/index.html")
                                        })

      expect(nav_result[:success]).to be true

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: session_id })
    end

    it "allows multiple auto-created sessions with different IDs" do
      session1 = "session_one"
      session2 = "session_two"

      # Create first session via navigate
      mcp_client.call_tool("navigate", {
                             session_id: session1,
                             url: TestHtmlServer.url("/index.html")
                           })

      # Create second session via navigate
      mcp_client.call_tool("navigate", {
                             session_id: session2,
                             url: TestHtmlServer.url("/form.html")
                           })

      # Both should work independently
      result1 = mcp_client.call_tool("find_element", {
                                       session_id: session1,
                                       strategy: "id",
                                       value: "test-button"
                                     })

      result2 = mcp_client.call_tool("find_element", {
                                       session_id: session2,
                                       strategy: "name",
                                       value: "username"
                                     })

      expect(result1[:element_id]).to match(/^element_\d+$/)
      expect(result2[:element_id]).to match(/^element_\d+$/)

      # Clean up
      mcp_client.call_tool("destroy_session", { session_id: session1 })
      mcp_client.call_tool("destroy_session", { session_id: session2 })
    end
  end
end
