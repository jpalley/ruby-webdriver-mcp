# frozen_string_literal: true

require "net/http"
require "json"

module McpClientHelper
  class McpClient
    attr_reader :base_url, :port

    def initialize(port: 9393)
      @base_url = "http://localhost:#{port}"
      @port = port
      @request_id = 0
    end

    def call_tool(tool_name, arguments = {})
      request = {
        jsonrpc: "2.0",
        id: next_request_id,
        method: "tools/call",
        params: {
          name: tool_name,
          arguments: arguments
        }
      }

      response = post_json("/mcp", request)
      result = parse_response(response)

      # FastMCP wraps tool results in a content array
      # Extract the actual result from the content[0].text field
      if result[:content]&.first&.dig(:text)
        text_result = result[:content].first[:text]
        # The text might be:
        # 1. A string representation of a Ruby hash (from .inspect)
        # 2. A plain error message string
        #  3. Or an actual data value

        # Try to eval it as Ruby code (for hash results)
        # rubocop:disable Security/Eval
        begin
          parsed_result = eval(text_result)

          # Check if the result indicates an error that should be raised
          # Only raise for errors that indicate invalid operations (like duplicates)
          # Don't raise for operations on non-existent resources (idempotent deletes, etc.)
          if parsed_result.is_a?(Hash) && parsed_result[:success] == false
            error_msg = parsed_result[:error] || "Tool execution failed"
            # Raise if it's a "resource already exists" type error
            raise error_msg if error_msg.match?(/already exists|duplicate/i)
            # For other errors (like "not found"), return the hash
          end

          parsed_result
        rescue SyntaxError
          # If eval fails, treat it as a plain error message
          # Check if the result indicates an error
          raise text_result if result[:isError] || text_result.start_with?("Error:")

          # Return the text as-is
          text_result
        end
        # rubocop:enable Security/Eval
      else
        result
      end
    end

    def list_tools
      request = {
        jsonrpc: "2.0",
        id: next_request_id,
        method: "tools/list"
      }

      response = post_json("/mcp", request)
      result = parse_response(response)
      result[:tools] || []
    end

    def list_resources
      request = {
        jsonrpc: "2.0",
        id: next_request_id,
        method: "resources/list"
      }

      response = post_json("/mcp", request)
      parse_response(response)
    end

    def read_resource(uri)
      request = {
        jsonrpc: "2.0",
        id: next_request_id,
        method: "resources/read",
        params: {
          uri: uri
        }
      }

      response = post_json("/mcp", request)
      parse_response(response)
    end

    private

    def next_request_id
      @request_id += 1
    end

    def post_json(path, body)
      uri = URI("#{base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
      request.body = body.to_json

      http.request(request)
    rescue Errno::ECONNREFUSED => e
      raise "MCP server not running on #{base_url}: #{e.message}"
    end

    def parse_response(response)
      return nil unless response.body

      parsed = JSON.parse(response.body, symbolize_names: true)

      raise "MCP Error: #{parsed[:error][:message]}" if parsed[:error]

      parsed[:result]
    end
  end

  def mcp_client
    @mcp_client ||= McpClient.new(port: 9393)
  end

  def start_mcp_server
    return if @mcp_server_thread

    # Create the Rack app using FastMCP's rack_middleware helper (proper way per FastMCP docs)
    @mcp_server = SeleniumWebdriverMcp::Server.new
    rack_app = @mcp_server.rack_app(localhost_only: false)

    # Start WEBrick in a thread with proper Rack integration
    require "webrick"
    begin
      require "rackup/handler/webrick"
      handler_class = Rackup::Handler::WEBrick
    rescue LoadError
      # Fallback for rackup 1.x / Rack 2.x
      require "rack/handler/webrick"
      handler_class = Rack::Handler::WEBrick
    end

    @webrick_server = WEBrick::HTTPServer.new(
      Port: 9393,
      BindAddress: "127.0.0.1",
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )

    # Mount the Rack app using WEBrick's Rack handler
    @webrick_server.mount "/", handler_class, rack_app

    @mcp_server_thread = Thread.new { @webrick_server.start }

    # Wait for server to be ready
    max_attempts = 10
    attempt = 0
    begin
      mcp_client.list_tools
    rescue StandardError
      attempt += 1
      raise "MCP server failed to start" if attempt >= max_attempts

      sleep 0.5
      retry
    end
  end

  def stop_mcp_server
    return unless @webrick_server

    @webrick_server.shutdown
    @mcp_server_thread&.join(5)
    @mcp_server_thread = nil
    @webrick_server = nil
    @mcp_server = nil
  end
end

RSpec.configure do |config|
  config.include McpClientHelper, type: :mcp_integration

  config.before(:suite) do
    # Start MCP server once for all MCP tests if running MCP integration tests
    if RSpec.configuration.files_to_run.any? { |f| f.include?("mcp_integration") }
      extend McpClientHelper

      start_mcp_server
    end
  end

  config.after(:suite) do
    # Stop MCP server after all tests
    if RSpec.configuration.files_to_run.any? { |f| f.include?("mcp_integration") }
      extend McpClientHelper

      stop_mcp_server
    end
  end
end
