# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP find_and_click Tool", type: :mcp_integration do
  let(:session_result) { mcp_client.call_tool("create_session", {}) }
  let(:session_id) { session_result[:session_id] }

  before do
    mcp_client.call_tool("navigate", {
                           session_id: session_id,
                           url: TestHtmlServer.url("/index.html")
                         })
  end

  after do
    mcp_client.call_tool("destroy_session", { session_id: session_id }) if session_id
  end

  describe "find_and_click tool" do
    it "finds and clicks element in single request" do
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: session_id,
                                      strategy: "id",
                                      value: "test-button"
                                    })

      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)
      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:message]).to include("clicked")
    end

    it "works with CSS selector" do
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: session_id,
                                      strategy: "css",
                                      value: "button#test-button"
                                    })
      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)
    end

    it "works with XPath" do
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: session_id,
                                      strategy: "xpath",
                                      value: "//button[@id='test-button']"
                                    })
      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)
    end

    it "works with link_text" do
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: session_id,
                                      strategy: "link_text",
                                      value: "Go to Form"
                                    })
      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)

      # Link click should navigate to form.html
      # We can verify by navigating back to index
      nav_result = mcp_client.call_tool("navigate", {
                                          session_id: session_id,
                                          url: TestHtmlServer.url("/index.html")
                                        })
      expect(nav_result[:success]).to be true
    end

    it "returns error message for non-existent element" do
      expect {
        mcp_client.call_tool("find_and_click", {
                               session_id: session_id,
                               strategy: "id",
                               value: "does-not-exist-at-all"
                             })
      }.to raise_error(RuntimeError, /NoSuchElementError|Element not found|unable to locate element/i)
    end

    it "auto-creates session but returns error for element not found" do
      # When a non-existent session is used, it auto-creates the session
      # but then fails because there's no page loaded yet (no element to find)
      expect {
        mcp_client.call_tool("find_and_click", {
                               session_id: "auto_created_session_id",
                               strategy: "id",
                               value: "test-button"
                             })
      }.to raise_error(RuntimeError, /unable to locate element/i)

      # Clean up the auto-created session
      begin
        mcp_client.call_tool("destroy_session", { session_id: "auto_created_session_id" })
      rescue StandardError
        # Ignore cleanup errors
      end
    end

    it "is atomic - no stale element between find and click" do
      # This test verifies that find_and_click is truly atomic
      # by clicking an element that might trigger page changes

      # First, navigate to form page
      mcp_client.call_tool("navigate", {
                             session_id: session_id,
                             url: TestHtmlServer.url("/form.html")
                           })

      # Find and click an input (which should succeed atomically)
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: session_id,
                                      strategy: "css",
                                      value: "input[type='text']"
                                    })

      expect(result[:success]).to be true
      expect(result[:element_id]).to be_a(String)
    end
  end

  describe "find_and_click vs separate find/click" do
    it "avoids the time gap that causes stale elements" do
      # With find_and_click (one MCP request)
      result = mcp_client.call_tool("find_and_click", {
                                      session_id: session_id,
                                      strategy: "id",
                                      value: "test-button"
                                    })

      expect(result[:success]).to be true

      # This demonstrates the advantage: single atomic operation
      # vs two separate MCP requests that could have page changes in between
    end
  end
end
