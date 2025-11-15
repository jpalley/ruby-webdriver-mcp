# frozen_string_literal: true

require "webrick"
require "fileutils"

module TestHtmlServer
  class << self
    attr_reader :server, :thread, :port

    def start(port: 9292)
      return if @server

      @port = port
      setup_test_files

      @server = WEBrick::HTTPServer.new(
        Port: port,
        BindAddress: "0.0.0.0", # Bind to all interfaces so Selenium container can access
        DocumentRoot: test_html_dir,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: []
      )

      @thread = Thread.new { @server.start }
      sleep 0.5 # Give server time to start
    end

    def stop
      return unless @server

      @server.shutdown
      @thread.join
      @server = nil
      @thread = nil
    end

    def url(path = "/")
      # Use 'app' hostname so Selenium container can access the test server
      # In docker-compose, services can reach each other via service name
      "http://app:#{port}#{path}"
    end

    def test_html_dir
      File.join(Dir.pwd, "spec", "fixtures", "html")
    end

    private

    def setup_test_files
      FileUtils.mkdir_p(test_html_dir)

      # Create test HTML files
      create_index_page
      create_simple_page
      create_form_page
      create_frame_page
      create_javascript_page
    end

    def create_index_page
      File.write(File.join(test_html_dir, "index.html"), <<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test Page</title>
        </head>
        <body>
          <h1 id="main-heading">Welcome to Test Page</h1>
          <p class="description">This is a test page for Selenium WebDriver MCP</p>
          <a href="/form.html" id="form-link">Go to Form</a>
          <button id="test-button" onclick="alert('Button clicked!')">Click Me</button>
          <div id="content">
            <span class="item">Item 1</span>
            <span class="item">Item 2</span>
            <span class="item">Item 3</span>
          </div>
        </body>
        </html>
      HTML
    end

    def create_simple_page
      File.write(File.join(test_html_dir, "simple.html"), <<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>Simple Test Page</title>
        </head>
        <body>
          <h1>Simple Page</h1>
          <p>This is a simple test page.</p>
        </body>
        </html>
      HTML
    end

    def create_form_page
      File.write(File.join(test_html_dir, "form.html"), <<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>Form Test Page</title>
        </head>
        <body>
          <h1>Test Form</h1>
          <form id="test-form" action="/submit" method="post">
            <label for="username">Username:</label>
            <input type="text" id="username" name="username" placeholder="Enter username">

            <label for="password">Password:</label>
            <input type="password" id="password" name="password">

            <label for="email">Email:</label>
            <input type="email" id="email" name="email">

            <label for="comments">Comments:</label>
            <textarea id="comments" name="comments"></textarea>

            <input type="checkbox" id="agree" name="agree" value="yes">
            <label for="agree">I agree to terms</label>

            <button type="submit" id="submit-btn">Submit</button>
          </form>
          <div id="result"></div>
        </body>
        </html>
      HTML
    end

    def create_frame_page
      File.write(File.join(test_html_dir, "frames.html"), <<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>Frame Test Page</title>
        </head>
        <body>
          <h1>Page with Frames</h1>
          <iframe id="test-frame" name="test-frame" srcdoc="<html><body><h2 id='frame-heading'>Inside Frame</h2><p id='frame-content'>Frame content here</p></body></html>"></iframe>
        </body>
        </html>
      HTML
    end

    def create_javascript_page
      File.write(File.join(test_html_dir, "javascript.html"), <<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>JavaScript Test Page</title>
          <script>
            console.log("Page loaded");
            console.warn("This is a warning");
            console.error("This is an error");

            function addNumbers(a, b) {
              return a + b;
            }

            function updateContent() {
              document.getElementById('dynamic-content').textContent = 'Updated!';
            }

            setTimeout(function() {
              console.log("Delayed log message");
            }, 100);
          </script>
        </head>
        <body>
          <h1>JavaScript Test Page</h1>
          <div id="dynamic-content">Original Content</div>
          <button id="update-btn" onclick="updateContent()">Update Content</button>
        </body>
        </html>
      HTML
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    TestHtmlServer.start
  end

  config.after(:suite) do
    TestHtmlServer.stop
  end
end
