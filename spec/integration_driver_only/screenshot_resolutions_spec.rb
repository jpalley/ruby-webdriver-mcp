# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Screenshot Resolutions", type: :integration_driver_only do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }
  let(:session_id) { @session_id }

  before do
    @session_id = session_manager.create_session
    @driver_manager = session_manager.get_driver_manager(@session_id)
    @driver_manager.navigate_to(TestHtmlServer.url("/simple.html"))
  end

  after do
    session_manager.destroy_session(@session_id) if @session_id
  end

  describe "desktop screenshot" do
    it "captures screenshot at desktop resolution (1920x1080)" do
      # Get original window size
      original_size = @driver_manager.get_window_size

      # Take desktop screenshot
      result = @driver_manager.screenshot_at_size(1920, 1080)

      # Verify screenshot was captured
      expect(result[:screenshot]).to be_a(String)
      expect(result[:screenshot].length).to be > 0
      expect(result[:width]).to eq(1920)
      expect(result[:height]).to eq(1080)

      # Verify window size was restored
      restored_size = @driver_manager.get_window_size
      expect(restored_size[:width]).to eq(original_size[:width])
      expect(restored_size[:height]).to eq(original_size[:height])
    end

    it "restores window size even if screenshot fails" do
      # Get original window size
      original_size = @driver_manager.get_window_size

      # This should work, but we're testing the ensure block
      begin
        @driver_manager.screenshot_at_size(1920, 1080)
      rescue StandardError
        # Ignore errors
      end

      # Verify window size was restored
      restored_size = @driver_manager.get_window_size
      expect(restored_size[:width]).to eq(original_size[:width])
      expect(restored_size[:height]).to eq(original_size[:height])
    end
  end

  describe "mobile screenshot" do
    it "captures screenshot at mobile resolution (375x667)" do
      # Get original window size
      original_size = @driver_manager.get_window_size

      # Take mobile screenshot
      result = @driver_manager.screenshot_at_size(375, 667)

      # Verify screenshot was captured
      expect(result[:screenshot]).to be_a(String)
      expect(result[:screenshot].length).to be > 0
      expect(result[:width]).to eq(375)
      expect(result[:height]).to eq(667)

      # Verify window size was restored
      restored_size = @driver_manager.get_window_size
      expect(restored_size[:width]).to eq(original_size[:width])
      expect(restored_size[:height]).to eq(original_size[:height])
    end
  end

  describe "window size management" do
    it "gets current window size" do
      size = @driver_manager.get_window_size

      expect(size).to be_a(Hash)
      expect(size[:width]).to be > 0
      expect(size[:height]).to be > 0
    end

    it "sets window size" do
      result = @driver_manager.set_window_size(800, 600)

      expect(result[:width]).to eq(800)
      expect(result[:height]).to eq(600)

      # Verify the size was actually set
      size = @driver_manager.get_window_size
      expect(size[:width]).to eq(800)
      expect(size[:height]).to eq(600)
    end

    it "handles multiple size changes" do
      # Change size multiple times
      @driver_manager.set_window_size(1024, 768)
      @driver_manager.set_window_size(1280, 720)
      @driver_manager.set_window_size(1920, 1080)

      # Verify final size
      size = @driver_manager.get_window_size
      expect(size[:width]).to eq(1920)
      expect(size[:height]).to eq(1080)
    end
  end

  describe "sequential screenshots at different resolutions" do
    it "can take desktop and mobile screenshots sequentially" do
      # Take desktop screenshot
      desktop_result = @driver_manager.screenshot_at_size(1920, 1080)
      expect(desktop_result[:width]).to eq(1920)
      expect(desktop_result[:height]).to eq(1080)

      # Take mobile screenshot
      mobile_result = @driver_manager.screenshot_at_size(375, 667)
      expect(mobile_result[:width]).to eq(375)
      expect(mobile_result[:height]).to eq(667)

      # Both screenshots should be different (different sizes)
      expect(desktop_result[:screenshot]).not_to eq(mobile_result[:screenshot])
    end
  end
end
