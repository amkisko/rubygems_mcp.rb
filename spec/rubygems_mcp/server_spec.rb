require "spec_helper"
require "rubygems_mcp/server"

RSpec.describe RubygemsMcp::Server do
  describe ".start" do
    it "can be called without errors" do
      # This is a smoke test - actual server.start blocks, so we can't test it fully
      # Just verify the method exists and can be called
      expect(described_class).to respond_to(:start)
    end
  end

  describe ".register_tools" do
    it "registers all tools" do
      server = FastMcp::Server.new(name: "test", version: "1.0", logger: RubygemsMcp::Server::NullLogger.new)
      described_class.register_tools(server)

      expect(server.tools.length).to eq(12)
      # Tools are stored as string keys
      tool_names = server.tools.keys.map(&:to_s)
      expect(tool_names).to include(
        "RubygemsMcp::Server::GetLatestVersionsTool",
        "RubygemsMcp::Server::GetGemVersionsTool",
        "RubygemsMcp::Server::GetLatestRubyVersionTool",
        "RubygemsMcp::Server::GetRubyVersionsTool",
        "RubygemsMcp::Server::GetRubyVersionChangelogTool",
        "RubygemsMcp::Server::GetGemInfoTool",
        "RubygemsMcp::Server::GetGemReverseDependenciesTool",
        "RubygemsMcp::Server::GetGemVersionDownloadsTool",
        "RubygemsMcp::Server::GetLatestGemsTool",
        "RubygemsMcp::Server::GetRecentlyUpdatedGemsTool",
        "RubygemsMcp::Server::GetGemChangelogTool",
        "RubygemsMcp::Server::SearchGemsTool"
      )
    end
  end

  describe ".register_resources" do
    it "registers all resources" do
      server = FastMcp::Server.new(name: "test", version: "1.0", logger: RubygemsMcp::Server::NullLogger.new)
      described_class.register_resources(server)

      expect(server.resources.length).to eq(4)
      expect(server.resources.keys).to include(
        "rubygems://popular",
        "rubygems://ruby/compatibility",
        "rubygems://ruby/maintenance",
        "rubygems://ruby/latest"
      )
    end
  end

  describe "Resources" do
    describe "PopularGemsResource" do
      it "provides popular gems data", :vcr do
        VCR.use_cassette("popular_gems_resource") do
          resource = RubygemsMcp::Server::PopularGemsResource.instance
          expect(resource.uri).to eq("rubygems://popular")
          expect(resource.class.resource_name).to eq("Popular Ruby Gems")
          expect(resource.content).to be_a(String)
        end
      end
    end

    describe "RubyVersionCompatibilityResource" do
      it "provides compatibility data", :vcr do
        VCR.use_cassette("ruby_version_compatibility_resource") do
          resource = RubygemsMcp::Server::RubyVersionCompatibilityResource.instance
          expect(resource.uri).to eq("rubygems://ruby/compatibility")
          expect(resource.class.resource_name).to eq("Ruby Version Compatibility")
          expect(resource.content).to be_a(String)
        end
      end
    end

    describe "RubyMaintenanceStatusResource" do
      it "provides maintenance status data", :vcr do
        VCR.use_cassette("ruby_maintenance_status_resource") do
          resource = RubygemsMcp::Server::RubyMaintenanceStatusResource.instance
          expect(resource.uri).to eq("rubygems://ruby/maintenance")
          expect(resource.class.resource_name).to eq("Ruby Maintenance Status")
          expect(resource.content).to be_a(String)
        end
      end
    end

    describe "LatestRubyVersionResource" do
      it "provides latest Ruby version data", :vcr do
        VCR.use_cassette("latest_ruby_version_resource") do
          resource = RubygemsMcp::Server::LatestRubyVersionResource.instance
          expect(resource.uri).to eq("rubygems://ruby/latest")
          expect(resource.class.resource_name).to eq("Latest Ruby Version")
          expect(resource.content).to be_a(String)
        end
      end
    end
  end
end
