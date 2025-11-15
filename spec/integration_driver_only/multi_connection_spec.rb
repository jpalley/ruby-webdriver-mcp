# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "json"
require "stringio"
require "support/test_html_server"

RSpec.describe "Multi-connection MCP requests", type: :integration do
  include Rack::Test::Methods

  # Use a shared server instance to match production behavior
  before(:all) do
    @shared_server = SeleniumWebdriverMcp::Server.new
    @shared_app = @shared_server.rack_app
  end

  let(:app) { @shared_app }

  def mcp_request(method, params = {}, id = 1)
    post "/mcp", JSON.generate({
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: id
    }), { "CONTENT_TYPE" => "application/json" }

    puts "Response status: #{last_response.status}"
    puts "Response body: #{last_response.body}"

    JSON.parse(last_response.body) if last_response.body && !last_response.body.empty?
  rescue JSON::ParserError => e
    puts "JSON Parse Error: #{e.message}"
    puts "Response body was: #{last_response.body.inspect}"
    nil
  end

  it "handles first connection initialize request" do
    response = mcp_request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "test-client-1", version: "1.0.0" }
    }, 1)

    expect(response).not_to be_nil
    expect(response["jsonrpc"]).to eq("2.0")
    expect(response["result"]).to be_a(Hash)
    expect(response["result"]["serverInfo"]).to be_a(Hash)
    expect(response["result"]["serverInfo"]["name"]).to eq("selenium-webdriver-mcp")
  end

  it "handles second connection initialize request" do
    response = mcp_request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "test-client-2", version: "1.0.0" }
    }, 2)

    expect(response).not_to be_nil
    expect(response["jsonrpc"]).to eq("2.0")
    expect(response["result"]).to be_a(Hash)
    expect(response["result"]["serverInfo"]).to be_a(Hash)
    expect(response["result"]["serverInfo"]["name"]).to eq("selenium-webdriver-mcp")
    expect(response["result"]["capabilities"]).to be_a(Hash)
    expect(response["result"]["capabilities"]).not_to be_nil
  end

  it "handles multiple sequential requests (simulating multiple connections)" do
    3.times do |i|
      response = mcp_request("initialize", {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "test-client-#{i}", version: "1.0.0" }
      }, i + 10)

      expect(response).not_to be_nil, "Request #{i} got nil response"
      expect(response["jsonrpc"]).to eq("2.0")
      expect(response["result"]).to be_a(Hash)
      expect(response["result"]["capabilities"]).not_to be_nil
      expect(response["result"]["serverInfo"]).to be_a(Hash)
    end
  end

  it "handles truly concurrent requests without race conditions" do
    threads = []
    results = []
    mutex = Mutex.new

    # Simulate 5 concurrent connections
    5.times do |i|
      threads << Thread.new do
        # Each thread makes its own request with a unique ID
        request_id = 100 + i

        env = {
          "REQUEST_METHOD" => "POST",
          "PATH_INFO" => "/mcp",
          "rack.input" => StringIO.new(JSON.generate({
            jsonrpc: "2.0",
            method: "initialize",
            params: {
              protocolVersion: "2024-11-05",
              capabilities: {},
              clientInfo: { name: "concurrent-client-#{i}", version: "1.0.0" }
            },
            id: request_id
          })),
          "CONTENT_TYPE" => "application/json",
          "HTTP_HOST" => "localhost",
          "REMOTE_ADDR" => "127.0.0.1"
        }

        status, _headers, body = app.call(env)
        response = JSON.parse(body.join) if body && status == 200

        mutex.synchronize do
          results << {
            thread_id: i,
            request_id: request_id,
            response: response,
            response_id: response&.dig("id")
          }
        end
      end
    end

    threads.each(&:join)

    # Verify all responses are correct and match their request IDs
    results.each do |result|
      expect(result[:response]).not_to be_nil, "Thread #{result[:thread_id]} got nil response"
      expect(result[:response]["jsonrpc"]).to eq("2.0")
      expect(result[:response]["id"]).to eq(result[:request_id]),
        "Thread #{result[:thread_id]} expected response ID #{result[:request_id]} but got #{result[:response_id]}"
      expect(result[:response]["result"]).to be_a(Hash)
      expect(result[:response]["result"]["capabilities"]).not_to be_nil
      expect(result[:response]["result"]["serverInfo"]).to be_a(Hash)
    end
  end

  describe "3 concurrent connections performing full workflows" do
    def make_mcp_request(method, params, id)
      env = {
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/mcp",
        "rack.input" => StringIO.new(JSON.generate({
          jsonrpc: "2.0",
          method: method,
          params: params,
          id: id
        })),
        "CONTENT_TYPE" => "application/json",
        "HTTP_HOST" => "localhost",
        "REMOTE_ADDR" => "127.0.0.1"
      }

      status, _headers, body = app.call(env)
      response = JSON.parse(body.join) if body && status == 200
      response
    end

    it "handles 3 clients each initializing concurrently" do
      threads = []
      results = []
      mutex = Mutex.new

      3.times do |i|
        threads << Thread.new do
          client_name = "client-#{i}"
          request_id = 200 + i

          response = make_mcp_request("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: {},
            clientInfo: { name: client_name, version: "1.0.0" }
          }, request_id)

          mutex.synchronize do
            results << {
              client: client_name,
              request_id: request_id,
              response: response
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all 3 clients got correct responses
      expect(results.size).to eq(3)
      results.each do |result|
        expect(result[:response]).not_to be_nil, "#{result[:client]} got nil response"
        expect(result[:response]["id"]).to eq(result[:request_id]),
          "#{result[:client]} expected ID #{result[:request_id]} but got #{result[:response]['id']}"
        expect(result[:response]["result"]["serverInfo"]["name"]).to eq("selenium-webdriver-mcp")
      end
    end

    it "handles 3 clients each listing tools concurrently" do
      threads = []
      results = []
      mutex = Mutex.new

      # First, all clients initialize
      3.times do |i|
        make_mcp_request("initialize", {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "client-#{i}", version: "1.0.0" }
        }, 300 + i)
      end

      # Then all clients request tools/list concurrently
      3.times do |i|
        threads << Thread.new do
          client_name = "client-#{i}"
          request_id = 310 + i

          response = make_mcp_request("tools/list", {}, request_id)

          mutex.synchronize do
            results << {
              client: client_name,
              request_id: request_id,
              response: response
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all 3 clients got the same tools list
      expect(results.size).to eq(3)
      results.each do |result|
        expect(result[:response]).not_to be_nil, "#{result[:client]} got nil response"
        expect(result[:response]["id"]).to eq(result[:request_id]),
          "#{result[:client]} expected ID #{result[:request_id]} but got #{result[:response]['id']}"
        expect(result[:response]["result"]["tools"]).to be_an(Array)
        expect(result[:response]["result"]["tools"].size).to eq(11)

        # Verify key tools are present
        tool_names = result[:response]["result"]["tools"].map { |t| t["name"] }
        expect(tool_names).to include("create_session", "navigate", "find_element", "click_element")
      end
    end

    it "handles 3 clients creating sessions and performing operations concurrently" do
      threads = []
      results = []
      mutex = Mutex.new

      3.times do |i|
        threads << Thread.new do
          client_name = "client-#{i}"
          base_id = 400 + (i * 10)

          # Initialize
          init_response = make_mcp_request("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: {},
            clientInfo: { name: client_name, version: "1.0.0" }
          }, base_id)

          # Create session with custom ID
          session_id = "test-session-#{i}"
          create_response = make_mcp_request("tools/call", {
            name: "create_session",
            arguments: { session_id: session_id }
          }, base_id + 1)

          # List sessions
          list_response = make_mcp_request("tools/call", {
            name: "destroy_session",
            arguments: { session_id: session_id }
          }, base_id + 2)

          mutex.synchronize do
            results << {
              client: client_name,
              session_id: session_id,
              init_response: init_response,
              create_response: create_response,
              list_response: list_response
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all 3 clients completed their workflows
      expect(results.size).to eq(3)
      results.each do |result|
        # Verify initialize
        expect(result[:init_response]).not_to be_nil
        expect(result[:init_response]["result"]["serverInfo"]).to be_a(Hash)

        # Verify create_session
        expect(result[:create_response]).not_to be_nil
        expect(result[:create_response]["result"]).to be_a(Hash)
        content = result[:create_response]["result"]["content"]
        expect(content).to be_an(Array)
        expect(content.first["text"]).to include("session_id")
        expect(content.first["text"]).to include(result[:session_id])

        # Verify destroy worked
        expect(result[:list_response]).not_to be_nil
        expect(result[:list_response]["result"]).to be_a(Hash)
      end
    end

    it "handles 3 clients with interleaved requests in random order" do
      threads = []
      all_results = []
      mutex = Mutex.new

      3.times do |i|
        threads << Thread.new do
          client_name = "client-#{i}"
          client_results = []

          # Each client makes multiple requests with random sleeps to interleave
          10.times do |req_num|
            request_id = 500 + (i * 100) + req_num

            # Random small delay to maximize interleaving
            sleep(rand * 0.01)

            response = make_mcp_request("tools/list", {}, request_id)

            client_results << {
              request_id: request_id,
              response_id: response&.dig("id"),
              has_tools: response&.dig("result", "tools")&.is_a?(Array)
            }
          end

          mutex.synchronize do
            all_results << {
              client: client_name,
              results: client_results
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all 3 clients got all 10 responses correctly
      expect(all_results.size).to eq(3)
      all_results.each do |client_result|
        expect(client_result[:results].size).to eq(10)

        client_result[:results].each do |req|
          expect(req[:response_id]).to eq(req[:request_id]),
            "#{client_result[:client]} request #{req[:request_id]} got response #{req[:response_id]}"
          expect(req[:has_tools]).to be true
        end
      end
    end

    it "maintains session isolation across 3 concurrent clients", :integration_driver_only do
      threads = []
      results = []
      mutex = Mutex.new

      3.times do |i|
        threads << Thread.new do
          client_name = "isolation-client-#{i}"
          session_id = "isolated-session-#{i}"
          base_id = 600 + (i * 10)

          # Initialize client
          make_mcp_request("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: {},
            clientInfo: { name: client_name, version: "1.0.0" }
          }, base_id)

          # Create session
          create_resp = make_mcp_request("tools/call", {
            name: "create_session",
            arguments: { session_id: session_id }
          }, base_id + 1)

          # Verify the session ID in response matches what we requested
          created_id = nil
          if create_resp && create_resp["result"] && create_resp["result"]["content"]
            text = create_resp["result"]["content"].first["text"]
            # Parse JSON from text
            data = JSON.parse(text)
            created_id = data["session_id"]
          end

          # Navigate to test page
          nav_resp = make_mcp_request("tools/call", {
            name: "navigate",
            arguments: { session_id: session_id, url: "http://app:9292/simple.html" }
          }, base_id + 2)

          # Find an element specific to this session
          find_resp = make_mcp_request("tools/call", {
            name: "find_element",
            arguments: { session_id: session_id, strategy: "tag_name", value: "h1" }
          }, base_id + 3)

          element_id = nil
          if find_resp && find_resp["result"] && find_resp["result"]["content"]
            text = find_resp["result"]["content"].first["text"]
            element_id = text.match(/element_\d+/)&.to_s
          end

          # Click the element
          click_resp = make_mcp_request("tools/call", {
            name: "click_element",
            arguments: { session_id: session_id, element_id: element_id }
          }, base_id + 4) if element_id

          # Destroy session
          destroy_resp = make_mcp_request("tools/call", {
            name: "destroy_session",
            arguments: { session_id: session_id }
          }, base_id + 5)

          mutex.synchronize do
            results << {
              client: client_name,
              requested_session_id: session_id,
              created_session_id: created_id,
              element_id: element_id,
              create_response: create_resp,
              navigate_response: nav_resp,
              find_response: find_resp,
              click_response: click_resp,
              destroy_response: destroy_resp
            }
          end
        end
      end

      threads.each(&:join)

      # Verify each client got their own isolated session and could interact with the page
      expect(results.size).to eq(3)

      session_ids = results.map { |r| r[:created_session_id] }
      expect(session_ids.uniq.size).to eq(3), "Sessions should be unique: #{session_ids.inspect}"

      results.each do |result|
        expect(result[:created_session_id]).to eq(result[:requested_session_id]),
          "#{result[:client]} requested session #{result[:requested_session_id]} but got #{result[:created_session_id]}"
        expect(result[:create_response]["result"]["isError"]).to be_falsy
        expect(result[:navigate_response]["result"]["isError"]).to be_falsy
        expect(result[:element_id]).to match(/element_\d+/),
          "#{result[:client]} should have found an element"
        expect(result[:destroy_response]["result"]["isError"]).to be_falsy
      end
    end

    it "handles 3 clients simultaneously navigating and interacting with different pages", :integration_driver_only do
      threads = []
      results = []
      mutex = Mutex.new

      # Each client will interact with a different test page
      test_scenarios = [
        { client: "concurrent-nav-0", session: "nav-session-0", page: "simple.html", find_strategy: "tag_name", find_value: "h1" },
        { client: "concurrent-nav-1", session: "nav-session-1", page: "form.html", find_strategy: "id", find_value: "username" },
        { client: "concurrent-nav-2", session: "nav-session-2", page: "simple.html", find_strategy: "tag_name", find_value: "p" }
      ]

      test_scenarios.each_with_index do |scenario, i|
        threads << Thread.new do
          base_id = 700 + (i * 10)

          # Initialize
          make_mcp_request("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: {},
            clientInfo: { name: scenario[:client], version: "1.0.0" }
          }, base_id)

          # Create session
          create_resp = make_mcp_request("tools/call", {
            name: "create_session",
            arguments: { session_id: scenario[:session] }
          }, base_id + 1)

          # Navigate
          nav_resp = make_mcp_request("tools/call", {
            name: "navigate",
            arguments: { session_id: scenario[:session], url: "http://app:9292/#{scenario[:page]}" }
          }, base_id + 2)

          # Find element
          find_resp = make_mcp_request("tools/call", {
            name: "find_element",
            arguments: {
              session_id: scenario[:session],
              strategy: scenario[:find_strategy],
              value: scenario[:find_value]
            }
          }, base_id + 3)

          # Extract element ID
          element_id = nil
          if find_resp && find_resp["result"] && find_resp["result"]["content"]
            text = find_resp["result"]["content"].first["text"]
            element_id = text.match(/element_\d+/)&.to_s
          end

          # Interact with element (send keys if it's an input, click otherwise)
          interact_resp = if scenario[:find_strategy] == "id" && scenario[:find_value] == "username"
            make_mcp_request("tools/call", {
              name: "send_keys",
              arguments: { session_id: scenario[:session], element_id: element_id, text: "testuser#{i}" }
            }, base_id + 4)
          else
            make_mcp_request("tools/call", {
              name: "click_element",
              arguments: { session_id: scenario[:session], element_id: element_id }
            }, base_id + 4)
          end if element_id

          # Destroy session
          destroy_resp = make_mcp_request("tools/call", {
            name: "destroy_session",
            arguments: { session_id: scenario[:session] }
          }, base_id + 5)

          mutex.synchronize do
            results << {
              client: scenario[:client],
              session_id: scenario[:session],
              page: scenario[:page],
              element_id: element_id,
              all_successful: (
                create_resp && !create_resp["result"]["isError"] &&
                nav_resp && !nav_resp["result"]["isError"] &&
                find_resp && !find_resp["result"]["isError"] &&
                element_id && interact_resp && !interact_resp["result"]["isError"] &&
                destroy_resp && !destroy_resp["result"]["isError"]
              )
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all 3 clients successfully completed their workflows
      expect(results.size).to eq(3)
      results.each do |result|
        expect(result[:all_successful]).to be(true),
          "#{result[:client]} failed to complete workflow (session: #{result[:session_id]}, page: #{result[:page]})"
        expect(result[:element_id]).to match(/element_\d+/),
          "#{result[:client]} should have found an element"
      end

      # Verify each client found their own unique element (different element caches)
      element_ids = results.map { |r| r[:element_id] }
      # All should be element_0 in their respective caches, showing isolation
      expect(element_ids).to all(match(/element_0/))
    end
  end
end
