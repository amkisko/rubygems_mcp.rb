#!/usr/bin/env ruby
# frozen_string_literal: true

require "fast_mcp"
require "rubygems_mcp"
require "logger"
require "stringio"
require "securerandom"

# Alias MCP to FastMcp for compatibility
FastMcp = MCP unless defined?(FastMcp)

# Monkey-patch fast-mcp to ensure error responses always have a valid id
# JSON-RPC 2.0 allows id: null for notifications, but MCP clients (Cursor/Inspector)
# use strict Zod validation that requires id to be a string or number
module MCP
  module Transports
    class StdioTransport
      if method_defined?(:send_error)
        alias_method :original_send_error, :send_error

        def send_error(code, message, id = nil)
          # Use placeholder id if nil to satisfy strict MCP client validation
          # JSON-RPC 2.0 allows null for notifications, but MCP clients require valid id
          id = "error_#{SecureRandom.hex(8)}" if id.nil?
          original_send_error(code, message, id)
        end
      end
    end
  end

  class Server
    if method_defined?(:send_error)
      alias_method :original_send_error, :send_error

      def send_error(code, message, id = nil)
        # Use placeholder id if nil to satisfy strict MCP client validation
        # JSON-RPC 2.0 allows null for notifications, but MCP clients require valid id
        id = "error_#{SecureRandom.hex(8)}" if id.nil?
        original_send_error(code, message, id)
      end
    end
  end
end

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
        get_client.get_ruby_version_changelog(version)
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
      end

      def call(query:)
        get_client.search_gems(query)
      end
    end

    # Resource: Popular Ruby gems list
    class PopularGemsResource < FastMcp::Resource
      uri "rubygems://popular"
      resource_name "Popular Ruby Gems"
      description "A curated list of popular Ruby gems with their latest versions"
      mime_type "application/json"

      def content
        client = Client.new
        popular_gems = %w[
          rails nokogiri bundler rake rspec devise puma sidekiq
          pg mysql2 redis json webrick sinatra haml sass
          jekyll octokit faraday httparty rest-client
        ]

        gems_data = popular_gems.map do |gem_name|
          versions = client.get_gem_versions(gem_name, limit: 1, fields: ["name", "version", "release_date"])
          latest = versions.first
          if latest
            result = latest.dup
            result[:name] = gem_name
            result
          else
            {name: gem_name, version: nil, release_date: nil}
          end
        rescue Client::ResponseSizeExceededError, Client::CorruptedDataError => e
          # Skip gems that exceed size limit or have corrupted data
          {name: gem_name, version: nil, release_date: nil, error: e.message}
        end

        # Filter out gems that weren't found (nil versions)
        gems_data = gems_data.reject { |g| g[:version].nil? }
        JSON.pretty_generate(gems_data)
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

    # Resource: Latest Ruby version
    class LatestRubyVersionResource < FastMcp::Resource
      uri "rubygems://ruby/latest"
      resource_name "Latest Ruby Version"
      description "The latest stable Ruby version with release date"
      mime_type "application/json"

      def content
        client = Client.new
        latest = client.get_latest_ruby_version
        JSON.pretty_generate(latest)
      end
    end
  end
end
