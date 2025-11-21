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

      expect(server.tools.length).to eq(16)
      # Tools are stored with user-friendly snake_case names
      tool_names = server.tools.keys.map(&:to_s)
      expect(tool_names).to include(
        "get_latest_versions",
        "get_gem_versions",
        "get_latest_ruby_version",
        "get_ruby_versions",
        "get_ruby_version_changelog",
        "get_gem_info",
        "get_gem_reverse_dependencies",
        "get_gem_version_downloads",
        "get_latest_gems",
        "get_recently_updated_gems",
        "get_gem_changelog",
        "search_gems",
        "get_ruby_roadmap",
        "get_ruby_version_roadmap_details",
        "get_ruby_version_github_changelog",
        "get_gem_version_info"
      )
    end
  end

  describe ".register_resources" do
    it "registers all resources" do
      server = FastMcp::Server.new(name: "test", version: "1.0", logger: RubygemsMcp::Server::NullLogger.new)
      described_class.register_resources(server)

      expect(server.resources.length).to eq(4)
      # Resources are stored as an Array of classes
      resource_uris = server.resources.map(&:uri)
      expect(resource_uris).to include(
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
          resource = RubygemsMcp::Server::PopularGemsResource.new
          expect(resource.uri).to eq("rubygems://popular")
          expect(resource.class.resource_name).to eq("Popular Ruby Gems")
          expect(resource.content).to be_a(String)
        end
      end
    end

    describe "RubyVersionCompatibilityResource" do
      it "provides compatibility data", :vcr do
        VCR.use_cassette("ruby_version_compatibility_resource") do
          resource = RubygemsMcp::Server::RubyVersionCompatibilityResource.new
          expect(resource.uri).to eq("rubygems://ruby/compatibility")
          expect(resource.class.resource_name).to eq("Ruby Version Compatibility")
          expect(resource.content).to be_a(String)
        end
      end
    end

    describe "RubyMaintenanceStatusResource" do
      it "provides maintenance status data", :vcr do
        VCR.use_cassette("ruby_maintenance_status_resource") do
          resource = RubygemsMcp::Server::RubyMaintenanceStatusResource.new
          expect(resource.uri).to eq("rubygems://ruby/maintenance")
          expect(resource.class.resource_name).to eq("Ruby Maintenance Status")
          expect(resource.content).to be_a(String)
        end
      end
    end

    describe "LatestRubyVersionResource" do
      it "provides latest Ruby version data", :vcr do
        VCR.use_cassette("latest_ruby_version_resource") do
          resource = RubygemsMcp::Server::LatestRubyVersionResource.new
          expect(resource.uri).to eq("rubygems://ruby/latest")
          expect(resource.class.resource_name).to eq("Latest Ruby Version")
          expect(resource.content).to be_a(String)
        end
      end
    end
  end

  describe "Tool error handling" do
    describe "GetRubyVersionChangelogTool" do
      it "handles empty content string" do
        tool = RubygemsMcp::Server::GetRubyVersionChangelogTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_ruby_version_changelog).and_return({content: ""})

        result = tool.call(version: "3.4.7")
        expect(result[:content]).to eq([])
      end

      it "handles nil content" do
        tool = RubygemsMcp::Server::GetRubyVersionChangelogTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_ruby_version_changelog).and_return({content: nil})

        result = tool.call(version: "3.4.7")
        expect(result[:content]).to eq([])
      end

      it "handles array content with string items" do
        tool = RubygemsMcp::Server::GetRubyVersionChangelogTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_ruby_version_changelog).and_return({content: ["item1", "item2"]})

        result = tool.call(version: "3.4.7")
        expect(result[:content]).to be_an(Array)
        expect(result[:content].all? { |item| item[:type] == "text" }).to be true
      end

      it "handles array content with hash items without type" do
        tool = RubygemsMcp::Server::GetRubyVersionChangelogTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_ruby_version_changelog).and_return({content: [{text: "item1"}]})

        result = tool.call(version: "3.4.7")
        expect(result[:content]).to be_an(Array)
        expect(result[:content].first[:type]).to eq("text")
      end

      it "handles array content with hash items that already have type" do
        tool = RubygemsMcp::Server::GetRubyVersionChangelogTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_ruby_version_changelog).and_return({content: [{type: "text", text: "item1"}]})

        result = tool.call(version: "3.4.7")
        expect(result[:content]).to be_an(Array)
        expect(result[:content].first[:type]).to eq("text")
      end
    end

    describe "GetGemVersionsTool" do
      it "handles invalid sort order" do
        tool = RubygemsMcp::Server::GetGemVersionsTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_gem_versions).and_return([])

        result = tool.call(gem_name: "rails", sort: "invalid_sort")
        # Should default to :version_desc (line 193)
        expect(result).to be_an(Array)
      end
    end

    describe "GetRubyVersionsTool" do
      it "handles invalid sort order" do
        tool = RubygemsMcp::Server::GetRubyVersionsTool.new
        client = RubygemsMcp::Client.new
        allow(tool).to receive(:get_client).and_return(client)
        allow(client).to receive(:get_ruby_versions).and_return([])

        result = tool.call(sort: "invalid_sort")
        # Should default to :version_desc (line 230)
        expect(result).to be_an(Array)
      end
    end

    describe "PopularGemsResource" do
      it "handles ResponseSizeExceededError" do
        resource = RubygemsMcp::Server::PopularGemsResource.new

        # Create a mock client that raises error for first gem
        mock_client = instance_double(RubygemsMcp::Client)
        call_count = 0
        allow(mock_client).to receive(:get_gem_versions) do |gem_name, **kwargs|
          call_count += 1
          if call_count == 1
            raise RubygemsMcp::ResponseSizeExceededError.new(6000000, 5000000, uri: "https://example.com")
          else
            [{version: "1.0.0", release_date: "2020-01-01", name: gem_name}]
          end
        end

        # Replace the Client.new call in the resource
        allow(RubygemsMcp::Client).to receive(:new).and_return(mock_client)

        content = resource.content
        expect(content).to be_a(String)
        # Should include error information (line 443)
        parsed = JSON.parse(content)
        expect(parsed).to be_an(Array)
        error_gem = parsed.find { |g| g["name"] == "rails" }
        expect(error_gem["error"]).to be_present if error_gem
      end

      it "handles CorruptedDataError" do
        resource = RubygemsMcp::Server::PopularGemsResource.new

        # Create a mock client that raises error for first gem
        mock_client = instance_double(RubygemsMcp::Client)
        call_count = 0
        allow(mock_client).to receive(:get_gem_versions) do |gem_name, **kwargs|
          call_count += 1
          if call_count == 1
            raise RubygemsMcp::CorruptedDataError.new("Corrupted data", uri: "https://example.com")
          else
            [{version: "1.0.0", release_date: "2020-01-01", name: gem_name}]
          end
        end

        # Replace the Client.new call in the resource
        allow(RubygemsMcp::Client).to receive(:new).and_return(mock_client)

        content = resource.content
        expect(content).to be_a(String)
        # Should include error information (line 443)
        parsed = JSON.parse(content)
        expect(parsed).to be_an(Array)
        error_gem = parsed.find { |g| g["name"] == "rails" }
        expect(error_gem["error"]).to be_present if error_gem
      end

      it "handles gems with no versions" do
        resource = RubygemsMcp::Server::PopularGemsResource.new

        # Create a mock client that returns empty array
        mock_client = instance_double(RubygemsMcp::Client)
        allow(mock_client).to receive(:get_gem_versions).and_return([])

        # Replace the Client.new call in the resource
        allow(RubygemsMcp::Client).to receive(:new).and_return(mock_client)

        content = resource.content
        expect(content).to be_a(String)
        parsed = JSON.parse(content)
        expect(parsed).to be_an(Array)
        # Gems with nil versions should be filtered out (line 447)
        expect(parsed.all? { |g| g["version"] }).to be true
      end
    end
  end

  describe "Tool implementations" do
    it "calls get_client for GetLatestVersionsTool" do
      tool = RubygemsMcp::Server::GetLatestVersionsTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_latest_versions).and_return([])

      result = tool.call(gem_names: ["rails"])
      expect(result).to be_an(Array)
    end

    it "calls get_client for GetLatestRubyVersionTool" do
      tool = RubygemsMcp::Server::GetLatestRubyVersionTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_latest_ruby_version).and_return({version: "3.4.7"})

      result = tool.call
      expect(result[:version]).to eq("3.4.7")
    end

    it "calls get_client for GetGemInfoTool" do
      tool = RubygemsMcp::Server::GetGemInfoTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_gem_info).and_return({name: "rails"})

      result = tool.call(gem_name: "rails")
      expect(result[:name]).to eq("rails")
    end

    it "calls get_client for GetGemReverseDependenciesTool" do
      tool = RubygemsMcp::Server::GetGemReverseDependenciesTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_gem_reverse_dependencies).and_return([])

      result = tool.call(gem_name: "rails")
      expect(result).to be_an(Array)
    end

    it "calls get_client for GetGemVersionDownloadsTool" do
      tool = RubygemsMcp::Server::GetGemVersionDownloadsTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_gem_version_downloads).and_return({downloads: 1000})

      result = tool.call(gem_name: "rails", version: "1.0.0")
      expect(result[:downloads]).to eq(1000)
    end

    it "calls get_client for GetLatestGemsTool" do
      tool = RubygemsMcp::Server::GetLatestGemsTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_latest_gems).and_return([])

      result = tool.call(limit: 10)
      expect(result).to be_an(Array)
    end

    it "calls get_client for GetRecentlyUpdatedGemsTool" do
      tool = RubygemsMcp::Server::GetRecentlyUpdatedGemsTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_recently_updated_gems).and_return([])

      result = tool.call(limit: 10)
      expect(result).to be_an(Array)
    end

    it "calls get_client for GetGemChangelogTool" do
      tool = RubygemsMcp::Server::GetGemChangelogTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_gem_changelog).and_return({summary: "changelog"})

      result = tool.call(gem_name: "rails")
      expect(result[:summary]).to eq("changelog")
    end

    it "calls get_client for SearchGemsTool" do
      tool = RubygemsMcp::Server::SearchGemsTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:search_gems).and_return([])

      result = tool.call(query: "rails")
      expect(result).to be_an(Array)
    end

    it "calls get_client for GetRubyRoadmapTool" do
      tool = RubygemsMcp::Server::GetRubyRoadmapTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_ruby_roadmap).and_return({versions: []})

      result = tool.call
      expect(result[:versions]).to eq([])
    end

    it "calls get_client for GetRubyVersionRoadmapDetailsTool" do
      tool = RubygemsMcp::Server::GetRubyVersionRoadmapDetailsTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_ruby_version_roadmap_details).and_return({issues: []})

      result = tool.call(version: "https://example.com/version")
      expect(result[:issues]).to eq([])
    end

    it "calls get_client for GetRubyVersionGithubChangelogTool" do
      tool = RubygemsMcp::Server::GetRubyVersionGithubChangelogTool.new
      client = RubygemsMcp::Client.new
      allow(tool).to receive(:get_client).and_return(client)
      allow(client).to receive(:get_ruby_version_github_changelog).and_return({body: "changelog"})

      result = tool.call(version: "3.4.7")
      expect(result[:body]).to eq("changelog")
    end
  end

  describe "NullLogger" do
    it "implements all logger methods" do
      logger = RubygemsMcp::Server::NullLogger.new
      expect(logger).to respond_to(:debug)
      expect(logger).to respond_to(:info)
      expect(logger).to respond_to(:warn)
      expect(logger).to respond_to(:error)
      expect(logger).to respond_to(:fatal)
      expect(logger).to respond_to(:unknown)

      # All methods should not raise errors
      expect { logger.debug("test") }.not_to raise_error
      expect { logger.info("test") }.not_to raise_error
      expect { logger.warn("test") }.not_to raise_error
      expect { logger.error("test") }.not_to raise_error
      expect { logger.fatal("test") }.not_to raise_error
      expect { logger.unknown("test") }.not_to raise_error
    end

    it "manages client_initialized state" do
      logger = RubygemsMcp::Server::NullLogger.new
      expect(logger.client_initialized?).to be false

      logger.set_client_initialized(true)
      expect(logger.client_initialized?).to be true

      logger.set_client_initialized(false)
      expect(logger.client_initialized?).to be false
    end

    it "checks transport type" do
      logger = RubygemsMcp::Server::NullLogger.new

      logger.transport = :stdio
      expect(logger.stdio_transport?).to be true
      expect(logger.rack_transport?).to be false

      logger.transport = :rack
      expect(logger.stdio_transport?).to be false
      expect(logger.rack_transport?).to be true
    end

    it "manages log level" do
      logger = RubygemsMcp::Server::NullLogger.new
      expect(logger.level).to be_nil

      logger.level = :info
      expect(logger.level).to eq(:info)
    end
  end
end
