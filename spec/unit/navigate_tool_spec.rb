# frozen_string_literal: true

require "spec_helper"

RSpec.describe SeleniumWebdriverMcp::Tools::NavigateTool do
  describe "#rewrite_localhost" do
    let(:tool) { described_class.new }

    context "when REWRITE_LOCALHOST_TO is not set" do
      before do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = nil
      end

      it "does not rewrite localhost URLs" do
        url = "http://localhost:3000/path"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://localhost:3000/path")
      end

      it "does not rewrite 127.0.0.1 URLs" do
        url = "http://127.0.0.1:8080/api"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://127.0.0.1:8080/api")
      end
    end

    context "when REWRITE_LOCALHOST_TO is set" do
      before do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = "app"
      end

      after do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = nil
      end

      it "rewrites localhost with port" do
        url = "http://localhost:3000/path"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://app:3000/path")
      end

      it "rewrites localhost without port" do
        url = "http://localhost/path"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://app/path")
      end

      it "rewrites 127.0.0.1 with port" do
        url = "http://127.0.0.1:8080/api"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://app:8080/api")
      end

      it "rewrites 127.0.0.1 without port" do
        url = "http://127.0.0.1/api/users"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://app/api/users")
      end

      it "rewrites https localhost URLs" do
        url = "https://localhost:443/secure"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("https://app:443/secure")
      end

      it "does not rewrite non-localhost URLs" do
        url = "http://example.com:3000/path"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://example.com:3000/path")
      end

      it "does not rewrite URLs containing localhost in path" do
        url = "http://example.com/localhost/path"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://example.com/localhost/path")
      end

      it "handles multiple rewrites in same URL (edge case)" do
        # This shouldn't happen in practice, but test the behavior
        url = "http://localhost:3000/redirect?url=http://localhost:4000"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://app:3000/redirect?url=http://app:4000")
      end
    end

    context "when REWRITE_LOCALHOST_TO is empty string" do
      before do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = ""
      end

      after do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = nil
      end

      it "does not rewrite localhost URLs" do
        url = "http://localhost:3000/path"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://localhost:3000/path")
      end
    end

    context "with custom host containing special characters" do
      before do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = "my-app.example.com"
      end

      after do
        SeleniumWebdriverMcp.configuration.rewrite_localhost_to = nil
      end

      it "rewrites localhost to custom host" do
        url = "http://localhost:8080/api"
        rewritten = tool.send(:rewrite_localhost, url)
        expect(rewritten).to eq("http://my-app.example.com:8080/api")
      end
    end
  end
end
