# frozen_string_literal: true

require "spec_helper"
require "support/test_html_server"

RSpec.describe "Thread Safety", type: :integration_driver_only do
  let(:session_manager) { SeleniumWebdriverMcp::SessionManager.instance }

  before do
    # Clean up any existing sessions
    session_manager.destroy_all_sessions
  end

  after do
    # Clean up sessions
    session_manager.destroy_all_sessions
  end

  describe "concurrent access to the same session" do
    it "handles multiple threads operating on the same session without errors" do
      # Create a session in the main thread
      session_id = session_manager.create_session
      driver_manager = session_manager.get_driver_manager(session_id)

      # Navigate to initial page
      driver_manager.navigate_to(TestHtmlServer.url("/simple.html"))

      # Array to collect errors from threads
      errors = []
      results = []

      # Spawn multiple threads that all operate on the same session
      threads = 5.times.map do |i|
        Thread.new do
          begin
            # Each thread gets the same driver_manager
            dm = session_manager.get_driver_manager(session_id)

            # Perform various operations
            case i % 3
            when 0
              # Navigate operation
              result = dm.navigate_to(TestHtmlServer.url("/form.html"))
              results << { thread: i, operation: "navigate", result: result }
            when 1
              # Get page info
              title = dm.page_title
              url = dm.current_url
              results << { thread: i, operation: "page_info", title: title, url: url }
            when 2
              # Find element
              element = dm.find_element(:tag_name, "body")
              results << { thread: i, operation: "find_element", element_id: element[:element_id] }
            end
          rescue StandardError => e
            errors << { thread: i, error: e, message: e.message, backtrace: e.backtrace.first(5) }
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Verify no errors occurred
      expect(errors).to be_empty, "Expected no threading errors, but got: #{errors.inspect}"

      # Verify we got results from all threads
      expect(results.size).to eq(5)

      # Specifically check for "stream closed in another thread" errors
      stream_errors = errors.select { |e| e[:message].include?("stream closed") }
      expect(stream_errors).to be_empty, "Got 'stream closed in another thread' errors: #{stream_errors.inspect}"
    end

    it "handles create_session followed by navigate in different threads" do
      # This simulates the exact scenario described in the bug report:
      # 1. Request 1 (Thread A): create_session
      # 2. Request 2 (Thread B): navigate with that session_id

      session_id = nil
      errors = []

      # Thread 1: Create session
      thread1 = Thread.new do
        begin
          session_id = session_manager.create_session
          sleep 0.1 # Give time for session to be fully initialized
        rescue StandardError => e
          errors << { thread: 1, error: e, message: e.message }
        end
      end

      thread1.join
      expect(session_id).not_to be_nil

      # Thread 2: Navigate using the session created by Thread 1
      thread2 = Thread.new do
        begin
          dm = session_manager.get_driver_manager(session_id)
          result = dm.navigate_to(TestHtmlServer.url("/simple.html"))
          expect(result[:success]).to be true
        rescue StandardError => e
          errors << { thread: 2, error: e, message: e.message, backtrace: e.backtrace.first(10) }
        end
      end

      thread2.join

      # Verify no errors
      expect(errors).to be_empty, "Expected no threading errors, but got: #{errors.inspect}"

      # Specifically check for "stream closed in another thread" errors
      stream_errors = errors.select { |e| e[:message].include?("stream closed") }
      expect(stream_errors).to be_empty,
                            "Got 'stream closed in another thread' errors: #{stream_errors.inspect}"
    end

    it "handles rapid concurrent operations without race conditions" do
      # Create a session
      session_id = session_manager.create_session
      driver_manager = session_manager.get_driver_manager(session_id)

      # Navigate to a page with elements
      driver_manager.navigate_to(TestHtmlServer.url("/form.html"))

      errors = []
      element_ids = []

      # Spawn many threads that all try to find elements concurrently
      threads = 10.times.map do |i|
        Thread.new do
          begin
            dm = session_manager.get_driver_manager(session_id)
            element = dm.find_element(:tag_name, "input")
            element_ids << element[:element_id]
          rescue StandardError => e
            errors << { thread: i, error: e, message: e.message }
          end
        end
      end

      threads.each(&:join)

      # Verify no errors
      expect(errors).to be_empty, "Expected no threading errors, but got: #{errors.inspect}"

      # Verify we got element IDs from all threads
      expect(element_ids.size).to eq(10)

      # All element IDs should be unique (no race condition in cache)
      expect(element_ids.uniq.size).to eq(10), "Element IDs should be unique, got duplicates: #{element_ids}"
    end
  end

  describe "concurrent sessions" do
    it "handles multiple threads with different sessions" do
      errors = []
      session_ids = []

      # Create multiple sessions in parallel
      threads = 5.times.map do |i|
        Thread.new do
          begin
            sid = session_manager.create_session
            session_ids << sid

            dm = session_manager.get_driver_manager(sid)
            dm.navigate_to(TestHtmlServer.url("/simple.html"))
          rescue StandardError => e
            errors << { thread: i, error: e, message: e.message }
          end
        end
      end

      threads.each(&:join)

      # Verify no errors
      expect(errors).to be_empty, "Expected no threading errors, but got: #{errors.inspect}"

      # Verify we created 5 unique sessions
      expect(session_ids.uniq.size).to eq(5)
    end
  end
end
