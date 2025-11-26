#!/usr/bin/env ruby
# frozen_string_literal: true

require "fast_mcp"
require "rubygems_mcp"
require "logger"
require "stringio"
require "securerandom"

# Alias MCP to FastMcp for compatibility
FastMcp = MCP unless defined?(FastMcp)

module RubygemsMcp
  # MCP Server for RubyGems integration
  #
  # This server provides MCP tools for interacting with RubyGems and Ruby version information
  # Usage: bundle exec rubygems_mcp
  class Server
    # Simple null logger that suppresses all output
    # Must implement the same interface as MCP::Logger
    class NullLogger
      attr_accessor :transport, :client_initialized

      def initialize
        @transport = nil
        @client_initialized = false
        @level = nil
      end

      attr_writer :level

      attr_reader :level

      def debug(*)
      end

      def info(*)
      end

      def warn(*)
      end

      def error(*)
      end

      def fatal(*)
      end

      def unknown(*)
      end

      def client_initialized?
        @client_initialized
      end

      def set_client_initialized(value = true)
        @client_initialized = value
      end

      def stdio_transport?
        @transport == :stdio
      end

      def rack_transport?
        @transport == :rack
      end
    end

    def self.start
      # Create server with null logger to prevent any output
      server = FastMcp::Server.new(
        name: "rubygems",
        version: RubygemsMcp::VERSION,
        logger: NullLogger.new
      )

      # Register all tools
      register_tools(server)

      # Register all resources
      register_resources(server)

      # Start the server (blocks and speaks MCP over STDIN/STDOUT)
      server.start
    end

    def self.register_tools(server)
      server.register_tool(GetLatestVersionsTool)
      server.register_tool(GetGemVersionsTool)
      server.register_tool(GetLatestRubyVersionTool)
      server.register_tool(GetRubyVersionsTool)
      server.register_tool(GetRubyVersionChangelogTool)
      server.register_tool(GetGemInfoTool)
      server.register_tool(GetGemReverseDependenciesTool)
      server.register_tool(GetGemVersionDownloadsTool)
      server.register_tool(GetLatestGemsTool)
      server.register_tool(GetRecentlyUpdatedGemsTool)
      server.register_tool(GetGemChangelogTool)
      server.register_tool(SearchGemsTool)
      server.register_tool(GetRubyRoadmapTool)
      server.register_tool(GetRubyVersionRoadmapDetailsTool)
      server.register_tool(GetRubyVersionGithubChangelogTool)
      server.register_tool(GetGemVersionInfoTool)
      server.register_tool(GetNewsReleasesTool)
      server.register_tool(GetPopularReleasesTool)
    end

    def self.register_resources(server)
      server.register_resource(PopularGemsResource)
      server.register_resource(RubyVersionCompatibilityResource)
      server.register_resource(RubyMaintenanceStatusResource)
      server.register_resource(LatestRubyVersionResource)
    end

    # Base tool class with common error handling
    #
    # Exceptions raised in tool #call methods are automatically caught by fast-mcp
    # and converted to MCP error results with the request ID preserved.
    # fast-mcp uses send_error_result(message, id) which sends a result with
    # isError: true, not a JSON-RPC error response.
    class BaseTool < FastMcp::Tool
      protected

      def get_client
        Client.new
      end
    end

    # Get latest versions for a list of gems with release dates
    class GetLatestVersionsTool < BaseTool
      tool_name "get_latest_versions"
      description "Get latest versions for a list of gems with release dates and licenses. Supports GraphQL-like field selection."

      arguments do
        required(:gem_names).array(:string, min_size?: 1).description("Array of gem names (e.g., ['rails', 'nokogiri', 'rack'])")
        optional(:fields).array(:string).description("GraphQL-like field selection. Available: name, version, release_date, license, built_at, prerelease, platform, ruby_version, rubygems_version, downloads_count, sha, spec_sha, requirements, metadata")
      end

      def call(gem_names:, fields: nil)
        get_client.get_latest_versions(gem_names, fields: fields)
      end
    end

    # Get all versions for a single gem
    class GetGemVersionsTool < BaseTool
      tool_name "get_gem_versions"
      description "Get all versions for a single gem with release dates and licenses, sorted by version descending. Supports GraphQL-like field selection."

      arguments do
        required(:gem_name).filled(:string).description("Gem name (e.g., 'rails')")
        optional(:limit).filled(:integer).description("Maximum number of versions to return (for pagination)")
        optional(:offset).filled(:integer).description("Number of versions to skip (for pagination)")
        optional(:sort).filled(:string).description("Sort order: version_desc, version_asc, date_desc, or date_asc (default: version_desc)")
        optional(:fields).array(:string).description("GraphQL-like field selection. Available: version, release_date, license, built_at, prerelease, platform, ruby_version, rubygems_version, downloads_count, sha, spec_sha, requirements, metadata")
      end

      def call(gem_name:, limit: nil, offset: 0, sort: "version_desc", fields: nil)
        valid_sorts = %w[version_desc version_asc date_desc date_asc]
        sort_value = sort.to_s
        sort_sym = if valid_sorts.include?(sort_value)
          sort_value.to_sym
        else
          :version_desc
        end
        get_client.get_gem_versions(gem_name, limit: limit, offset: offset, sort: sort_sym, fields: fields)
      end
    end

    # Get latest Ruby version with release date
    class GetLatestRubyVersionTool < BaseTool
      tool_name "get_latest_ruby_version"
      description "Get latest Ruby version with release date"

      arguments do
        # No arguments required
      end

      def call
        get_client.get_latest_ruby_version
      end
    end

    # Get all Ruby versions with release dates
    class GetRubyVersionsTool < BaseTool
      tool_name "get_ruby_versions"
      description "Get all Ruby versions with release dates, download URLs, and release notes URLs, sorted by version descending"

      arguments do
        optional(:limit).filled(:integer).description("Maximum number of versions to return (for pagination)")
        optional(:offset).filled(:integer).description("Number of versions to skip (for pagination)")
        optional(:sort).filled(:string).description("Sort order: version_desc, version_asc, date_desc, or date_asc (default: version_desc)")
      end

      def call(limit: nil, offset: 0, sort: "version_desc")
        valid_sorts = %w[version_desc version_asc date_desc date_asc]
        sort_value = sort.to_s
        sort_sym = if valid_sorts.include?(sort_value)
          sort_value.to_sym
        else
          :version_desc
        end
        get_client.get_ruby_versions(limit: limit, offset: offset, sort: sort_sym)
      end
    end

    # Get changelog summary for a Ruby version
    class GetRubyVersionChangelogTool < BaseTool
      tool_name "get_ruby_version_changelog"
      description "Get changelog summary for a specific Ruby version by fetching and parsing the release notes"

      arguments do
        required(:version).filled(:string).description("Ruby version (e.g., '3.4.7')")
      end

      def call(version:)
        result = get_client.get_ruby_version_changelog(version)
        # Convert content to MCP-compliant format
        # MCP expects content to be an array of content items with type and text fields
        if result.is_a?(Hash)
          if result[:content].is_a?(String) && !result[:content].empty?
            result[:content] = [{type: "text", text: result[:content]}]
          elsif result[:content].is_a?(String) && result[:content].empty?
            result[:content] = []
          elsif result[:content].nil?
            result[:content] = []
          elsif result[:content].is_a?(Array)
            # Ensure array elements have the correct format
            result[:content] = result[:content].map do |item|
              if item.is_a?(String)
                {type: "text", text: item}
              elsif item.is_a?(Hash) && !item.key?(:type)
                item.merge(type: "text")
              else
                item
              end
            end
          end
        end
        result
      end
    end

    # Get gem information (summary, homepage, etc.)
    class GetGemInfoTool < BaseTool
      tool_name "get_gem_info"
      description "Get detailed information about a gem (summary, homepage, source code, documentation, licenses, authors, dependencies, downloads). Supports GraphQL-like field selection."

      arguments do
        required(:gem_name).filled(:string).description("Gem name (e.g., 'rails')")
        optional(:fields).array(:string).description("GraphQL-like field selection. Available: name, version, summary, description, homepage, source_code, documentation, licenses, authors, info, downloads, version_downloads, yanked, dependencies, changelog_uri, funding_uri, platform, sha, spec_sha, metadata")
      end

      def call(gem_name:, fields: nil)
        get_client.get_gem_info(gem_name, fields: fields)
      end
    end

    # Get detailed information for a specific gem version
    class GetGemVersionInfoTool < BaseTool
      tool_name "get_gem_version_info"
      description "Get detailed information for a specific gem version using RubyGems API v2. Returns version-specific details including download counts, dependencies, SHA checksums, and creation date for that exact version."

      arguments do
        required(:gem_name).filled(:string).description("Gem name (e.g., 'devise')")
        required(:version).filled(:string).description("Version string (e.g., '0.1.0', '4.9.4')")
        optional(:fields).array(:string).description("GraphQL-like field selection. Available: name, version, summary, description, homepage, source_code, documentation, licenses, authors, info, downloads, version_downloads, yanked, dependencies, changelog_uri, funding_uri, platform, sha, spec_sha, metadata, version_created_at, built_at, prerelease, rubygems_version, ruby_version, requirements, gem_uri, project_uri, wiki_uri, mailing_list_uri, bug_tracker_uri")
      end

      def call(gem_name:, version:, fields: nil)
        get_client.get_gem_version_info(gem_name, version, fields: fields)
      end
    end

    # Get reverse dependencies (gems that depend on this gem)
    class GetGemReverseDependenciesTool < BaseTool
      tool_name "get_gem_reverse_dependencies"
      description "Get reverse dependencies - list of gems that depend on the specified gem"

      arguments do
        required(:gem_name).filled(:string).description("Gem name (e.g., 'rails')")
      end

      def call(gem_name:)
        get_client.get_gem_reverse_dependencies(gem_name)
      end
    end

    # Get download statistics for a gem version
    class GetGemVersionDownloadsTool < BaseTool
      tool_name "get_gem_version_downloads"
      description "Get download statistics for a specific gem version"

      arguments do
        required(:gem_name).filled(:string).description("Gem name (e.g., 'rails')")
        required(:version).filled(:string).description("Gem version (e.g., '7.1.0')")
      end

      def call(gem_name:, version:)
        get_client.get_gem_version_downloads(gem_name, version)
      end
    end

    # Get latest gems (most recently added)
    class GetLatestGemsTool < BaseTool
      tool_name "get_latest_gems"
      description "Get latest gems - most recently added gems to RubyGems.org"

      arguments do
        optional(:limit).filled(:integer).description("Maximum number of gems to return (default: 30, max: 50)")
      end

      def call(limit: 30)
        get_client.get_latest_gems(limit: limit)
      end
    end

    # Get recently updated gems
    class GetRecentlyUpdatedGemsTool < BaseTool
      tool_name "get_recently_updated_gems"
      description "Get recently updated gems - most recently updated gem versions"

      arguments do
        optional(:limit).filled(:integer).description("Maximum number of gems to return (default: 30, max: 50)")
      end

      def call(limit: 30)
        get_client.get_recently_updated_gems(limit: limit)
      end
    end

    # Get changelog summary for a gem
    class GetGemChangelogTool < BaseTool
      tool_name "get_gem_changelog"
      description "Get changelog summary for a gem by fetching and parsing the changelog from its changelog_uri"

      arguments do
        required(:gem_name).filled(:string).description("Gem name (e.g., 'rails')")
        optional(:version).filled(:string).description("Gem version (optional, uses latest if not provided)")
      end

      def call(gem_name:, version: nil)
        get_client.get_gem_changelog(gem_name, version: version)
      end
    end

    # Search for gems by name
    class SearchGemsTool < BaseTool
      tool_name "search_gems"
      description "Search for gems by name on RubyGems"

      arguments do
        required(:query).filled(:string).description("Search query (e.g., 'rails')")
        optional(:page).filled(:integer).description("Page number (1-based). If provided, overrides offset")
        optional(:limit).filled(:integer).description("Maximum number of results to return")
        optional(:offset).filled(:integer).description("Number of results to skip (for pagination)")
      end

      def call(query:, page: nil, limit: nil, offset: 0)
        get_client.search_gems(query, page: page, limit: limit, offset: offset)
      end
    end

    # Get news releases (all new gem releases)
    class GetNewsReleasesTool < BaseTool
      tool_name "get_news_releases"
      description "Get news releases - all new gem releases from RubyGems.org with pagination"

      arguments do
        optional(:page).filled(:integer).description("Page number (1-based, default: 1)")
      end

      def call(page: 1)
        get_client.get_news_releases(page: page)
      end
    end

    # Get popular releases (popular new gem releases)
    class GetPopularReleasesTool < BaseTool
      tool_name "get_popular_releases"
      description "Get popular releases - popular new gem releases from RubyGems.org with pagination"

      arguments do
        optional(:page).filled(:integer).description("Page number (1-based, default: 1)")
      end

      def call(page: 1)
        get_client.get_popular_releases(page: page)
      end
    end

    # Get Ruby roadmap information
    class GetRubyRoadmapTool < BaseTool
      tool_name "get_ruby_roadmap"
      description "Get Ruby roadmap information from bugs.ruby-lang.org showing planned versions and their issues"

      arguments do
        # No arguments required
      end

      def call
        get_client.get_ruby_roadmap
      end
    end

    # Get detailed roadmap information for a specific Ruby version
    class GetRubyVersionRoadmapDetailsTool < BaseTool
      tool_name "get_ruby_version_roadmap_details"
      description "Get detailed roadmap information for a specific Ruby version from bugs.ruby-lang.org, including issues and features planned for that version"

      arguments do
        required(:version).filled(:string).description("Ruby version (e.g., '3.4', '4.0')")
      end

      def call(version:)
        get_client.get_ruby_version_roadmap_details(version)
      end
    end

    # Get GitHub release changelog for a Ruby version
    class GetRubyVersionGithubChangelogTool < BaseTool
      tool_name "get_ruby_version_github_changelog"
      description "Get GitHub release changelog for a Ruby version from the ruby/ruby repository"

      arguments do
        required(:version).filled(:string).description("Ruby version (e.g., '3.4.7', '3.4.0')")
      end

      def call(version:)
        get_client.get_ruby_version_github_changelog(version)
      end
    end

    # Resource: Popular Ruby gems list with real-time data
    class PopularGemsResource < FastMcp::Resource
      uri "rubygems://popular"
      resource_name "Popular Ruby Gems"
      description "Popular new gem releases from RubyGems.org with their versions, download counts, and metadata"
      mime_type "application/json"

      def content
        client = Client.new
        # Get popular releases from the first 3 pages (up to ~30 gems)
        all_releases = []
        (1..3).each do |page|
          releases = client.get_popular_releases(page: page)
          break if releases.empty?
          all_releases.concat(releases)
        rescue
          # If a page fails, continue with what we have
          break
        end

        # Limit to top 20 most popular by downloads
        gems_data = all_releases
          .select { |g| g[:downloads] && g[:downloads] > 0 }
          .sort_by { |g| g[:downloads] || 0 }
          .last(20).reverse
          .map do |release|
            {
              name: release[:name],
              version: release[:version],
              release_date: release[:release_date],
              downloads: release[:downloads],
              info: release[:info],
              gem_url: release[:gem_url]
            }
          end

        result = {
          updated_at: Time.now.iso8601,
          total_gems: gems_data.length,
          source: "rubygems.org/releases/popular",
          gems: gems_data
        }

        JSON.pretty_generate(result)
      end
    end

    # Resource: Ruby version compatibility information
    class RubyVersionCompatibilityResource < FastMcp::Resource
      uri "rubygems://ruby/compatibility"
      resource_name "Ruby Version Compatibility"
      description "Information about Ruby version compatibility and release dates"
      mime_type "application/json"

      def content
        client = Client.new
        ruby_versions = client.get_ruby_versions(limit: 20, sort: :version_desc)
        latest = client.get_latest_ruby_version
        maintenance_status = client.get_ruby_maintenance_status

        # Create a map of version to maintenance status for quick lookup
        maintenance_status.each_with_object({}) do |status, map|
          map[status[:version]] = status
        end

        data = {
          latest: latest,
          recent_versions: ruby_versions,
          maintenance_status: maintenance_status.first(10), # Most recent 10 versions
          compatibility_notes: {
            "3.4.x" => "Latest stable series. Normal maintenance. Supports all modern gems.",
            "3.3.x" => "Stable series. Normal maintenance until 2027. Well-supported by most gems.",
            "3.2.x" => "Security maintenance only. EOL expected 2026-03-31.",
            "3.1.x" => "End of life (EOL: 2025-03-26). No longer supported.",
            "3.0.x" => "End of life (EOL: 2024-04-23). No longer supported.",
            "2.7.x" => "End of life. No longer supported."
          }
        }

        JSON.pretty_generate(data)
      end
    end

    # Resource: Ruby maintenance status for all versions
    class RubyMaintenanceStatusResource < FastMcp::Resource
      uri "rubygems://ruby/maintenance"
      resource_name "Ruby Maintenance Status"
      description "Detailed maintenance status for all Ruby versions including EOL dates and maintenance phases"
      mime_type "application/json"

      def content
        client = Client.new
        maintenance_status = client.get_ruby_maintenance_status

        data = {
          updated_at: Time.now.iso8601,
          versions: maintenance_status,
          summary: {
            preview: maintenance_status.count { |v| v[:status] == "preview" },
            normal_maintenance: maintenance_status.count { |v| v[:status] == "normal maintenance" },
            security_maintenance: maintenance_status.count { |v| v[:status] == "security maintenance" },
            eol: maintenance_status.count { |v| v[:status] == "eol" }
          }
        }

        JSON.pretty_generate(data)
      end
    end

    # Resource: Latest Ruby version with additional context
    class LatestRubyVersionResource < FastMcp::Resource
      uri "rubygems://ruby/latest"
      resource_name "Latest Ruby Version"
      description "The latest stable Ruby version with release date, maintenance status, and compatibility information"
      mime_type "application/json"

      def content
        client = Client.new
        latest = client.get_latest_ruby_version
        maintenance_status = client.get_ruby_maintenance_status

        # Find maintenance info for the latest version
        latest_major_minor = latest[:version]&.match(/^(\d+\.\d+)/)&.[](1)
        maintenance_info = maintenance_status.find { |m| m[:version] == latest_major_minor } if latest_major_minor

        result = {
          version: latest[:version],
          release_date: latest[:release_date],
          maintenance_status: maintenance_info&.dig(:status),
          normal_maintenance_until: maintenance_info&.dig(:normal_maintenance_until),
          eol: maintenance_info&.dig(:eol),
          updated_at: Time.now.iso8601
        }

        JSON.pretty_generate(result)
      end
    end
  end
end
