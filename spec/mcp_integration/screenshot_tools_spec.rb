# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"
require "support/test_html_server"

RSpec.describe "MCP Screenshot Tools", type: :mcp_integration do
  let(:session_result) { mcp_client.call_tool("create_session", {}) }
  let(:session_id) { session_result[:session_id] }

  before do
    # Navigate to a test page
    mcp_client.call_tool("navigate", {
                           session_id: session_id,
                           url: TestHtmlServer.url("/simple.html")
                         })
  end

  after do
    mcp_client.call_tool("destroy_session", { session_id: session_id }) if session_id
  end

  describe "save_desktop_screenshot tool" do
    it "captures a screenshot at desktop resolution (1920x1080)" do
      result = mcp_client.call_tool("save_desktop_screenshot", {
                                      session_id: session_id
                                    })

      expect(result).to be_a(Hash)
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:type]).to eq("image")
      expect(result[:content].first[:mimeType]).to eq("image/png")
      expect(result[:content].first[:data]).to be_a(String)
      expect(result[:content].first[:data].length).to be > 0

      # Check metadata
      expect(result[:metadata][:resolution]).to eq("desktop")
      expect(result[:metadata][:width]).to eq(1920)
      expect(result[:metadata][:height]).to eq(1080)
      expect(result[:metadata][:url]).to include("simple.html")
    end

    it "restores original window size after taking screenshot" do
      # Get original window size via driver manager
      session_manager = SeleniumWebdriverMcp::SessionManager.instance
      driver_manager = session_manager.get_driver_manager(session_id)
      original_size = driver_manager.get_window_size

      # Take desktop screenshot
      mcp_client.call_tool("save_desktop_screenshot", {
                             session_id: session_id
                           })

      # Verify window size was restored
      restored_size = driver_manager.get_window_size
      expect(restored_size[:width]).to eq(original_size[:width])
      expect(restored_size[:height]).to eq(original_size[:height])
    end
  end

  describe "save_mobile_screenshot tool" do
    it "captures a screenshot at mobile resolution (375x667)" do
      result = mcp_client.call_tool("save_mobile_screenshot", {
                                      session_id: session_id
                                    })

      expect(result).to be_a(Hash)
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:type]).to eq("image")
      expect(result[:content].first[:mimeType]).to eq("image/png")
      expect(result[:content].first[:data]).to be_a(String)
      expect(result[:content].first[:data].length).to be > 0

      # Check metadata
      expect(result[:metadata][:resolution]).to eq("mobile")
      expect(result[:metadata][:width]).to eq(375)
      expect(result[:metadata][:height]).to eq(667)
      expect(result[:metadata][:url]).to include("simple.html")
    end

    it "restores original window size after taking screenshot" do
      # Get original window size via driver manager
      session_manager = SeleniumWebdriverMcp::SessionManager.instance
      driver_manager = session_manager.get_driver_manager(session_id)
      original_size = driver_manager.get_window_size

      # Take mobile screenshot
      mcp_client.call_tool("save_mobile_screenshot", {
                             session_id: session_id
                           })

      # Verify window size was restored
      restored_size = driver_manager.get_window_size
      expect(restored_size[:width]).to eq(original_size[:width])
      expect(restored_size[:height]).to eq(original_size[:height])
    end
  end

  describe "using both screenshot tools sequentially" do
    it "can take desktop and mobile screenshots in sequence" do
      # Take desktop screenshot
      desktop_result = mcp_client.call_tool("save_desktop_screenshot", {
                                              session_id: session_id
                                            })

      expect(desktop_result[:metadata][:resolution]).to eq("desktop")
      expect(desktop_result[:content].first[:data]).to be_a(String)

      # Take mobile screenshot
      mobile_result = mcp_client.call_tool("save_mobile_screenshot", {
                                             session_id: session_id
                                           })

      expect(mobile_result[:metadata][:resolution]).to eq("mobile")
      expect(mobile_result[:content].first[:data]).to be_a(String)

      # Screenshots should be different (different sizes)
      expect(desktop_result[:content].first[:data]).not_to eq(mobile_result[:content].first[:data])
    end
  end
end
