# Localhost URL Rewriting - Implementation Summary

## Feature Overview

Added `REWRITE_LOCALHOST_TO` environment variable to automatically rewrite localhost/127.0.0.1 URLs to a different hostname in the navigate tool. This solves the containerization problem where browsers and applications run in separate containers.

## Problem Solved

In Docker/Kubernetes environments:
- Browser (Selenium) runs in one container
- Application runs in a different container (e.g., `app`)
- Navigating to `http://localhost:3000` from the browser fails
- Need to navigate to `http://app:3000` instead

## Implementation

### Files Created
- `lib/selenium_webdriver_mcp/tools/navigate_tool.rb` - Added `rewrite_localhost` method
- `spec/unit/navigate_tool_spec.rb` - 12 comprehensive tests
- `LOCALHOST_REWRITE.md` - Complete documentation

### Files Modified
- `lib/selenium_webdriver_mcp/configuration.rb` - Added `rewrite_localhost_to` attribute
- `CLAUDE.md` - Added section about localhost URL rewriting

## Configuration

### Environment Variable
```bash
export REWRITE_LOCALHOST_TO=app
```

### Docker Compose
```yaml
environment:
  - REWRITE_LOCALHOST_TO=app
```

### Programmatic
```ruby
SeleniumWebdriverMcp.configure do |config|
  config.rewrite_localhost_to = "app"
end
```

## Usage

When configured:
```ruby
# User calls navigate with localhost
navigate(session_id: "...", url: "http://localhost:3000/dashboard")

# URL automatically rewritten to
# "http://app:3000/dashboard"
```

## Rewrites Applied

| Original | Rewritten (REWRITE_LOCALHOST_TO=app) |
|----------|--------------------------------------|
| `http://localhost:3000/path` | `http://app:3000/path` |
| `http://localhost/path` | `http://app/path` |
| `http://127.0.0.1:8080/api` | `http://app:8080/api` |
| `https://localhost:443/secure` | `https://app:443/secure` |

## Testing

### Unit Tests (`spec/unit/navigate_tool_spec.rb`)

**12 Tests - All Passing ✅**

Coverage:
- ✅ No rewrite when not configured
- ✅ Rewrite localhost with/without port
- ✅ Rewrite 127.0.0.1 with/without port
- ✅ HTTPS URLs
- ✅ Preserve non-localhost URLs
- ✅ Don't rewrite localhost in paths
- ✅ Handle edge cases (empty config, special chars)

```bash
bundle exec rspec spec/unit/navigate_tool_spec.rb
# 12 examples, 0 failures
```

### All Unit Tests

**57 Tests - All Passing ✅**

```bash
bundle exec rspec spec/unit/
# 57 examples, 0 failures
```

## Implementation Details

### Rewrite Logic

```ruby
def rewrite_localhost(url)
  rewrite_target = SeleniumWebdriverMcp.configuration.rewrite_localhost_to
  return url if rewrite_target.nil? || rewrite_target.empty?

  url.gsub(%r{//localhost(:|/)}, "//#{rewrite_target}\\1")
     .gsub(%r{//127\.0\.0\.1(:|/)}, "//#{rewrite_target}\\1")
end
```

### Pattern Matching
- Matches `//localhost:` and `//localhost/`
- Matches `//127.0.0.1:` and `//127.0.0.1/`
- Preserves protocol, port, path, query, fragment

### Thread Safety
- Configuration is read-only during request processing
- No shared mutable state
- Works with existing thread-safe infrastructure

## Benefits

✅ **Zero Code Changes Required** - Set environment variable only
✅ **Transparent** - Users don't need to know about container networking
✅ **Flexible** - Works with any hostname (app, service name, FQDN)
✅ **Safe** - Only rewrites localhost/127.0.0.1, other URLs unchanged
✅ **Well-Tested** - Comprehensive unit test coverage
✅ **Documented** - Complete documentation in LOCALHOST_REWRITE.md

## Use Cases

### 1. Docker Compose Development
```yaml
services:
  app:
    ports: ["3000:3000"]
  selenium-mcp:
    environment:
      - REWRITE_LOCALHOST_TO=app
```

### 2. Kubernetes Testing
```yaml
env:
  - name: REWRITE_LOCALHOST_TO
    value: "my-service.namespace.svc.cluster.local"
```

### 3. Devcontainer
```json
{
  "containerEnv": {
    "REWRITE_LOCALHOST_TO": "app"
  }
}
```

## Future Enhancements

Potential improvements:
- Rewrite in execute_script contexts
- Pattern-based rewrites (not just localhost)
- Multiple rewrite rules
- Rewrite other tools (if needed)

## Documentation

See `LOCALHOST_REWRITE.md` for:
- Detailed usage examples
- Common patterns
- Troubleshooting guide
- Security considerations
- Complete API reference
