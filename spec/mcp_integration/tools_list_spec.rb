# frozen_string_literal: true

require "spec_helper"
require "support/mcp_client_helper"

RSpec.describe "MCP Tools List", type: :mcp_integration do
  describe "listing available tools" do
    it "returns all available tools via MCP protocol" do
      result = mcp_client.list_tools

      expect(result).to be_an(Array)
      expect(result.size).to eq(11) # Should have exactly 11 tools

      tool_names = result.map { |tool| tool[:name] }

      # Session management tools
      expect(tool_names).to include("create_session")
      expect(tool_names).to include("destroy_session")

      # Navigation tools
      expect(tool_names).to include("navigate")

      # Element tools
      expect(tool_names).to include("find_element")
      expect(tool_names).to include("click_element")
      expect(tool_names).to include("send_keys")
      expect(tool_names).to include("find_and_click")

      # JavaScript tools
      expect(tool_names).to include("execute_script")
      expect(tool_names).to include("get_console_logs")

      # Screenshot tools
      expect(tool_names).to include("save_desktop_screenshot")
      expect(tool_names).to include("save_mobile_screenshot")
    end

    it "includes tool descriptions" do
      result = mcp_client.list_tools

      result.each do |tool|
        expect(tool).to include(:name)
        expect(tool).to include(:description) if tool[:description]
      end
    end
  end
end
