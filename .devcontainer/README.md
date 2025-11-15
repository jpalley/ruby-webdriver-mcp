# Devcontainer Setup for selenium-webdriver-mcp

This directory contains the configuration for a complete development and testing environment using VSCode's Remote-Containers feature.

## What's Included

### Services

**App Container**
- Ruby 3.2 environment
- All gem dependencies pre-installed (automatic `bundle install`)
- Working directory mounted at `/workspace`
- Connected to Selenium via Docker network

**Selenium Container**
- Selenium standalone Chromium (ARM64 compatible)
- WebDriver endpoint: `http://selenium:4444/wd/hub`
- Configured for up to 10 concurrent sessions
- 2GB shared memory for browser stability

### Ports

- **3000**: MCP server (when running)
- **4444**: Selenium WebDriver API

## Quick Start

### Prerequisites

1. Install Docker Desktop
2. Install VSCode
3. Install the "Remote - Containers" extension

### Opening the Project

1. Open this project folder in VSCode
2. When prompted, click **"Reopen in Container"**
   - Or use Command Palette (Cmd/Ctrl+Shift+P): "Remote-Containers: Reopen in Container"
3. Wait for containers to build and start (first time takes 2-5 minutes)
4. **Gems are installed automatically** - no need to run `bundle install`
5. Terminal will open in the app container

### Verify Setup

```bash
# Check Ruby version
ruby --version
# Should show: ruby 3.2.x

# Check gems are installed
bundle list
# Should show fast-mcp, selenium-webdriver, rack, etc.

# Check Selenium is available
curl http://selenium:4444/wd/hub/status
# Should return JSON with "ready": true
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run MCP integration tests (tests the MCP server protocol)
bundle exec rspec spec/mcp_integration

# Run unit tests
bundle exec rspec spec/unit

# Run specific test file
bundle exec rspec spec/mcp_integration/session_tools_spec.rb
```

See [TESTING.md](../TESTING.md) for detailed testing documentation.

## Starting the MCP Server

```bash
# Start the MCP server
bundle exec selenium-mcp-server

# Or using rake
bundle exec rake selenium_mcp:start
```

The server will be available at `http://localhost:3000/mcp`

## Development Workflow

### Making Code Changes

1. Edit files in VSCode (they're mounted from host)
2. Changes are immediately reflected in container
3. Run tests to verify changes:
   ```bash
   bundle exec rspec spec/mcp_integration/
   ```

### Adding Dependencies

1. Edit `Gemfile` to add new gem
2. Run: `bundle install`
3. Or rebuild container: Command Palette → "Remote-Containers: Rebuild Container"

### Automatic Bundle Install

The devcontainer automatically runs `bundle install`:
- **During build**: Gems cached in Docker image
- **On create**: Installs any missing gems
- **On start**: Checks and installs if needed

You should never need to manually run `bundle install`!

### Running RuboCop

```bash
# Check code style
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

## Container Management

### Rebuilding Containers

If you modify Dockerfile or docker-compose.yml:

1. Command Palette: "Remote-Containers: Rebuild Container"
2. Or manually:
   ```bash
   docker-compose -f .devcontainer/docker-compose.yml down
   docker-compose -f .devcontainer/docker-compose.yml build --no-cache
   ```

### Stopping Containers

Containers stop automatically when you close VSCode or exit the devcontainer.

To manually stop:
```bash
docker-compose -f .devcontainer/docker-compose.yml down
```

### Checking Container Status

```bash
# List running containers
docker ps

# Should see:
# - app container (ruby-webdriver-mcp_app)
# - selenium container (selenium/standalone-chromium)
```

### Viewing Logs

```bash
# Selenium logs
docker logs $(docker ps -qf "ancestor=selenium/standalone-chromium")

# App container logs
docker logs $(docker ps -qf "name=app")
```

## Troubleshooting

### Bundle Install Issues

If gems aren't installing:

```bash
# Inside container, check bundle status
bundle check

# Manually install
bundle install

# If still failing, clean and reinstall
rm -rf vendor/bundle .bundle Gemfile.lock
bundle install
```

### Selenium Not Available

```bash
# Check Selenium health
curl http://selenium:4444/wd/hub/status

# If not responding, check container
docker ps | grep selenium

# View Selenium logs
docker logs $(docker ps -qf "ancestor=selenium/standalone-chromium")

# Restart Selenium container
docker restart $(docker ps -qf "ancestor=selenium/standalone-chromium")
```

### Port Already in Use

If ports 3000 or 4444 are already in use:

1. Stop other services using those ports
2. Or modify `devcontainer.json` to use different ports

### Container Won't Start

```bash
# Check Docker is running
docker ps

# Rebuild with clean slate
docker-compose -f .devcontainer/docker-compose.yml down -v
docker-compose -f .devcontainer/docker-compose.yml build --no-cache
```

### Tests Fail with Connection Errors

```bash
# Verify Selenium is healthy
docker ps

# Selenium container should show "healthy" status
# If not, wait a minute and check again

# Test connection
curl http://selenium:4444/wd/hub/status
```

### Gemfile.lock Issues

```bash
# If Gemfile.lock gets out of sync
rm Gemfile.lock
bundle install
```

Note: Gemfile.lock is gitignored for this gem since it's a library meant to run in multiple environments.

## Configuration Files

- `devcontainer.json` - VSCode devcontainer configuration
- `docker-compose.yml` - Docker services definition
- `Dockerfile` - App container image definition

## Environment Variables

The following environment variables are automatically set:

- `SELENIUM_URL=http://selenium:4444/wd/hub`
- `RACK_ENV=development`
- `RAILS_ENV=development`

## VSCode Extensions

These extensions are automatically installed in the devcontainer:

- **Shopify.ruby-lsp** - Ruby language server
- **rebornix.ruby** - Ruby language support
- **kaiwood.endwise** - Auto-insert `end` keyword
- **misogi.ruby-rubocop** - RuboCop linting

## Network Configuration

Containers communicate via a Docker bridge network:

```
app container (ruby) ←→ Docker network ←→ selenium container (chromium)
      ↓                                           ↓
   localhost:3000                          localhost:4444
```

## Resource Usage

Typical resource usage:
- **App container**: ~200MB RAM
- **Selenium container**: ~500MB-1GB RAM
- **Total disk**: ~2GB

## Tips

1. **Gems install automatically** - no need to run `bundle install` manually
2. **Keep containers running** between sessions (faster startup)
3. **Check Selenium health** before running integration tests
4. **Use focused tests** (`fit` or `fdescribe`) during development
5. **Monitor container logs** if issues occur
6. **Rebuild container** after changing Dockerfile or dependencies

## Additional Resources

- [VSCode Remote Containers Docs](https://code.visualstudio.com/docs/remote/containers)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [Selenium Docker Images](https://github.com/seleniumhq-community/docker-seleniarm)
- [Testing Guide](../TESTING.md)
