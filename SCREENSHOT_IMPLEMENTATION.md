# Screenshot Implementation

## Overview

Screenshots are now accessed via **MCP Resources** and **Direct HTTP endpoints** instead of through an MCP tool. This provides more flexible and protocol-compliant ways to access binary image data.

## Changes Made

### 1. New Screenshot Access Methods

**MCP Resource (Protocol-Compliant)**
- **File**: `lib/selenium_webdriver_mcp/resources/screenshot_resource.rb`
- **URI**: `screenshot://{session_id}`
- **Format**: Returns base64-encoded PNG in a `blob` field with `mimeType: "image/png"`
- **Usage**:
  ```json
  {
    "method": "resources/read",
    "params": {"uri": "screenshot://session_abc123"}
  }
  ```

**HTTP Endpoint (Direct Access)**
- **File**: `lib/selenium_webdriver_mcp/image_middleware.rb`
- **Endpoint**: `GET /screenshots/{session_id}`
- **Format**: Returns raw PNG binary with `Content-Type: image/png` header
- **Usage**:
  ```bash
  curl http://localhost:4443/screenshots/session_abc123 > screenshot.png
  ```

### 2. Removed Components

- ❌ `lib/selenium_webdriver_mcp/tools/take_screenshot_tool.rb` (deleted)
- ❌ `DriverManager#take_screenshot` method (removed from `driver_manager.rb:127-130`)
- ❌ Tool registration in `server.rb` (removed)

### 3. Updated Components

**Server Configuration** (`lib/selenium_webdriver_mcp/server.rb`):
- Added `require_relative "resources/screenshot_resource"`
- Added `require_relative "image_middleware"`
- Registered `ScreenshotResource` in `register_resources`
- Integrated `ImageMiddleware` into `rack_app` method

**Tests**:
- Removed driver-level screenshot tests from `spec/integration_driver_only/page_information_spec.rb`
- Converted tool test to resource test in `spec/mcp_integration/javascript_tools_spec.rb`
- Updated tool count in `spec/mcp_integration/tools_list_spec.rb` (15 → 14 tools)
- Added HTTP endpoint test in `spec/http_integration/screenshot_endpoint_spec.rb`

**Documentation**:
- Updated `README.md` with new screenshot access methods
- Updated architecture diagram to show `/screenshots/{id}` endpoint
- Updated `config.ru` comments

## Benefits of New Approach

### 1. Protocol Compliance
- MCP Resources are the official way to handle binary data in the MCP protocol
- Binary data is automatically base64-encoded by FastMCP with proper MIME types

### 2. Flexibility
- **For MCP Clients**: Use the resource protocol with automatic base64 encoding
- **For Direct Access**: Use HTTP endpoint for raw PNG data (browser-viewable)

### 3. Better User Experience
- Screenshots can be viewed directly in a browser: `http://localhost:4443/screenshots/session_id`
- No need to decode base64 for simple viewing
- Still available via MCP protocol for programmatic access

### 4. Clean Separation of Concerns
- **Tools**: Actions that modify state or perform operations
- **Resources**: Read-only data access (URLs, titles, screenshots)

## Usage Examples

### Via MCP Resource Protocol

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "resources/read",
  "params": {
    "uri": "screenshot://session_abc123"
  }
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "contents": [
      {
        "uri": "screenshot://session_abc123",
        "mimeType": "image/png",
        "blob": "iVBORw0KGgoAAAANSUhEUgAA..."
      }
    ]
  }
}
```

### Via Direct HTTP

```bash
# View in browser
open http://localhost:4443/screenshots/session_abc123

# Save to file
curl http://localhost:4443/screenshots/session_abc123 > screenshot.png

# Use with wget
wget http://localhost:4443/screenshots/session_abc123 -O screenshot.png
```

## Technical Details

### ScreenshotResource

```ruby
class ScreenshotResource < FastMcp::Resource
  resource_name "screenshot"
  description "Screenshot of the current browser window for a session"
  mime_type "image/png"
  uri "screenshot://{session_id}"

  def content
    session_id = params[:session_id]
    driver_manager = SessionManager.instance.get_driver_manager(session_id)

    # Get base64 from Selenium and decode to binary PNG
    screenshot_base64 = driver_manager.ensure_started.screenshot_as(:base64)
    Base64.decode64(screenshot_base64)
  end
end
```

**How FastMCP Handles It**:
1. When `mime_type` is `"image/png"`, the `binary?` method returns `true`
2. FastMCP automatically calls `Base64.strict_encode64(content)` on the binary data
3. Returns as `{ blob: "base64-encoded-data", mimeType: "image/png" }`

### ImageMiddleware

```ruby
class ImageMiddleware
  def call(env)
    if env["PATH_INFO"] =~ %r{^/screenshots/([^/]+)$}
      session_id = $1
      serve_screenshot(session_id)
    else
      @app.call(env)
    end
  end

  private

  def serve_screenshot(session_id)
    driver_manager = SessionManager.instance.get_driver_manager(session_id)
    screenshot_base64 = driver_manager.ensure_started.screenshot_as(:base64)
    png_data = Base64.decode64(screenshot_base64)

    [200,
     { "content-type" => "image/png",
       "content-length" => png_data.bytesize.to_s,
       "cache-control" => "no-cache" },
     [png_data]]
  end
end
```

## Migration Guide

### Before (Tool-based)

```json
{
  "method": "tools/call",
  "params": {
    "name": "take_screenshot",
    "arguments": {
      "session_id": "session_abc123"
    }
  }
}
```

**Response**:
```json
{
  "result": {
    "content": [
      {
        "text": "{:screenshot=>\"iVBORw0KGg...\", :format=>\"base64\"}"
      }
    ]
  }
}
```

### After (Resource-based)

```json
{
  "method": "resources/read",
  "params": {
    "uri": "screenshot://session_abc123"
  }
}
```

**Response**:
```json
{
  "result": {
    "contents": [
      {
        "uri": "screenshot://session_abc123",
        "mimeType": "image/png",
        "blob": "iVBORw0KGg..."
      }
    ]
  }
}
```

### Or Use HTTP Directly

```bash
curl http://localhost:4443/screenshots/session_abc123 > screenshot.png
```

## Tool Count

- **Before**: 15 tools (including `take_screenshot`)
- **After**: 14 tools (screenshot removed)
- **Resources**: 4 resources (including new `screenshot://{session_id}`)

## File Structure

```
lib/selenium_webdriver_mcp/
├── resources/
│   ├── browser_state.rb          # Existing resources
│   └── screenshot_resource.rb    # NEW: Screenshot resource
├── tools/
│   ├── ...                       # 14 tools
│   └── take_screenshot_tool.rb  # REMOVED
├── driver_manager.rb             # Removed take_screenshot method
├── image_middleware.rb           # NEW: HTTP endpoint
└── server.rb                     # Updated to register resource & middleware
```

## Testing

The implementation includes comprehensive tests:

- **Unit Tests**: All existing unit tests still pass (28 examples)
- **Resource Test**: `spec/mcp_integration/javascript_tools_spec.rb` tests MCP resource access
- **HTTP Test**: `spec/http_integration/screenshot_endpoint_spec.rb` tests direct HTTP access
- **Tool List Test**: Updated to expect 14 tools instead of 15

## Endpoints Summary

| Endpoint | Method | Purpose | Returns |
|----------|--------|---------|---------|
| `/mcp` | POST | JSON-RPC tools & resources | JSON |
| `/sse` | GET | Server-Sent Events | Event stream |
| `/screenshots/{id}` | GET | PNG screenshots | Binary PNG |
| `/health` | GET | Health check | JSON status |
