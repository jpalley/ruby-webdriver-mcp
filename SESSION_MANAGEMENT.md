# Session Management

## Overview

The selenium-webdriver-mcp gem implements **thread-safe session management** to support multiple concurrent AI clients (e.g., multiple Claude instances) connecting to the same MCP server. Each session maintains its own:

- Browser instance (separate WebDriver)
- Element cache (isolated element references)
- Browser state (independent navigation and interactions)

## How It Works

### Session Isolation

Each client must:
1. **Create a session** using the `create_session` tool
2. **Use the session_id** in all subsequent tool calls
3. **Destroy the session** when done to free resources

### Session Lifecycle

```
Client A                              Client B
   │                                     │
   ├─ create_session                     ├─ create_session
   │  └─ Returns: session_abc123         │  └─ Returns: session_xyz789
   │                                     │
   ├─ navigate(session_abc123, url)      ├─ navigate(session_xyz789, url)
   │  [Separate browser A]               │  [Separate browser B]
   │                                     │
   ├─ find_element(session_abc123, ...)  ├─ find_element(session_xyz789, ...)
   │  └─ element_0 (in session A cache)  │  └─ element_0 (in session B cache)
   │                                     │
   ├─ click(session_abc123, element_0)   ├─ click(session_xyz789, element_0)
   │  [Clicks in browser A]              │  [Clicks in browser B]
   │                                     │
   └─ destroy_session(session_abc123)    └─ destroy_session(session_xyz789)
      [Browser A closed]                    [Browser B closed]
```

## Session Management Tools

### create_session

Create a new browser session.

**Arguments:**
- `session_id` (string, optional): Custom session ID (auto-generated if not provided)

**Returns:**
```json
{
  "success": true,
  "session_id": "session_abc123def456",
  "message": "Session created successfully. Use this session_id in subsequent tool calls."
}
```

**Example:**
```json
{
  "tool": "create_session",
  "arguments": {}
}
```

### destroy_session

Destroy a session and close the browser.

**Arguments:**
- `session_id` (string, required): The session ID to destroy

**Returns:**
```json
{
  "success": true,
  "message": "Session session_abc123def456 destroyed successfully"
}
```

**Example:**
```json
{
  "tool": "destroy_session",
  "arguments": {
    "session_id": "session_abc123def456"
  }
}
```

### list_sessions

List all active sessions.

**Returns:**
```json
{
  "success": true,
  "session_count": 2,
  "sessions": [
    {
      "session_id": "session_abc123",
      "created_at": "2025-10-14T10:30:00Z",
      "last_accessed": "2025-10-14T10:35:00Z",
      "active": true
    },
    {
      "session_id": "session_xyz789",
      "created_at": "2025-10-14T10:32:00Z",
      "last_accessed": "2025-10-14T10:33:00Z",
      "active": true
    }
  ]
}
```

**Example:**
```json
{
  "tool": "list_sessions",
  "arguments": {}
}
```

## Usage Pattern

### Standard Workflow

```json
// 1. Create a session
{"tool": "create_session", "arguments": {}}
// Returns: {"session_id": "session_abc123", ...}

// 2. Use the session_id in all operations
{"tool": "navigate", "arguments": {"session_id": "session_abc123", "url": "https://example.com"}}

{"tool": "find_element", "arguments": {"session_id": "session_abc123", "strategy": "id", "value": "search"}}
// Returns: {"element_id": "element_0", ...}

{"tool": "send_keys", "arguments": {"session_id": "session_abc123", "element_id": "element_0", "text": "query"}}

{"tool": "take_screenshot", "arguments": {"session_id": "session_abc123"}}

// 3. Clean up when done
{"tool": "destroy_session", "arguments": {"session_id": "session_abc123"}}
```

## Thread Safety

The `SessionManager` uses a `Mutex` to ensure thread-safe operations:

- **Session creation/destruction**: Atomic operations
- **Session access**: Synchronized access to session data
- **Element caching**: Per-session element caches prevent cross-contamination

## Session Cleanup

### Automatic Cleanup

Sessions are automatically cleaned up after **1 hour of inactivity** (default). The cleanup process:

1. Checks `last_accessed` timestamp
2. Closes the browser if expired
3. Removes the session from the manager

### Manual Cleanup

Clients should always call `destroy_session` when done:

```json
{"tool": "destroy_session", "arguments": {"session_id": "session_abc123"}}
```

### Emergency Cleanup

Administrators can destroy all sessions programmatically:

```ruby
SeleniumWebdriverMcp::SessionManager.instance.destroy_all_sessions
```

## Concurrency Scenarios

### Multiple Clients, Same Site

```
Client A: session_1 → https://example.com
Client B: session_2 → https://example.com
✓ Both can interact independently
```

### Multiple Clients, Different Sites

```
Client A: session_1 → https://site-a.com
Client B: session_2 → https://site-b.com
✓ Completely isolated
```

### Element ID Conflicts

Element IDs are scoped to sessions:

```
Session 1: element_0 → <input id="search"> on site A
Session 2: element_0 → <button id="submit"> on site B
✓ No conflict - different sessions, different caches
```

## Error Handling

### Session Not Found

If you use an invalid session_id:

```json
{
  "error": "Session session_invalid not found"
}
```

### Session Already Exists

If you try to create a session with a duplicate ID:

```json
{
  "success": false,
  "error": "Session my_session already exists"
}
```

## Best Practices

1. **Always create a session first**
   ```
   create_session → get session_id → use in all calls
   ```

2. **Clean up sessions**
   ```
   Always call destroy_session when done
   ```

3. **Handle errors gracefully**
   ```
   Check for "Session not found" errors
   Re-create session if needed
   ```

4. **Use list_sessions for debugging**
   ```
   Check active sessions and their status
   ```

5. **Let session IDs be auto-generated**
   ```
   Don't specify custom session_id unless needed
   Auto-generated IDs prevent conflicts
   ```

## Performance Considerations

### Resource Usage

Each session consumes:
- 1 browser instance (Chrome/Firefox/Edge)
- Memory for element cache
- Network connections to Selenium

### Scalability

The gem can support:
- **10-20 concurrent sessions** on typical hardware
- Limited by Selenium grid capacity
- Selenium standalone-chrome typically supports 5 sessions by default

### Optimization

Configure Selenium for more sessions:

```yaml
# docker-compose.yml
selenium:
  image: selenium/standalone-chrome:latest
  environment:
    SE_NODE_MAX_SESSIONS: 20  # Increase session limit
    SE_NODE_SESSION_TIMEOUT: 300  # 5 minute timeout
  shm_size: 4gb  # Increase shared memory
```

## Monitoring

### Check Active Sessions

```json
{"tool": "list_sessions", "arguments": {}}
```

### Session Health

Monitor for:
- Stuck sessions (not accessed for long time)
- Too many active sessions
- Failed session cleanup

## Migration from Single-Client Pattern

### Old (Pre-Session) Code

```json
{"tool": "navigate", "arguments": {"url": "https://example.com"}}
```

### New (Session-Aware) Code

```json
{"tool": "create_session", "arguments": {}}
// Use returned session_id

{"tool": "navigate", "arguments": {"session_id": "session_abc123", "url": "https://example.com"}}
```

All tools now require `session_id` as the first argument.
