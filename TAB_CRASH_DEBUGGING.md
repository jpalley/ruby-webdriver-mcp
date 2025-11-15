# Chrome "Tab Crashed" Error - Analysis & Solutions

> **⚡ NEW: Automatic Crash Recovery**
> The system now includes automatic crash detection and recovery. See [CRASH_RECOVERY.md](CRASH_RECOVERY.md) for details.
> When crashes occur, the system will automatically:
> - Detect the crash
> - Close ALL Selenium sessions (including orphaned ones)
> - Wait for system stabilization
> - Retry the operation with a fresh session

## Problem
Chrome browser tabs are crashing frequently during navigation and element interaction operations, producing errors like:
```
tab crashed (Session info: chrome=129.0.6668.89)
```

## Root Causes

### 1. **Memory Exhaustion**
Chrome running in Docker containers can run out of memory, especially in headless mode. Even with `shm_size: 2gb`, heavy JavaScript pages or multiple concurrent sessions can exhaust resources.

### 2. **CPU/GPU Resource Limits**
Without proper GPU configuration or with limited CPU, Chrome's rendering engine can crash, especially when:
- Loading complex/heavy pages
- Running multiple animations or media
- Processing large DOM trees

### 3. **Chrome Process Isolation**
Chrome's site-per-process isolation can create too many processes in containerized environments with limited resources.

### 4. **JavaScript Memory Issues**
Websites with memory leaks or heavy JavaScript can crash the renderer process.

## Solutions Implemented

### 1. Added Chrome Stability Flags (`lib/selenium_webdriver_mcp/configuration.rb`)

```ruby
# Disable unnecessary features
--disable-gpu                    # Disable GPU in headless mode
--disable-software-rasterizer    # Disable software rasterizer
--disable-extensions             # No extensions needed
--disable-background-networking  # No background updates
--disable-dev-shm-usage          # Already had this

# Memory management
--disable-features=site-per-process         # Reduce process count
--js-flags=--max-old-space-size=512        # Limit JS heap to 512MB

# Performance flags
--enable-features=NetworkService,NetworkServiceInProcess  # In-process networking
--disable-renderer-backgrounding           # Keep renderer active
--metrics-recording-only                   # Minimal telemetry
--mute-audio                               # No audio needed
```

### 2. Enhanced Logging (`lib/selenium_webdriver_mcp/driver_manager.rb`)

Added comprehensive logging to track operations before crashes:

```ruby
# Logs include:
- Operation start time and duration
- Thread ID for concurrent request tracking
- Browser Selenium session ID
- Current URL (helps identify problematic pages)
- Active session count
- Detailed error information with timing
```

**Example log output:**
```
[Thread 12345] Navigating to: https://example.com
[Thread 12345] Navigation successful: https://example.com (took 2.3s)
[Thread 12345] Find-and-click: strategy=css, value=button.submit
[Thread 12345] Element found, now clicking...
[Thread 12345] Find-and-click successful: element_0 (took 0.15s)
```

**Error log output:**
```
[Thread 12345] Find-and-click FAILED after 5.2s: Selenium::WebDriver::Error::UnknownError - tab crashed
[Thread 12345] Current URL: https://heavy-site.com/page
[Thread 12345] Browser session_id: abc123def456
[Thread 12345] Active sessions: 3
```

## Debugging Strategy

With the new logging, you can now identify patterns:

1. **Check timing**: Do crashes happen after long operations? (>5s may indicate timeout issues)
2. **Check URLs**: Do certain URLs consistently crash? (heavy pages, bad JavaScript)
3. **Check session count**: Do crashes happen with many concurrent sessions? (resource exhaustion)
4. **Check patterns**: Navigation vs. interaction crashes? (different resource usage)

## Additional Recommendations

### 1. Reduce Selenium Max Sessions
In `docker-compose.production.yml`, reduce from 10 to 5:
```yaml
SE_NODE_MAX_SESSIONS: 5  # Instead of 10
```

### 2. Increase Timeouts
If pages are slow to load, increase timeouts in `lib/selenium_webdriver_mcp/configuration.rb`:
```ruby
@page_load_timeout = 60  # Instead of 30
```

### 3. Add Resource Limits to Docker Compose
```yaml
mcp-server:
  deploy:
    resources:
      limits:
        memory: 1G
      reservations:
        memory: 512M

selenium:
  deploy:
    resources:
      limits:
        memory: 3G
      reservations:
        memory: 2G
```

### 4. Monitor Selenium Container
```bash
# Check Selenium container logs
docker logs -f <selenium-container>

# Check memory usage
docker stats
```

### 5. Add Retry Logic (Future Enhancement)
Consider adding automatic retry for tab crashes:
```ruby
def navigate_to_with_retry(url, retries: 2)
  begin
    navigate_to(url)
  rescue Selenium::WebDriver::Error::UnknownError => e
    if e.message.include?("tab crashed") && retries > 0
      warn "Tab crashed, retrying... (#{retries} retries left)"
      sleep 1
      navigate_to_with_retry(url, retries: retries - 1)
    else
      raise
    end
  end
end
```

### 6. Use Non-Headless Mode for Debugging
Set `SELENIUM_HEADLESS=false` to see what's happening:
```yaml
environment:
  SELENIUM_HEADLESS: "false"
```
Then connect via VNC at `vnc://localhost:7900` (password: secret)

## Monitoring Your Logs

When you run the app again, watch for patterns in the logs:

```bash
# Filter for failures
docker logs mcp-server 2>&1 | grep FAILED

# Filter for specific URLs
docker logs mcp-server 2>&1 | grep "Navigating to"

# Filter for session count
docker logs mcp-server 2>&1 | grep "Active sessions"

# Watch timing
docker logs mcp-server 2>&1 | grep "took.*s)"
```

## Next Steps

1. **Run the app** with the new logging and Chrome flags
2. **Reproduce the crashes** and examine the logs
3. **Share the logs** showing:
   - What operation was running when it crashed
   - The URL being accessed
   - How many active sessions were running
   - How long the operation took before crashing
4. **Adjust settings** based on patterns (reduce sessions, increase memory, etc.)

The enhanced logging will help us identify:
- If specific websites cause crashes
- If it's a resource exhaustion issue (multiple sessions)
- If it's a timing issue (operations taking too long)
- If it's random (hardware/Docker issues)
