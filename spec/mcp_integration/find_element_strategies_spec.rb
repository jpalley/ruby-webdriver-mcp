# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP find_element Strategies", type: :mcp_integration do
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

  describe "locator strategies through MCP" do
    it "finds element by id" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "id",
                                      value: "test-button"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by xpath with single quotes" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "xpath",
                                      value: "//button[@id='test-button']"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by xpath with double quotes" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "xpath",
                                      value: '//button[@id="test-button"]'
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by xpath with text content" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "xpath",
                                      value: "//button[contains(text(),'Click')]"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by xpath with complex path" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "xpath",
                                      value: "//div[@id='content']//span[1]"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("span")
    end

    it "finds element by css selector" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "css",
                                      value: "button#test-button"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end

    it "finds element by link_text" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "link_text",
                                      value: "Go to Form"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("a")
    end

    it "finds element by partial_link_text" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "partial_link_text",
                                      value: "Go to"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("a")
    end

    it "finds element by class name" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "class",
                                      value: "description"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("p")
    end

    it "finds element by tag_name" do
      result = mcp_client.call_tool("find_element", {
                                      session_id: session_id,
                                      strategy: "tag_name",
                                      value: "button"
                                    })

      expect(result[:element_id]).to match(/^element_\d+$/)
      expect(result[:tag_name]).to eq("button")
    end
  end

  describe "error handling through MCP" do
    it "returns error for non-existent xpath element" do
      expect {
        mcp_client.call_tool("find_element", {
                               session_id: session_id,
                               strategy: "xpath",
                               value: "//button[@id='does-not-exist']"
                             })
      }.to raise_error(RuntimeError, /NoSuchElementError|Element not found|unable to locate element/i)
    end

    it "returns error for invalid xpath syntax" do
      expect {
        mcp_client.call_tool("find_element", {
                               session_id: session_id,
                               strategy: "xpath",
                               value: "//button[@id='test-button'" # Missing closing bracket
                             })
      }.to raise_error(RuntimeError, /invalid selector|xpath/i)
    end
  end
end
