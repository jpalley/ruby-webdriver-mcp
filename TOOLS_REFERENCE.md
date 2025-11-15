# MCP Tools Reference

Quick reference for all available MCP tools in selenium-webdriver-mcp.

## Navigation

### navigate
Navigate the browser to a URL.

**Arguments:**
- `url` (string, required): The URL to navigate to

**Example:**
```json
{"tool": "navigate", "arguments": {"url": "https://example.com"}}
```

## Element Finding

### find_element
Find an element on the page.

**Arguments:**
- `strategy` (string, required): Locator strategy (id, name, class, css, xpath, link_text, tag_name)
- `value` (string, required): The value to search for using the strategy

**Returns:**
```json
{
  "element_id": "element_0",
  "tag_name": "input",
  "text": "...",
  "displayed": true,
  "enabled": true
}
```

**Example:**
```json
{"tool": "find_element", "arguments": {"strategy": "id", "value": "search"}}
```

### wait_for_element
Wait for an element to appear on the page.

**Arguments:**
- `strategy` (string, required): Locator strategy
- `value` (string, required): The value to search for
- `timeout` (integer, optional): Maximum time to wait in seconds (default: 10)

**Example:**
```json
{"tool": "wait_for_element", "arguments": {"strategy": "css", "value": ".loading", "timeout": 15}}
```

## Element Interaction

### click_element
Click on an element.

**Arguments:**
- `element_id` (string, required): Element ID returned from find_element

**Example:**
```json
{"tool": "click_element", "arguments": {"element_id": "element_0"}}
```

### send_keys
Send keystrokes to an element (type text).

**Arguments:**
- `element_id` (string, required): Element ID returned from find_element
- `text` (string, required): The text to type into the element

**Example:**
```json
{"tool": "send_keys", "arguments": {"element_id": "element_0", "text": "hello world"}}
```

## Element Information

### get_text
Get the text content of an element.

**Arguments:**
- `element_id` (string, required): Element ID returned from find_element

**Returns:**
```json
{"text": "Hello World"}
```

**Example:**
```json
{"tool": "get_text", "arguments": {"element_id": "element_0"}}
```

### get_attribute
Get an attribute value from an element.

**Arguments:**
- `element_id` (string, required): Element ID returned from find_element
- `attribute_name` (string, required): Name of the attribute to retrieve

**Returns:**
```json
{"value": "attribute value"}
```

**Example:**
```json
{"tool": "get_attribute", "arguments": {"element_id": "element_0", "attribute_name": "href"}}
```

## JavaScript Execution

### execute_script
Execute JavaScript in the browser context.

**Arguments:**
- `script` (string, required): The JavaScript code to execute

**Returns:**
```json
{"result": "value returned from JS"}
```

**Example:**
```json
{"tool": "execute_script", "arguments": {"script": "return document.title"}}
```

## Page Information

### take_screenshot
Take a screenshot of the current browser window.

**Returns:**
```json
{
  "screenshot": "base64_encoded_image_data",
  "format": "base64"
}
```

**Example:**
```json
{"tool": "take_screenshot", "arguments": {}}
```

### get_page_source
Get the HTML source of the current page.

**Returns:**
```json
{"source": "<html>...</html>"}
```

**Example:**
```json
{"tool": "get_page_source", "arguments": {}}
```

### get_console_logs
Get browser console logs (Chrome/JS console output).

**Returns:**
```json
{
  "logs": [
    {
      "level": "INFO",
      "message": "Console message",
      "timestamp": 1634567890
    }
  ]
}
```

**Example:**
```json
{"tool": "get_console_logs", "arguments": {}}
```

## Frame Switching

### switch_frame
Switch to a frame or iframe.

**Arguments:**
- `frame_reference`: Frame index (integer), frame name (string), element_id, 'default', or 'parent'

**Examples:**
```json
# Switch to frame by index
{"tool": "switch_frame", "arguments": {"frame_reference": 0}}

# Switch to frame by name
{"tool": "switch_frame", "arguments": {"frame_reference": "myframe"}}

# Switch back to default content
{"tool": "switch_frame", "arguments": {"frame_reference": "default"}}

# Switch to parent frame
{"tool": "switch_frame", "arguments": {"frame_reference": "parent"}}
```

## MCP Resources

### current_url
Get the current URL of the browser.

**Type:** text/plain

### page_title
Get the title of the current page.

**Type:** text/plain

### session_status
Get WebDriver session status and information.

**Type:** application/json

**Returns:**
```json
{
  "session_id": "...",
  "capabilities": {...},
  "current_url": "...",
  "title": "..."
}
```

## Common Workflows

### Fill out and submit a form

1. Navigate to page: `navigate`
2. Find input field: `find_element` with strategy "name" or "id"
3. Type text: `send_keys`
4. Find submit button: `find_element` with strategy "css" or "xpath"
5. Click button: `click_element`

### Wait for dynamic content

1. Navigate to page: `navigate`
2. Wait for element: `wait_for_element` with appropriate timeout
3. Interact with element: `click_element`, `get_text`, etc.

### Debug JavaScript issues

1. Navigate to page: `navigate`
2. Get console logs: `get_console_logs`
3. Execute debugging script: `execute_script`
4. Take screenshot: `take_screenshot`

### Work with iframes

1. Find iframe element: `find_element`
2. Switch to iframe: `switch_frame` with element_id
3. Interact with content inside iframe
4. Switch back: `switch_frame` with "default"
