require "uri"
require "net/http"
require "json"
require "date"

require_relative "rubygems_mcp/version"
require_relative "rubygems_mcp/errors"
require_relative "rubygems_mcp/client"
# Server is loaded on-demand when running the executable
# require_relative "rubygems_mcp/server"

module RubygemsMcp
  # Main module for RubyGems MCP integration
  #
  # This gem provides:
  # - RubygemsMcp::Client - API client for RubyGems and Ruby version information
  #
  # @example Basic usage
  #   require "rubygems_mcp"
  #
  #   # Create client
  #   client = RubygemsMcp::Client.new
  #
  #   # Get latest versions for multiple gems
  #   versions = client.get_latest_versions(["rails", "nokogiri", "rack"])
  #
  #   # Get all versions for a gem
  #   versions = client.get_gem_versions("rails")
  #
  #   # Get latest Ruby version
  #   ruby_version = client.get_latest_ruby_version
end
