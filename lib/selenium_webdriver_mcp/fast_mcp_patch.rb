# frozen_string_literal: true

require "fast_mcp"

# Monkey patch FastMCP to fix the RackTransport response handling bug in version 1.6.0
# The issue is that handle_request doesn't return the response for synchronous HTTP requests
# Instead it calls send_response which only works for SSE/async transports
#
# This patch captures the response in an instance variable and returns it for HTTP requests
# Note: Instance variables are used instead of thread-locals because FastMCP may process
# requests asynchronously in different threads, but the same RackTransport instance is used

module FastMcpRackPatch
  # Override origin validation to allow all origins in production
  # FastMCP validates origins by default, but for containerized deployment
  # we want to accept requests from any origin (use reverse proxy for auth)
  def validate_origin(request, env)
    # Always return true to bypass origin validation
    # In production, use a reverse proxy (nginx, Traefik) with authentication
    true
  end

  def send_message(message)
    # If we're in a synchronous request context, store the response in thread-local storage
    # This ensures each thread (request) has its own response capture, avoiding race conditions
    if Thread.current[:mcp_capturing_sync_response]
      json_message = message.is_a?(String) ? message : JSON.generate(message)
      Thread.current[:mcp_sync_response_capture] = json_message
      @logger&.debug("Captured synchronous response: #{json_message[0..100]}...")
    end

    # Also call the original for SSE clients
    super
  end

  def process_json_request_with_server(request, server)
    # Parse the request body
    body = request.body.read
    @logger&.debug("Request body: #{body}")

    # Extract headers that might be relevant
    headers = request.env.select { |k, _v| k.start_with?("HTTP_") }
                     .transform_keys { |k| k.sub("HTTP_", "").downcase.tr("_", "-") }

    # Store request context in Thread.current for tools to access
    # This allows tools to construct full URLs based on the incoming request
    # Use begin/ensure to guarantee cleanup
    begin
      Thread.current[:mcp_request_base_url] = build_base_url(request)

      # Set up thread-local flag to capture the synchronous response
      # Using Thread.current instead of instance variables prevents race conditions
      # when multiple requests are processed concurrently
      Thread.current[:mcp_capturing_sync_response] = true
      Thread.current[:mcp_sync_response_capture] = nil

      # Let the specific server handle the JSON request
      server.handle_request(body, headers: headers)

      # Get the captured response from thread-local storage
      response_json = Thread.current[:mcp_sync_response_capture]

      # Return the JSON response (or empty array if no response was captured)
      response_array = response_json ? [response_json] : []
      [200, { "Content-Type" => "application/json" }, response_array]
    ensure
      # Clean up thread-local state
      Thread.current[:mcp_capturing_sync_response] = nil
      Thread.current[:mcp_sync_response_capture] = nil
      Thread.current[:mcp_request_base_url] = nil
    end
  end

  private

  def build_base_url(request)
    # Extract scheme and host from the Rack request
    # Return nil if we can't build a valid URL (tools will fall back to relative paths)
    scheme = request.env["rack.url_scheme"] || "http"
    host = request.env["HTTP_HOST"] || request.env["SERVER_NAME"]
    port = request.env["SERVER_PORT"]

    # If we don't have a host, we can't build a URL
    return nil if host.nil? || host.empty?

    # Build base URL
    base_url = "#{scheme}://#{host}"

    # Only include port if it's non-standard
    if (scheme == "http" && port != "80") || (scheme == "https" && port != "443")
      base_url += ":#{port}" unless host.include?(":")
    end

    base_url
  rescue StandardError => e
    # If anything goes wrong, log and return nil
    # Tools will fall back to relative URLs
    @logger&.warn("Failed to build base URL: #{e.message}")
    nil
  end
end

# Apply the patch using prepend (which works at instance level)
FastMcp::Transports::RackTransport.prepend(FastMcpRackPatch)
