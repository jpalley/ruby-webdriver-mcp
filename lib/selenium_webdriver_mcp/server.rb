# frozen_string_literal: true

require "fast_mcp"
require "logger"

# Require all tools
require_relative "tools/create_session_tool"
require_relative "tools/destroy_session_tool"
require_relative "tools/navigate_tool"
require_relative "tools/find_element_tool"
require_relative "tools/click_tool"
require_relative "tools/send_keys_tool"
require_relative "tools/execute_script_tool"
require_relative "tools/get_console_logs_tool"
require_relative "tools/save_desktop_screenshot_tool"
require_relative "tools/save_mobile_screenshot_tool"
require_relative "tools/find_and_click_tool"

# Require middleware
require_relative "image_middleware"
require_relative "web_app"

# Require utilities
require_relative "screenshot_history"

module SeleniumWebdriverMcp
  class Server
    attr_reader :session_manager, :logger

    def initialize(name: "selenium-webdriver-mcp", version: VERSION, logger: nil)
      @name = name
      @version = version
      @session_manager = SessionManager.instance
      @logger = logger || create_default_logger
    end

    # Start the MCP server using STDIO transport (for Claude Desktop)
    def start
      server = FastMcp::Server.new(name: @name, version: @version)
      register_tools(server)
      register_resources(server)
      server.start
    end

    # Create a Rack application with MCP middleware for HTTP/SSE transport
    # Uses custom router to separate MCP endpoints from web app
    def rack_app(base_app: nil, localhost_only: false, **options)
      @logger.info { "Starting MCP Server: #{@name} v#{@version}" }
      @logger.info { "Log level: #{@logger.level} (#{Logger::SEV_LABEL[@logger.level]})" }

      # Create the web application stack (Sinatra + ImageMiddleware)
      web_app = WebApp.new
      app_with_images = ImageMiddleware.new(web_app)

      # Configure allowed origins - accept all for production deployment
      # In production, you should use a reverse proxy with authentication
      options[:allowed_origins] ||= ["*"] unless localhost_only

      # Create MCP-only app (doesn't handle non-MCP requests)
      mcp_base = lambda do |_env|
        [404, { "content-type" => "text/plain" }, ["Not Found"]]
      end

      # Configure MCP paths
      options[:path_prefix] ||= ""
      options[:messages_route] ||= "mcp"
      options[:sse_route] ||= "sse"
      options[:logger] ||= @logger

      # Create the MCP handler
      @logger.info { "Registering MCP endpoints: /mcp (JSON-RPC), /sse (Server-Sent Events)" }
      mcp_app = FastMcp.rack_middleware(
        mcp_base,
        name: @name,
        version: @version,
        localhost_only: localhost_only,
        **options
      ) do |server|
        register_tools(server)
        register_resources(server)
      end
      @logger.info { "Registered #{count_tools} tools and #{count_resources} resources" }

      # Create a router that:
      # - Routes /mcp and /sse to MCP handler
      # - Routes everything else to web app
      lambda do |env|
        path = env["PATH_INFO"]
        method = env["REQUEST_METHOD"]

        if path.start_with?("/mcp", "/sse")
          @logger.debug { "Routing #{method} #{path} → MCP handler" } if @logger
          mcp_app.call(env)
        else
          @logger.debug { "Routing #{method} #{path} → Web app" } if @logger
          app_with_images.call(env)
        end
      end
    end

    private

    def create_default_logger
      # Check environment variables for log level
      log_level = if ENV["DEBUG"] == "true"
                    Logger::DEBUG
                  elsif ENV["LOG_LEVEL"]
                    Logger.const_get(ENV["LOG_LEVEL"].upcase)
                  else
                    Logger::INFO
                  end

      logger = Logger.new($stdout)
      logger.level = log_level
      logger.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{severity.ljust(5)} MCP: #{msg}\n"
      end
      logger
    end

    def count_tools
      11 # Total number of tools registered
    end

    def count_resources
      0 # No resources registered
    end

    def register_tools(server)
      # Session management
      server.register_tool(Tools::CreateSessionTool)
      server.register_tool(Tools::DestroySessionTool)

      # Navigation
      server.register_tool(Tools::NavigateTool)

      # Element finding
      server.register_tool(Tools::FindElementTool)

      # Element interaction
      server.register_tool(Tools::ClickTool)
      server.register_tool(Tools::SendKeysTool)

      # Combined operations
      server.register_tool(Tools::FindAndClickTool)

      # JavaScript
      server.register_tool(Tools::ExecuteScriptTool)

      # Page information
      server.register_tool(Tools::GetConsoleLogsTool)

      # Screenshot management
      server.register_tool(Tools::SaveDesktopScreenshotTool)
      server.register_tool(Tools::SaveMobileScreenshotTool)
    end

    def register_resources(server)
      # No resources registered
    end
  end

  # Rack middleware for easy integration into Rails/Sinatra apps
  # Usage in Rails config/application.rb:
  #   config.middleware.use SeleniumWebdriverMcp::RackMiddleware
  #
  # Usage in Sinatra:
  #   use SeleniumWebdriverMcp::RackMiddleware
  class RackMiddleware
    def initialize(app, **options)
      server = Server.new(**options.slice(:name, :version))
      @mcp_app = server.rack_app(base_app: app, **options)
    end

    def call(env)
      @mcp_app.call(env)
    end
  end
end
