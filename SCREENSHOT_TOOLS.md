# Screenshot Tools Enhancement

## Summary

Added two new MCP tools for capturing screenshots at standard desktop and mobile resolutions:
- `save_desktop_screenshot` - Captures at 1920x1080 (Full HD desktop)
- `save_mobile_screenshot` - Captures at 375x667 (iPhone SE / iPhone 8)

## Features

### SaveDesktopScreenshot
- **Resolution**: 1920x1080 (Full HD)
- **Use Case**: Captures how the page appears on standard desktop monitors
- **Behavior**:
  - Temporarily resizes browser window to 1920x1080
  - Captures screenshot
  - Restores original window size
- **Returns**: Embedded image with metadata

### SaveMobileScreenshot
- **Resolution**: 375x667 (iPhone SE size)
- **Use Case**: Captures how the page appears on mobile devices
- **Behavior**:
  - Temporarily resizes browser window to 375x667
  - Captures screenshot
  - Restores original window size
- **Returns**: Embedded image with metadata

## Implementation

### New Methods in DriverManager

1. **get_window_size**: Returns current window dimensions
```ruby
def get_window_size
  size = ensure_started.manage.window.size
  { width: size.width, height: size.height }
end
```

2. **set_window_size**: Sets window to specific dimensions
```ruby
def set_window_size(width, height)
  ensure_started.manage.window.resize_to(width, height)
  { width: width, height: height }
end
```

3. **screenshot_at_size**: Captures screenshot at specific resolution
```ruby
def screenshot_at_size(width, height)
  original_size = ensure_started.manage.window.size

  begin
    ensure_started.manage.window.resize_to(width, height)
    sleep 0.5  # Wait for resize to complete
    screenshot_base64 = ensure_started.screenshot_as(:base64)

    { screenshot: screenshot_base64, width: width, height: height }
  ensure
    # Always restore original size
    ensure_started.manage.window.resize_to(original_size.width, original_size.height)
  end
end
```

### New Tool Files

1. **lib/selenium_webdriver_mcp/tools/save_desktop_screenshot_tool.rb**
   - Desktop resolution: 1920x1080
   - Tool name: `save_desktop_screenshot`

2. **lib/selenium_webdriver_mcp/tools/save_mobile_screenshot_tool.rb**
   - Mobile resolution: 375x667
   - Tool name: `save_mobile_screenshot`

### Server Registration

Updated `lib/selenium_webdriver_mcp/server.rb`:
- Added requires for new tool files
- Registered both tools in `register_tools` method
- Updated tool count to 17

## Testing

### Unit Tests (`spec/integration_driver_only/screenshot_resolutions_spec.rb`)

Tests the DriverManager methods directly:
- ✅ Desktop screenshot capture (1920x1080)
- ✅ Mobile screenshot capture (375x667)
- ✅ Window size restoration after screenshot
- ✅ Get/set window size
- ✅ Multiple sequential screenshots

**Results**: 7/7 tests passing

### MCP Integration Tests (`spec/mcp_integration/screenshot_tools_spec.rb`)

Tests the tools through the MCP interface:
- ✅ save_screenshot tool (original)
- ✅ save_desktop_screenshot tool with metadata
- ✅ save_mobile_screenshot tool with metadata
- ✅ Window size restoration verification
- ✅ Sequential desktop and mobile screenshots

**Results**: 6/6 tests passing

## Usage Examples

### Using MCP Tools

```javascript
// Create a session
const session = await mcp.callTool("create_session", {});

// Navigate to a page
await mcp.callTool("navigate", {
  session_id: session.session_id,
  url: "https://example.com"
});

// Capture desktop screenshot
const desktopScreenshot = await mcp.callTool("save_desktop_screenshot", {
  session_id: session.session_id
});
// Returns: { content: [{ type: "image", data: "base64...", mimeType: "image/png" }],
//            metadata: { resolution: "desktop", width: 1920, height: 1080, url: "..." } }

// Capture mobile screenshot
const mobileScreenshot = await mcp.callTool("save_mobile_screenshot", {
  session_id: session.session_id
});
// Returns: { content: [{ type: "image", data: "base64...", mimeType: "image/png" }],
//            metadata: { resolution: "mobile", width: 375, height: 667, url: "..." } }
```

### Direct DriverManager Usage

```ruby
driver_manager = SessionManager.instance.get_driver_manager(session_id)

# Get current window size
size = driver_manager.get_window_size
# => { width: 1400, height: 1400 }

# Set window size
driver_manager.set_window_size(1024, 768)

# Capture screenshot at specific size
result = driver_manager.screenshot_at_size(1920, 1080)
# => { screenshot: "base64_encoded_png", width: 1920, height: 1080 }
```

## Benefits

1. **Responsive Testing**: Easily test how pages appear on different devices
2. **Automatic Restoration**: Original window size is always restored
3. **Standard Resolutions**: Uses industry-standard sizes (Full HD desktop, iPhone SE)
4. **Metadata Included**: Returns resolution info with each screenshot
5. **Thread-Safe**: Uses existing thread-safe DriverManager infrastructure

## Files Modified/Created

### Created
- `lib/selenium_webdriver_mcp/tools/save_desktop_screenshot_tool.rb`
- `lib/selenium_webdriver_mcp/tools/save_mobile_screenshot_tool.rb`
- `spec/integration_driver_only/screenshot_resolutions_spec.rb`
- `spec/mcp_integration/screenshot_tools_spec.rb`
- `SCREENSHOT_TOOLS.md` (this file)

### Modified
- `lib/selenium_webdriver_mcp/driver_manager.rb` - Added window management methods
- `lib/selenium_webdriver_mcp/server.rb` - Registered new tools

## Resolution Choices

### Desktop: 1920x1080
- Most common desktop resolution (Full HD)
- Standard for responsive design testing
- Widely used for web development

### Mobile: 375x667
- iPhone SE / iPhone 8 size
- Standard mobile viewport for testing
- Represents smaller smartphone screens

## Future Enhancements

Potential additions:
- Tablet resolution tool (768x1024 for iPad)
- Custom resolution tool (user-specified dimensions)
- Multiple screenshots in one call (desktop + mobile + tablet)
- Screenshot comparison tool
