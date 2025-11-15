# frozen_string_literal: true

require "sinatra/base"
require "sinatra/json"
require "base64"
require "rack/protection"

module SeleniumWebdriverMcp
  # Sinatra web application for browser session dashboard
  # Provides a browser-based interface for viewing sessions and screenshot history
  class WebApp < Sinatra::Base
    set :public_folder, File.expand_path("../../public", __dir__)
    set :show_exceptions, false
    set :protection, false  # Deployed behind reverse proxy with authentication

    # Dashboard home page
    get "/" do
      content_type :html
      dashboard_html
    end

    # API: List all sessions
    get "/api/sessions" do
      sessions = SessionManager.instance.list_sessions

      # Sort by last_accessed (most recent first)
      sessions_data = sessions.sort_by { |s| -s[:last_accessed].to_f }.map do |session|
        session_id = session[:session_id]

        # Try to get current browser state
        begin
          driver = SessionManager.instance.get_driver_manager(session_id)
          current_url = driver.current_url rescue "N/A"
          page_title = driver.page_title rescue "N/A"
        rescue StandardError
          current_url = "N/A"
          page_title = "N/A"
        end

        {
          session_id: session_id,
          created_at: session[:created_at].to_i,
          last_accessed: session[:last_accessed].to_i,
          current_url: current_url,
          page_title: page_title,
          screenshot_count: ScreenshotHistory.instance.get_history(session_id).length
        }
      end

      json sessions_data
    end

    # API: Get screenshots for a session
    get "/api/sessions/:session_id/screenshots" do
      session_id = params[:session_id]

      # Check if session exists
      unless SessionManager.instance.session_exists?(session_id)
        status 404
        return json({ error: "Session not found" })
      end

      history = ScreenshotHistory.instance.get_history(session_id)
      json history
    end

    # API: Capture a screenshot
    post "/api/sessions/:session_id/screenshot" do
      session_id = params[:session_id]

      begin
        driver_manager = SessionManager.instance.get_driver_manager(session_id, auto_create: false)
        current_url = driver_manager.current_url

        # Capture screenshot
        screenshot_base64 = driver_manager.ensure_started.screenshot_as(:base64)
        png_data = Base64.decode64(screenshot_base64)

        # Save to history
        metadata = ScreenshotHistory.instance.save_screenshot(session_id, png_data, current_url)

        json({
          success: true,
          screenshot: metadata
        })
      rescue SeleniumWebdriverMcp::Error => e
        status 404
        json({
          success: false,
          error: e.message
        })
      rescue StandardError => e
        status 500
        json({
          success: false,
          error: e.message
        })
      end
    end

    private

    def dashboard_html
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Selenium WebDriver MCP - Dashboard</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="bg-gray-100">
          <div class="container mx-auto px-4 py-8">
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-gray-900">Selenium WebDriver MCP Dashboard</h1>
              <p class="text-gray-600 mt-2">Active browser sessions and screenshot history</p>
            </div>

            <div id="sessions-container" class="space-y-4">
              <div class="text-center text-gray-500 py-8">
                Loading sessions...
              </div>
            </div>
          </div>

          <script>
            let expandedSessions = new Set();

            async function fetchSessions() {
              try {
                const response = await fetch('/api/sessions');
                const sessions = await response.json();
                renderSessions(sessions);
              } catch (error) {
                console.error('Error fetching sessions:', error);
                document.getElementById('sessions-container').innerHTML =
                  '<div class="text-center text-red-500 py-8">Error loading sessions</div>';
              }
            }

            async function captureScreenshot(sessionId) {
              try {
                const response = await fetch(`/api/sessions/${sessionId}/screenshot`, {
                  method: 'POST'
                });
                const result = await response.json();
                if (result.success) {
                  // Reload this session's screenshots
                  if (expandedSessions.has(sessionId)) {
                    loadScreenshots(sessionId);
                  }
                  // Refresh session list to update counts
                  fetchSessions();
                }
              } catch (error) {
                console.error('Error capturing screenshot:', error);
              }
            }

            async function loadScreenshots(sessionId) {
              const screenshotsContainer = document.getElementById(`screenshots-${sessionId}`);
              screenshotsContainer.innerHTML = '<div class="text-center text-gray-500 py-4">Loading...</div>';

              try {
                const response = await fetch(`/api/sessions/${sessionId}/screenshots`);
                const screenshots = await response.json();

                if (screenshots.length === 0) {
                  screenshotsContainer.innerHTML =
                    '<div class="text-center text-gray-500 py-4">No screenshots yet. Click "Capture Screenshot" to save one.</div>';
                  return;
                }

                screenshotsContainer.innerHTML = screenshots.map(screenshot => `
                  <div class="border rounded-lg p-4 bg-white">
                    <div class="mb-2">
                      <div class="text-sm text-gray-600">${new Date(screenshot.timestamp * 1000).toLocaleString()}</div>
                      <div class="text-sm text-blue-600 truncate">${screenshot.url}</div>
                    </div>
                    <a href="${screenshot.path}" target="_blank" class="block">
                      <img src="${screenshot.path}" alt="Screenshot" class="w-full rounded border hover:opacity-90">
                    </a>
                  </div>
                `).join('');
              } catch (error) {
                console.error('Error loading screenshots:', error);
                screenshotsContainer.innerHTML =
                  '<div class="text-center text-red-500 py-4">Error loading screenshots</div>';
              }
            }

            function toggleSession(sessionId) {
              if (expandedSessions.has(sessionId)) {
                expandedSessions.delete(sessionId);
                document.getElementById(`screenshots-${sessionId}`).classList.add('hidden');
                document.getElementById(`expand-icon-${sessionId}`).textContent = '▶';
              } else {
                expandedSessions.add(sessionId);
                document.getElementById(`screenshots-${sessionId}`).classList.remove('hidden');
                document.getElementById(`expand-icon-${sessionId}`).textContent = '▼';
                loadScreenshots(sessionId);
              }
            }

            function renderSessions(sessions) {
              const container = document.getElementById('sessions-container');

              if (sessions.length === 0) {
                container.innerHTML =
                  '<div class="text-center text-gray-500 py-8">No active sessions</div>';
                return;
              }

              container.innerHTML = sessions.map(session => {
                const isExpanded = expandedSessions.has(session.session_id);
                const lastAccessed = new Date(session.last_accessed * 1000);
                const timeAgo = getTimeAgo(lastAccessed);

                return `
                  <div class="bg-white rounded-lg shadow">
                    <div class="p-6">
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <div class="flex items-center gap-2">
                            <button onclick="toggleSession('${session.session_id}')"
                                    class="text-gray-500 hover:text-gray-700">
                              <span id="expand-icon-${session.session_id}" class="text-sm">${isExpanded ? '▼' : '▶'}</span>
                            </button>
                            <h3 class="text-lg font-semibold text-gray-900">${session.session_id}</h3>
                            <span class="px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">
                              Active
                            </span>
                          </div>
                          <div class="mt-2 space-y-1">
                            <div class="text-sm text-gray-600">
                              <span class="font-medium">URL:</span>
                              <span class="text-blue-600">${session.current_url}</span>
                            </div>
                            <div class="text-sm text-gray-600">
                              <span class="font-medium">Title:</span> ${session.page_title}
                            </div>
                            <div class="text-sm text-gray-500">
                              Last active: ${timeAgo}
                            </div>
                            <div class="text-sm text-gray-500">
                              Screenshots: ${session.screenshot_count}
                            </div>
                          </div>
                        </div>
                        <button onclick="captureScreenshot('${session.session_id}')"
                                class="ml-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition">
                          Capture Screenshot
                        </button>
                      </div>

                      <div id="screenshots-${session.session_id}"
                           class="${isExpanded ? '' : 'hidden'} mt-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                      </div>
                    </div>
                  </div>
                `;
              }).join('');

              // Load screenshots for expanded sessions
              expandedSessions.forEach(sessionId => {
                if (sessions.find(s => s.session_id === sessionId)) {
                  loadScreenshots(sessionId);
                }
              });
            }

            function getTimeAgo(date) {
              const seconds = Math.floor((new Date() - date) / 1000);
              if (seconds < 60) return `${seconds} seconds ago`;
              const minutes = Math.floor(seconds / 60);
              if (minutes < 60) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
              const hours = Math.floor(minutes / 60);
              if (hours < 24) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
              const days = Math.floor(hours / 24);
              return `${days} day${days > 1 ? 's' : ''} ago`;
            }

            // Initial load
            fetchSessions();

            // Auto-refresh every 5 seconds
            setInterval(fetchSessions, 5000);
          </script>
        </body>
        </html>
      HTML
    end
  end
end
