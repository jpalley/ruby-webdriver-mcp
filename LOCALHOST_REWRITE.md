# Localhost URL Rewriting Feature

## Overview

The `REWRITE_LOCALHOST_TO` environment variable enables automatic rewriting of `localhost` and `127.0.0.1` URLs to a different hostname. This is essential for containerized environments where "localhost" from the browser's perspective differs from the host machine.

## Use Case

In Docker/containerized environments:
- Browser runs in a container (e.g., Selenium Grid)
- Application runs in a different container (e.g., `app` container)
- `http://localhost:3000` from the browser won't reach the app container
- Need to navigate to `http://app:3000` instead

## Configuration

### Environment Variable

```bash
export REWRITE_LOCALHOST_TO=app
```

Or in docker-compose:

```yaml
services:
  selenium-mcp:
    environment:
      - REWRITE_LOCALHOST_TO=app
```

### Programmatic Configuration

```ruby
SeleniumWebdriverMcp.configure do |config|
  config.rewrite_localhost_to = "app"
end
```

## Behavior

When `REWRITE_LOCALHOST_TO` is set, the navigate tool automatically rewrites URLs:

### Rewrites Applied

| Original URL | Rewritten URL (if REWRITE_LOCALHOST_TO=app) |
|--------------|---------------------------------------------|
| `http://localhost:3000/path` | `http://app:3000/path` |
| `http://localhost/path` | `http://app/path` |
| `http://127.0.0.1:8080/api` | `http://app:8080/api` |
| `http://127.0.0.1/api` | `http://app/api` |
| `https://localhost:443/secure` | `https://app:443/secure` |

### No Rewrites

| URL | Reason |
|-----|--------|
| `http://example.com:3000/path` | Not localhost/127.0.0.1 |
| `http://example.com/localhost/path` | localhost in path, not host |

### When Not Set

If `REWRITE_LOCALHOST_TO` is not set or empty, URLs pass through unchanged:

```ruby
# REWRITE_LOCALHOST_TO not set
"http://localhost:3000/path" → "http://localhost:3000/path"  # unchanged
```

## Examples

### Docker Compose Setup

```yaml
version: '3.8'

services:
  app:
    image: my-app:latest
    ports:
      - "3000:3000"

  selenium:
    image: selenium/standalone-chrome:latest
    ports:
      - "4444:4444"

  selenium-mcp:
    build: .
    environment:
      - SELENIUM_URL=http://selenium:4444/wd/hub
      - REWRITE_LOCALHOST_TO=app  # Rewrite localhost → app
    ports:
      - "4443:4443"
    depends_on:
      - selenium
      - app
```

### Usage with MCP

```javascript
// Create session
const session = await mcp.callTool("create_session", {});

// Navigate using localhost - automatically rewritten to app
await mcp.callTool("navigate", {
  session_id: session.session_id,
  url: "http://localhost:3000/dashboard"
});
// Browser actually navigates to: http://app:3000/dashboard

// Also works with 127.0.0.1
await mcp.callTool("navigate", {
  session_id: session.session_id,
  url: "http://127.0.0.1:3000/api"
});
// Browser actually navigates to: http://app:3000/api
```

### Devcontainer Setup

In `.devcontainer/devcontainer.json`:

```json
{
  "name": "Selenium MCP",
  "dockerComposeFile": "docker-compose.yml",
  "service": "workspace",
  "containerEnv": {
    "REWRITE_LOCALHOST_TO": "app"
  }
}
```

## Implementation Details

### Location

- **Configuration**: `lib/selenium_webdriver_mcp/configuration.rb`
- **Rewrite Logic**: `lib/selenium_webdriver_mcp/tools/navigate_tool.rb`
- **Tests**: `spec/unit/navigate_tool_spec.rb`

### Rewrite Method

```ruby
def rewrite_localhost(url)
  rewrite_target = SeleniumWebdriverMcp.configuration.rewrite_localhost_to
  return url if rewrite_target.nil? || rewrite_target.empty?

  url.gsub(%r{//localhost(:|/)}, "//#{rewrite_target}\\1")
     .gsub(%r{//127\.0\.0\.1(:|/)}, "//#{rewrite_target}\\1")
end
```

### Pattern Matching

Uses regex to match:
- `//localhost:` - localhost with port
- `//localhost/` - localhost without port
- `//127.0.0.1:` - 127.0.0.1 with port
- `//127.0.0.1/` - 127.0.0.1 without port

Preserves:
- Protocol (http/https)
- Port numbers
- Paths and query strings
- Fragments

## Testing

### Unit Tests

Run unit tests:
```bash
bundle exec rspec spec/unit/navigate_tool_spec.rb
```

**Test Coverage:**
- ✅ No rewrite when not configured
- ✅ Rewrite localhost with port
- ✅ Rewrite localhost without port
- ✅ Rewrite 127.0.0.1 with port
- ✅ Rewrite 127.0.0.1 without port
- ✅ HTTPS URLs
- ✅ Non-localhost URLs unchanged
- ✅ localhost in path unchanged
- ✅ Empty string configuration
- ✅ Custom hosts with special characters

**Results**: 12/12 tests passing ✅

### Integration Testing

Test with real environment:

```bash
# Set environment variable
export REWRITE_LOCALHOST_TO=app

# Start services
docker-compose up

# Test navigation
# URLs with localhost will be rewritten to app
```

## Common Patterns

### Pattern 1: Docker Compose with Named Services

```yaml
services:
  app:
    # Application container
  selenium-mcp:
    environment:
      - REWRITE_LOCALHOST_TO=app
```

Navigate to `http://localhost:3000` → Browser goes to `http://app:3000`

### Pattern 2: Kubernetes with Service Names

```yaml
env:
  - name: REWRITE_LOCALHOST_TO
    value: "my-app-service.namespace.svc.cluster.local"
```

Navigate to `http://localhost:8080` → Browser goes to `http://my-app-service.namespace.svc.cluster.local:8080`

### Pattern 3: Development with Docker Bridge Network

```yaml
environment:
  - REWRITE_LOCALHOST_TO=host.docker.internal
```

Navigate to `http://localhost:5000` → Browser goes to `http://host.docker.internal:5000`

## Troubleshooting

### Issue: URLs still showing localhost

**Check:**
1. Is `REWRITE_LOCALHOST_TO` set? `echo $REWRITE_LOCALHOST_TO`
2. Is the service restarted after setting the variable?
3. Check logs for the rewritten URL

### Issue: Connection refused

**Check:**
1. Is the target host (`app`) accessible from the browser container?
2. Can you ping the target? `docker exec selenium-mcp ping app`
3. Are network/firewall rules blocking access?

### Issue: DNS resolution failed

**Check:**
1. Is the hostname defined in docker-compose or network?
2. Try IP address instead: `REWRITE_LOCALHOST_TO=172.17.0.2`

## Security Considerations

- URL rewriting happens before navigation
- Only affects `localhost` and `127.0.0.1` hosts
- Other domains pass through unchanged
- Rewrite target should be a trusted internal hostname
- Review logs to verify correct URL transformations

## Limitations

- Only rewrites in the `navigate` tool
- Does not rewrite:
  - JavaScript redirects
  - Form actions
  - AJAX requests made by the page
  - iframes
- For full localhost mapping, configure at the network level

## Future Enhancements

Potential improvements:
- Rewrite in more contexts (execute_script, etc.)
- Pattern-based rewrites (not just localhost)
- Multiple rewrite rules
- URL validation before rewriting
