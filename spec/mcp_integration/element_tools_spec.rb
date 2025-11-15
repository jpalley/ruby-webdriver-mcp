# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP Element Tools", type: :mcp_integration do
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

  describe "find_element tool" do
    it "finds element by ID via MCP" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "id",
                                      value: "main-heading"
                                    })

      expect(result[:element_id]).to be_a(String)
      expect(result[:element_id]).not_to be_empty
      expect(result[:tag_name]).to eq("h1")
      expect(result[:text]).to eq("Welcome to Test Page")
      expect(result[:displayed]).to be true
    end

    it "finds element by CSS selector via MCP" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "css",
                                      value: ".description"
                                    })

      expect(result[:element_id]).to be_a(String)
      expect(result[:element_id]).not_to be_empty
      expect(result[:tag_name]).to eq("p")
      expect(result[:text]).to include("test page")
    end

    it "finds element by XPath via MCP" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "xpath",
                                      value: "//button[@id='test-button']"
                                    })

      expect(result[:element_id]).to be_a(String)
      expect(result[:element_id]).not_to be_empty
      expect(result[:tag_name]).to eq("button")
    end
  end

  describe "send_keys and click tools" do
    before do
      mcp_client.call_tool("navigate", {
                             session_id: session_id,
                             url: TestHtmlServer.url("/form.html")
                           })
    end

    it "types text into input via MCP" do
      element = mcp_client.call_tool("find_element", {
                                       session_id: session_id,
                                       strategy: "id",
                                       value: "username"
                                     })

      result = mcp_client.call_tool("send_keys", {
                                      session_id: session_id,
                                      element_id: element[:element_id],
                                      text: "testuser123"
                                    })

      expect(result[:success]).to be true
    end

    it "clicks an element via MCP" do
      element = mcp_client.call_tool("find_element", {
                                       session_id: session_id,
                                       strategy: "id",
                                       value: "username"
                                     })

      result = mcp_client.call_tool("click_element", {
                                      session_id: session_id,
                                      element_id: element[:element_id]
                                    })

      expect(result[:success]).to be true
    end
  end

end
