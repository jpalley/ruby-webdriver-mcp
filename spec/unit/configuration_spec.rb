# frozen_string_literal: true

require "spec_helper"

RSpec.describe SeleniumWebdriverMcp::Configuration do
  let(:config) { described_class.new }

  describe "default values" do
    it "sets default selenium_url" do
      # Configuration reads from ENV, so we need to test with a clean ENV
      old_selenium_url = ENV.delete("SELENIUM_URL")
      begin
        fresh_config = described_class.new
        expect(fresh_config.selenium_url).to eq("http://localhost:4444/wd/hub")
      ensure
        ENV["SELENIUM_URL"] = old_selenium_url if old_selenium_url
      end
    end

    it "sets default browser to chrome" do
      expect(config.browser).to eq(:chrome)
    end

    it "enables headless mode by default" do
      expect(config.headless).to be true
    end

    it "sets default timeouts" do
      expect(config.implicit_wait).to eq(10)
      expect(config.page_load_timeout).to eq(30)
      expect(config.script_timeout).to eq(30)
    end

    it "sets default window size" do
      expect(config.window_size).to eq([1400, 1400])
    end
  end

  describe "browser_options" do
    it "returns Chrome options when browser is chrome" do
      config.browser = :chrome

      options = config.browser_options

      expect(options).to be_a(Selenium::WebDriver::Chrome::Options)
    end

    it "returns Firefox options when browser is firefox" do
      config.browser = :firefox

      options = config.browser_options

      expect(options).to be_a(Selenium::WebDriver::Firefox::Options)
    end

    it "returns Edge options when browser is edge" do
      config.browser = :edge

      options = config.browser_options

      expect(options).to be_a(Selenium::WebDriver::Edge::Options)
    end

    it "raises error for unsupported browser" do
      config.browser = :safari

      expect do
        config.browser_options
      end.to raise_error(SeleniumWebdriverMcp::Error, /Unsupported browser/)
    end

    it "includes headless argument when headless is true" do
      config.browser = :chrome
      config.headless = true

      options = config.browser_options

      expect(options.args).to include("--headless")
    end

    it "excludes headless argument when headless is false" do
      config.browser = :chrome
      config.headless = false

      options = config.browser_options

      expect(options.args).not_to include("--headless")
    end
  end
end
