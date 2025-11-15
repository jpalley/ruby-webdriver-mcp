# frozen_string_literal: true

require "spec_helper"

RSpec.describe SeleniumWebdriverMcp::DriverManager do
  let(:config) do
    instance_double(
      SeleniumWebdriverMcp::Configuration,
      selenium_url: "http://example.com/wd/hub",
      browser_options: :browser_options,
      implicit_wait: 5,
      page_load_timeout: 30,
      script_timeout: 30
    )
  end

  let(:timeouts_double) do
    double("Timeouts").tap do |timeouts|
      allow(timeouts).to receive(:implicit_wait=)
      allow(timeouts).to receive(:page_load=)
      allow(timeouts).to receive(:script_timeout=)
    end
  end

  let(:manage_double) do
    double("Manage", timeouts: timeouts_double)
  end

  let(:http_client_one) { instance_double(SeleniumWebdriverMcp::ThreadSafeHttpClient, close: nil) }
  let(:http_client_two) { instance_double(SeleniumWebdriverMcp::ThreadSafeHttpClient, close: nil) }

  let(:driver_one) do
    double("DriverOne", session_id: "driver-1", manage: manage_double).tap do |driver|
      allow(driver).to receive(:quit)
      navigator = double("Navigator")
      allow(navigator).to receive(:to).and_raise(Net::ReadTimeout)
      allow(driver).to receive(:navigate).and_return(navigator)
    end
  end

  let(:driver_two) do
    double("DriverTwo", session_id: "driver-2", manage: manage_double).tap do |driver|
      allow(driver).to receive(:quit)
      navigator = double("Navigator")
      allow(navigator).to receive(:to).and_return(nil)
      allow(driver).to receive(:navigate).and_return(navigator)
      allow(driver).to receive(:current_url).and_return("http://example.com/after")
    end
  end

  let(:driver_three) do
    double("DriverThree", session_id: "driver-3", manage: manage_double).tap do |driver|
      allow(driver).to receive(:quit)
      navigator = double("Navigator")
      allow(navigator).to receive(:to).and_raise(Net::ReadTimeout)
      allow(driver).to receive(:navigate).and_return(navigator)
    end
  end

  let(:manager) { described_class.new(config) }

  before do
    allow(SeleniumWebdriverMcp::ThreadSafeHttpClient).to receive(:new).and_return(http_client_one, http_client_two)
    allow(Selenium::WebDriver).to receive(:for).and_return(driver_one, driver_two)
    allow(SeleniumWebdriverMcp::SessionManager.instance).to receive(:session_count).and_return(1)
  end

  describe "#navigate_to" do
    it "restarts the driver when a network timeout occurs and succeeds on retry" do
      result = manager.navigate_to("http://example.com/page")

      expect(result).to eq(success: true, url: "http://example.com/after")
      expect(Selenium::WebDriver).to have_received(:for).twice
      expect(http_client_one).to have_received(:close)
      expect(driver_one).to have_received(:quit)
    end

    it "cleans up the driver and surfaces the error when retries are exhausted" do
      allow(Selenium::WebDriver).to receive(:for).and_return(driver_one, driver_three)

      expect do
        manager.navigate_to("http://example.com/page")
      end.to raise_error(Net::ReadTimeout)

      expect(http_client_two).to have_received(:close)
      expect(driver_three).to have_received(:quit)
      expect(manager.driver).to be_nil
    end
  end
end
