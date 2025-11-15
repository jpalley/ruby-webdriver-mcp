# frozen_string_literal: true

require "spec_helper"
require "net/http"
require "json"
require "rack"

RSpec.describe "HTTP Transport Integration", :http_integration do
  let(:port) { 9999 }
  let(:base_url) { "http://localhost:#{port}" }
  let(:server_thread) { nil }

  # Start a real Rack server with the MCP app
  before(:all) do
    @port = 9999
    @base_url = "http://localhost:#{@port}"

    # Create the MCP server
    server = SeleniumWebdriverMcp::Server.new(
      name: "selenium-webdriver-mcp-test",
      version: SeleniumWebdriverMcp::VERSION
    )

    # Get the Rack app with localhost_only: false to test origin validation
    mcp_app = server.rack_app(localhost_only: false)

    # Add health check middleware (same as in config.ru)
    class HealthCheckMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        if env["PATH_INFO"] == "/health"
          # Rack 3.x requires lowercase header names
          [200, { "content-type" => "application/json" }, ['{"status":"ok","version":"' + SeleniumWebdriverMcp::VERSION + '"}']]
        else
          @app.call(env)
        end
      end
    end

    @app = HealthCheckMiddleware.new(mcp_app)

    # Start WEBrick server in a thread
    require "webrick"
    @server = WEBrick::HTTPServer.new(
      Port: @port,
      BindAddress: "127.0.0.1",
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )

    # Mount the Rack app using a servlet
    @server.mount_proc "/" do |req, res|
      # Wrap the request body in a StringIO for Rack compatibility
      require "stringio"
      body_io = StringIO.new(req.body || "")

      env = req.meta_vars.merge({
        "rack.input" => body_io,
        "rack.errors" => $stderr,
        "rack.url_scheme" => "http",
        "HTTP_VERSION" => req.http_version,
        "REQUEST_METHOD" => req.request_method,
        "REQUEST_PATH" => req.path,
        "PATH_INFO" => req.path,
        "QUERY_STRING" => req.query_string || "",
        "SERVER_NAME" => "127.0.0.1",
        "SERVER_PORT" => @port.to_s,
        "rack.multithread" => true,
        "rack.multiprocess" => false,
        "rack.run_once" => false,
        "rack.version" => [1, 3]
      })

      # Add headers to env
      req.header.each do |key, values|
        env_key = "HTTP_#{key.upcase.tr("-", "_")}"
        env[env_key] = values.join(", ")
      end

      # Call the Rack app
      status, headers, body = @app.call(env)

      # Set response
      res.status = status
      headers.each { |k, v| res[k] = v }
      body.each { |chunk| res.body << chunk }
      body.close if body.respond_to?(:close)
    end

    # Start server in background thread
    @server_thread = Thread.new { @server.start }

    # Wait for server to start
    sleep 0.5
  end

  after(:all) do
    @server&.shutdown
    @server_thread&.join(2) # timeout in seconds
  end

  describe "MCP JSON-RPC endpoint" do
    it "accepts requests without origin validation errors" do
      uri = URI("#{@base_url}/mcp")
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      # Simulate a request from a different origin
      request["Origin"] = "http://example.com"

      request.body = {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list"
      }.to_json

      response = http.request(request)

      # Debug output if there's an error
      if response.code != "200"
        puts "\n=== DEBUG: Response Code: #{response.code} ==="
        puts "Response Body: #{response.body}"
        puts "=== END DEBUG ===\n"
      end

      # Should NOT get origin validation error
      expect(response.code).to eq("200")
      expect(response["Content-Type"]).to include("application/json")

      body = JSON.parse(response.body)
      expect(body).to have_key("jsonrpc")
      expect(body).to have_key("id")
      expect(body["id"]).to eq(1)

      # Should not have an error about origin validation
      if body["error"]
        expect(body["error"]["message"]).not_to include("Origin validation failed")
      end

      # Should have a result with tools
      expect(body).to have_key("result")
      expect(body["result"]).to have_key("tools")
      expect(body["result"]["tools"]).to be_an(Array)
    end

    it "handles requests without origin header" do
      uri = URI("#{@base_url}/mcp")
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      # No Origin header

      request.body = {
        jsonrpc: "2.0",
        id: 2,
        method: "tools/list"
      }.to_json

      response = http.request(request)

      expect(response.code).to eq("200")
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(2)
      expect(body).to have_key("result")
    end

    it "returns proper JSON-RPC response for initialize method" do
      uri = URI("#{@base_url}/mcp")
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"

      request.body = {
        jsonrpc: "2.0",
        id: 3,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: {
            name: "test-client",
            version: "1.0.0"
          }
        }
      }.to_json

      response = http.request(request)

      expect(response.code).to eq("200")
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(3)
      expect(body).to have_key("result")
      expect(body["result"]).to have_key("serverInfo")
      expect(body["result"]["serverInfo"]["name"]).to eq("selenium-webdriver-mcp-test")
    end
  end

  describe "Health check endpoint" do
    it "returns OK status" do
      uri = URI("#{@base_url}/health")
      response = Net::HTTP.get_response(uri)

      expect(response.code).to eq("200")
      expect(response["Content-Type"]).to include("application/json")

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body["version"]).to eq(SeleniumWebdriverMcp::VERSION)
    end
  end
end
