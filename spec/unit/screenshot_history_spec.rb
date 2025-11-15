# frozen_string_literal: true

require "spec_helper"

RSpec.describe SeleniumWebdriverMcp::ScreenshotHistory do
  let(:history) { described_class.instance }
  let(:session_id) { "test_session_123" }
  let(:png_data) { "\x89PNG\r\n\x1A\n".dup.force_encoding("ASCII-8BIT") }
  let(:url) { "https://example.com/page" }

  before do
    # Clear any existing history for test session
    history.instance_variable_get(:@history).delete(session_id)

    # Clean up test screenshot directory
    test_dir = File.join("public", "screenshots", session_id)
    FileUtils.rm_rf(test_dir) if File.exist?(test_dir)
  end

  after do
    # Clean up after tests
    test_dir = File.join("public", "screenshots", session_id)
    FileUtils.rm_rf(test_dir) if File.exist?(test_dir)
  end

  describe "#save_screenshot" do
    it "saves a screenshot with metadata" do
      result = history.save_screenshot(session_id, png_data, url)

      expect(result).to include(
        timestamp: be_a(Integer),
        url: url,
        filename: match(/\d+\.png/),
        path: match(%r{/screenshots/#{session_id}/\d+\.png})
      )
    end

    it "creates the session directory if it doesn't exist" do
      history.save_screenshot(session_id, png_data, url)

      dir_path = File.join("public", "screenshots", session_id)
      expect(File.directory?(dir_path)).to be true
    end

    it "writes the PNG data to a file" do
      result = history.save_screenshot(session_id, png_data, url)

      file_path = File.join("public", "screenshots", session_id, result[:filename])
      expect(File.exist?(file_path)).to be true
      expect(File.binread(file_path)).to eq(png_data)
    end

    it "limits screenshots to 10 per session" do
      # Save 12 screenshots with unique timestamps
      12.times do |i|
        allow(Time).to receive(:now).and_return(Time.at(4000000 + i))
        history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
      end
      allow(Time).to receive(:now).and_call_original

      screenshots = history.get_history(session_id)
      expect(screenshots.length).to eq(10)
    end

    it "keeps the most recent screenshots when limit is exceeded" do
      # Save screenshots with identifiable URLs and unique timestamps
      15.times do |i|
        allow(Time).to receive(:now).and_return(Time.at(2000000 + i))
        history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
      end
      allow(Time).to receive(:now).and_call_original

      screenshots = history.get_history(session_id)
      urls = screenshots.map { |s| s[:url] }

      # Should have pages 5-14 (the last 10)
      expect(urls).to include("https://example.com/page14")
      expect(urls).to include("https://example.com/page5")
      expect(urls).not_to include("https://example.com/page0")
      expect(urls).not_to include("https://example.com/page4")
    end

    it "deletes old screenshot files when exceeding limit" do
      # Save 11 screenshots with unique timestamps
      filenames = []
      11.times do |i|
        # Use a unique timestamp to avoid collisions
        allow(Time).to receive(:now).and_return(Time.at(1000000 + i))
        result = history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
        filenames << result[:filename]
      end
      # Reset Time.now mock
      allow(Time).to receive(:now).and_call_original

      # First screenshot file should be deleted
      first_file = File.join("public", "screenshots", session_id, filenames.first)
      expect(File.exist?(first_file)).to be false

      # Last 10 should still exist
      filenames.last(10).each do |filename|
        file_path = File.join("public", "screenshots", session_id, filename)
        expect(File.exist?(file_path)).to be true
      end
    end

    it "is thread-safe" do
      threads = []
      mutex = Mutex.new
      timestamp_base = 3000000

      # Create 20 threads saving screenshots concurrently
      20.times do |i|
        threads << Thread.new do
          # Use a unique offset for each thread to avoid timestamp collisions
          unique_timestamp = mutex.synchronize { timestamp_base + i }
          # Create unique png data to avoid any caching issues
          thread_png_data = "\x89PNG\r\n\x1A\n#{i}".dup.force_encoding("ASCII-8BIT")

          # Temporarily stub Time.now for this specific call
          timestamp = Time.at(unique_timestamp)
          allow(Time).to receive(:now).and_return(timestamp)
          history.save_screenshot(session_id, thread_png_data, "https://example.com/page#{i}")
          allow(Time).to receive(:now).and_call_original
        end
      end

      threads.each(&:join)

      # Should have exactly 10 screenshots (due to limit)
      # This is the key test for thread-safety
      screenshots = history.get_history(session_id)
      expect(screenshots.length).to eq(10)

      # Verify the history is not corrupted
      expect(screenshots).to all(include(:timestamp, :url, :filename, :path))
    end
  end

  describe "#get_history" do
    it "returns an empty array for a session with no screenshots" do
      screenshots = history.get_history("nonexistent_session")
      expect(screenshots).to eq([])
    end

    it "returns screenshots in reverse chronological order (newest first)" do
      # Save 3 screenshots with unique timestamps
      3.times do |i|
        allow(Time).to receive(:now).and_return(Time.at(5000000 + i))
        history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
      end
      allow(Time).to receive(:now).and_call_original

      screenshots = history.get_history(session_id)

      # Newest should be first
      expect(screenshots[0][:url]).to eq("https://example.com/page2")
      expect(screenshots[1][:url]).to eq("https://example.com/page1")
      expect(screenshots[2][:url]).to eq("https://example.com/page0")
    end

    it "returns a copy of the history (not the original array)" do
      history.save_screenshot(session_id, png_data, url)

      screenshots = history.get_history(session_id)
      screenshots << { fake: "data" }

      # Original history should be unchanged
      expect(history.get_history(session_id).length).to eq(1)
    end
  end

  describe "#get_screenshot_count" do
    it "returns 0 for a session with no screenshots" do
      count = history.get_screenshot_count("nonexistent_session")
      expect(count).to eq(0)
    end

    it "returns the correct count of screenshots" do
      3.times do |i|
        allow(Time).to receive(:now).and_return(Time.at(6000000 + i))
        history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
      end
      allow(Time).to receive(:now).and_call_original

      count = history.get_screenshot_count(session_id)
      expect(count).to eq(3)
    end
  end

  describe "#cleanup_session" do
    it "removes all screenshots for a session" do
      # Save some screenshots with unique timestamps
      5.times do |i|
        allow(Time).to receive(:now).and_return(Time.at(7000000 + i))
        history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
      end
      allow(Time).to receive(:now).and_call_original

      # Verify they exist
      expect(history.get_screenshot_count(session_id)).to eq(5)

      # Clear the session
      history.cleanup_session(session_id)

      # Verify they're gone from history
      expect(history.get_screenshot_count(session_id)).to eq(0)
    end

    it "deletes the session directory and all files" do
      # Save some screenshots with unique timestamps
      3.times do |i|
        allow(Time).to receive(:now).and_return(Time.at(8000000 + i))
        history.save_screenshot(session_id, png_data, "https://example.com/page#{i}")
      end
      allow(Time).to receive(:now).and_call_original

      dir_path = File.join("public", "screenshots", session_id)
      expect(File.directory?(dir_path)).to be true

      # Clear the session
      history.cleanup_session(session_id)

      # Directory should be deleted
      expect(File.directory?(dir_path)).to be false
    end

    it "does not raise an error for a non-existent session" do
      expect { history.cleanup_session("nonexistent_session") }.not_to raise_error
    end
  end

  describe "singleton behavior" do
    it "returns the same instance" do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to be(instance2)
    end

    it "shares state across instance calls" do
      allow(Time).to receive(:now).and_return(Time.at(9000000))
      described_class.instance.save_screenshot(session_id, png_data, url)
      allow(Time).to receive(:now).and_call_original

      count = described_class.instance.get_screenshot_count(session_id)
      expect(count).to eq(1)
    end
  end
end
