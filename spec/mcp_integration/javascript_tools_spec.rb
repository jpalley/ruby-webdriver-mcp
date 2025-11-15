# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP JavaScript Tools", type: :mcp_integration do
  let(:session_result) { mcp_client.call_tool("create_session", {}) }
  let(:session_id) { session_result[:session_id] }

  before do
    mcp_client.call_tool("navigate", {
                           session_id: session_id,
                           url: TestHtmlServer.url("/javascript.html")
                         })
  end

  after do
    mcp_client.call_tool("destroy_session", { session_id: session_id }) if session_id
  end

  describe "execute_script tool" do
    it "executes JavaScript and returns result via MCP" do
      result = mcp_client.call_tool("execute_script", {
                                      session_id: session_id,
                                      script: "return 2 + 2"
                                    })

      expect(result[:result]).to eq(4)
    end

    it "executes JavaScript that returns a string via MCP" do
      result = mcp_client.call_tool("execute_script", {
                                      session_id: session_id,
                                      script: "return document.title"
                                    })

      expect(result[:result]).to eq("JavaScript Test Page")
    end

    it "executes JavaScript that manipulates DOM via MCP" do
      result = mcp_client.call_tool("execute_script", {
                                      session_id: session_id,
                                      script: <<~JS
                                        document.getElementById('dynamic-content').textContent = 'Changed!';
                                        return document.getElementById('dynamic-content').textContent;
                                      JS
                                    })

      expect(result[:result]).to eq("Changed!")
    end

    it "executes JavaScript that calls page functions via MCP" do
      result = mcp_client.call_tool("execute_script", {
                                      session_id: session_id,
                                      script: "return addNumbers(10, 15)"
                                    })

      expect(result[:result]).to eq(25)
    end

    it "executes JavaScript that returns objects via MCP" do
      result = mcp_client.call_tool("execute_script", {
                                      session_id: session_id,
                                      script: "return {foo: 'bar', num: 42}"
                                    })

      expect(result[:result]).to eq("foo" => "bar", "num" => 42)
    end
  end

  describe "get_console_logs tool" do
    it "retrieves console logs via MCP" do
      sleep 0.5 # Give time for console logs to appear

      result = mcp_client.call_tool("get_console_logs", {
                                      session_id: session_id
                                    })

      expect(result[:logs]).to be_an(Array)
      expect(result[:logs].size).to be >= 1

      # Check that logs have expected structure
      result[:logs].each do |log|
        expect(log).to include(:level, :message, :timestamp)
        expect(log[:timestamp]).to be_a(Integer)
      end
    end
  end

  # Screenshot resource test disabled - FastMCP 1.6.0 has issues with URI templates
  # Use HTTP endpoint at /screenshots/{session_id} or save_screenshot tool instead
  # describe "screenshot resource" do
  #   it "captures screenshot via MCP resource" do
  #     result = mcp_client.read_resource("screenshot://#{session_id}")
  #
  #     # FastMCP returns resources as { contents: [...] }
  #     expect(result[:contents]).to be_an(Array)
  #     expect(result[:contents].first).to have_key(:blob)
  #     expect(result[:contents].first[:mimeType]).to eq("image/png")
  #
  #     # Verify it's valid base64 PNG data
  #     blob = result[:contents].first[:blob]
  #     expect(blob).to be_a(String)
  #     expect(blob.length).to be > 1000
  #
  #     decoded = Base64.decode64(blob)
  #     expect(decoded).not_to be_empty
  #     # PNG files start with magic bytes: \x89PNG
  #     expect(decoded[0..3]).to eq("\x89PNG")
  #   end
  # end
end
