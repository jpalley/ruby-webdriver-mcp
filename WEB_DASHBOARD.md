# Web Dashboard Feature

## Overview

A modern web-based dashboard for monitoring active browser sessions and viewing screenshot history. The dashboard is accessible via web browser (not MCP clients) and provides a visual interface for session management.

## Access

**Dashboard URL**: `http://localhost:4443/` (or whatever port your server runs on)

The dashboard is the default root page, replacing the previous 404 response.

## Features

### 1. Session List
- **Active sessions** displayed as expandable cards
- **Sorted by activity** - most recently active sessions first
- **Real-time updates** - auto-refreshes every 5 seconds
- **Session information**:
  - Session ID
  - Current URL
  - Page title
  - Last activity timestamp (e.g., "2 minutes ago")
  - Screenshot count

### 2. Screenshot History
- **Manual capture** - Click "Capture Screenshot" button to save
- **History limit** - Keeps last 10 screenshots per session
- **Grid view** - Screenshots displayed in responsive grid
- **Metadata** - Each screenshot shows:
  - Capture timestamp
  - URL when captured
  - Full-size preview (click to open in new tab)

### 3. UI Design
- **Modern interface** - Built with Tailwind CSS
- **Responsive** - Works on desktop, tablet, and mobile
- **Interactive** - Expand/collapse sessions
- **Auto-refresh** - Session list updates automatically

## Implementation

### New Components

**1. Screenshot History Manager** (`lib/selenium_webdriver_mcp/screenshot_history.rb`)
- Singleton class managing screenshot storage
- Stores screenshots: `public/screenshots/{session_id}/{timestamp}.png`
- Tracks metadata: timestamp, URL, filename
- Auto-limits to 10 screenshots per session
- Thread-safe with mutex locking

**2. Web UI Middleware** (`lib/selenium_webdriver_mcp/web_ui.rb`)
- Rack middleware serving dashboard and API
- Routes:
  - `GET /` - Dashboard HTML
  - `GET /api/sessions` - JSON list of sessions
  - `GET /api/sessions/{id}/screenshots` - JSON screenshot history
  - `POST /api/sessions/{id}/screenshot` - Capture screenshot

**3. Save Screenshot Tool** (`lib/selenium_webdriver_mcp/tools/save_screenshot_tool.rb`)
- MCP tool: `save_screenshot`
- Captures and saves screenshot to history
- Returns metadata about saved screenshot

**4. Updated Image Middleware** (`lib/selenium_webdriver_mcp/image_middleware.rb`)
- Now handles both current and historical screenshots:
  - `GET /screenshots/{session_id}` - Current screenshot
  - `GET /screenshots/{session_id}/{timestamp}.png` - Historical screenshot

### API Endpoints

| Endpoint | Method | Purpose | Returns |
|----------|--------|---------|---------|
| `/` | GET | Web dashboard | HTML page |
| `/api/sessions` | GET | List all sessions | JSON array |
| `/api/sessions/{id}/screenshots` | GET | Screenshot history | JSON array |
| `/api/sessions/{id}/screenshot` | POST | Capture screenshot | JSON result |
| `/screenshots/{id}` | GET | Current screenshot | PNG image |
| `/screenshots/{id}/{ts}.png` | GET | Historical screenshot | PNG image |

### API Response Examples

**GET /api/sessions:**
```json
[
  {
    "session_id": "session_123",
    "created_at": 1697234567,
    "last_accessed": 1697234890,
    "current_url": "https://example.com",
    "page_title": "Example Domain",
    "screenshot_count": 5
  }
]
```

**GET /api/sessions/{id}/screenshots:**
```json
[
  {
    "timestamp": 1697234890,
    "url": "https://example.com",
    "filename": "1697234890.png",
    "path": "/screenshots/session_123/1697234890.png"
  }
]
```

**POST /api/sessions/{id}/screenshot:**
```json
{
  "success": true,
  "screenshot": {
    "timestamp": 1697234890,
    "url": "https://example.com",
    "path": "/screenshots/session_123/1697234890.png"
  }
}
```

## MCP Tool Integration

### save_screenshot Tool

**Description**: Capture a screenshot and save it to the session's screenshot history

**Arguments**:
- `session_id` (string, required): The browser session ID

**Returns**:
```ruby
{
  saved: true,
  timestamp: 1697234890,
  url: "https://example.com",
  path: "/screenshots/session_123/1697234890.png",
  total_screenshots: 5
}
```

**Example Usage via MCP**:
```json
{
  "tool": "save_screenshot",
  "arguments": {
    "session_id": "session_123"
  }
}
```

## Usage Examples

### Via Web Browser

1. **Open dashboard**: Navigate to `http://localhost:4443/`
2. **View sessions**: See all active browser sessions
3. **Expand session**: Click the ▶ icon to view screenshot history
4. **Capture screenshot**: Click "Capture Screenshot" button
5. **View screenshot**: Click any screenshot to open in new tab

### Via MCP Tool

```json
{
  "method": "tools/call",
  "params": {
    "name": "save_screenshot",
    "arguments": {
      "session_id": "session_abc123"
    }
  }
}
```

### Via API (cURL)

```bash
# List sessions
curl http://localhost:4443/api/sessions

# View screenshot history
curl http://localhost:4443/api/sessions/session_123/screenshots

# Capture new screenshot
curl -X POST http://localhost:4443/api/sessions/session_123/screenshot

# Download historical screenshot
curl http://localhost:4443/screenshots/session_123/1697234890.png > screenshot.png
```

## File Storage

Screenshots are stored in: `public/screenshots/{session_id}/{timestamp}.png`

**Example structure**:
```
public/screenshots/
├── session_123/
│   ├── 1697234567.png
│   ├── 1697234890.png
│   └── 1697235000.png
└── session_456/
    └── 1697235123.png
```

**Cleanup**:
- Old screenshots are automatically deleted when exceeding 10 per session
- All screenshots for a session are deleted when the session is destroyed
- Screenshots directory is in `.gitignore`

## Configuration

No configuration needed - works out of the box.

**Default settings**:
- Max screenshots per session: 10
- Storage directory: `public/screenshots`
- Auto-refresh interval: 5 seconds
- Cache control:
  - Current screenshots: `no-cache`
  - Historical screenshots: `public, max-age=31536000` (immutable)

## Browser Compatibility

The dashboard uses:
- **Tailwind CSS** (via CDN) - Modern CSS framework
- **Vanilla JavaScript** - No framework dependencies
- **Fetch API** - Modern browsers only (IE not supported)

**Supported browsers**:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

## Development

### Adding Custom UI Elements

The dashboard HTML is embedded in `lib/selenium_webdriver_mcp/web_ui.rb`. To customize:

1. Edit the `dashboard_html` method
2. Modify the HTML structure
3. Add custom Tailwind CSS classes
4. Update JavaScript functions as needed

### Extending API

To add new API endpoints:

1. Add route handling in `WebUI#call` method
2. Create corresponding private method
3. Return JSON response using `json_response` helper

## Security Considerations

**Important**: The dashboard has no authentication.

**For production use**:
1. **Use a reverse proxy** (nginx, Traefik) with authentication
2. **Restrict access** by IP or network
3. **Enable HTTPS** for encrypted communication
4. **Set up proper CORS** policies if needed

The current implementation is designed for:
- Local development
- Trusted internal networks
- Behind authenticated reverse proxy

## Performance

**Auto-refresh impact**:
- Dashboard polls `/api/sessions` every 5 seconds
- Minimal data transfer (~1KB per poll for typical usage)
- Screenshots loaded on-demand (only when session expanded)

**Storage considerations**:
- Each screenshot: ~50-500KB (typical PNG size)
- 10 screenshots per session max
- Multiple sessions: ~5-50MB total (10 sessions × 10 screenshots)

## Troubleshooting

**Dashboard shows "No active sessions"**:
- Create a session using the `create_session` tool
- Refresh the page

**"Capture Screenshot" doesn't work**:
- Ensure session ID is valid
- Check browser console for JavaScript errors
- Verify Selenium is running and session is active

**Screenshots not displaying**:
- Check `public/screenshots/` directory exists
- Verify file permissions
- Check browser console for 404 errors

**Dashboard not loading**:
- Verify server is running on correct port
- Check for port conflicts
- Review server logs for errors

## Future Enhancements

Possible improvements:
- Session filtering/search
- Screenshot comparison
- Download all screenshots as ZIP
- Delete individual screenshots
- Session activity timeline
- Real-time updates via WebSockets/SSE
- Screenshot annotations
- Multiple screenshot selection
- Bulk operations

## Tool Count

After adding the web dashboard feature:
- **Tools**: 15 (added `save_screenshot`)
- **Resources**: 4 (no change)
- **Endpoints**: 10 total (MCP + API + images + health)
