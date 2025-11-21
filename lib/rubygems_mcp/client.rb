require "uri"
require "net/http"
require "openssl"
require "json"
require "date"
require "nokogiri"

module RubygemsMcp
  # RubyGems and Ruby version API client
  #
  # @example
  #   client = RubygemsMcp::Client.new
  #   versions = client.get_latest_versions(["rails", "nokogiri"])
  #   all_versions = client.get_gem_versions("rails")
  #   ruby_version = client.get_latest_ruby_version
  class Client
    # Maximum response size (1MB) to protect against crawler protection pages
    MAX_RESPONSE_SIZE = 1024 * 1024 # 1MB

    # Custom exception for corrupted data
    class CorruptedDataError < StandardError
      attr_reader :original_error, :response_size

      def initialize(message, original_error: nil, response_size: nil)
        super(message)
        @original_error = original_error
        @response_size = response_size
      end
    end

    # Custom exception for response size exceeded
    class ResponseSizeExceededError < StandardError
      attr_reader :size, :max_size

      def initialize(size, max_size)
        @size = size
        @max_size = max_size
        super("Response size (#{size} bytes) exceeds maximum allowed size (#{max_size} bytes). This may indicate crawler protection.")
      end
    end
    RUBYGEMS_API_BASE = "https://rubygems.org/api/v1"
    RUBY_RELEASES_URL = "https://www.ruby-lang.org/en/downloads/releases/"
    RUBY_BRANCHES_URL = "https://www.ruby-lang.org/en/downloads/branches/"

    # Simple in-memory cache with TTL
    class Cache
      def initialize
        @cache = {}
        @mutex = Mutex.new
      end

      def get(key)
        @mutex.synchronize do
          entry = @cache[key]
          return nil unless entry

          if entry[:expires_at] < Time.now
            @cache.delete(key)
            return nil
          end

          entry[:value]
        end
      end

      def set(key, value, ttl_seconds)
        @mutex.synchronize do
          @cache[key] = {
            value: value,
            expires_at: Time.now + ttl_seconds
          }
        end
      end

      def clear
        @mutex.synchronize { @cache.clear }
      end
    end

    # Shared cache instance
    @cache = Cache.new

    class << self
      attr_reader :cache
    end

    def initialize(cache_enabled: true)
      @cache_enabled = cache_enabled
    end

    # Get latest versions for a list of gems with release dates
    #
    # @param gem_names [Array<String>] Array of gem names
    # @param fields [Array<String>, nil] GraphQL-like field selection (nil = all fields)
    #   Available fields: name, version, release_date, license, built_at, prerelease, platform,
    #   ruby_version, rubygems_version, downloads_count, sha, spec_sha, requirements, metadata
    # @return [Array<Hash>] Array of hashes with selected fields
    def get_latest_versions(gem_names, fields: nil)
      gem_names.map do |name|
        versions = get_gem_versions(name, limit: 1, fields: fields)
        latest = versions.first # Versions are sorted by version number descending
        if latest
          result = latest.dup
          result[:name] = name
          result
        else
          base_result = {name: name, version: nil, release_date: nil, license: nil}
          select_fields([base_result], fields).first || base_result
        end
      end
    end

    # Get all versions for a single gem
    #
    # @param gem_name [String] Gem name
    # @param limit [Integer, nil] Maximum number of versions to return (nil = all)
    # @param offset [Integer] Number of versions to skip (for pagination)
    # @param sort [Symbol] Sort order: :version_desc (default), :version_asc, :date_desc, :date_asc
    # @param fields [Array<String>, nil] GraphQL-like field selection (nil = all fields)
    #   Available fields: version, release_date, license, built_at, prerelease, platform,
    #   ruby_version, rubygems_version, downloads_count, sha, spec_sha, requirements, metadata
    # @return [Array<Hash>] Array of hashes with selected fields
    def get_gem_versions(gem_name, limit: nil, offset: 0, sort: :version_desc, fields: nil)
      cache_key = "gem_versions:#{gem_name}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        if cached
          result = apply_pagination_and_sort(cached, limit: limit, offset: offset, sort: sort)
          return select_fields(result, fields) if fields
          return result
        end
      end

      uri = URI("#{RUBYGEMS_API_BASE}/versions/#{gem_name}.json")

      response = make_request(uri)

      # Validate response is an Array (get_gem_versions expects Array)
      unless response.is_a?(Array)
        raise CorruptedDataError.new(
          "Invalid JSON structure: expected Array, got #{response.class}",
          response_size: response.to_s.bytesize
        )
      end

      return [] if response.empty?

      versions = response.map do |version_data|
        original_version = version_data["number"]
        next unless original_version.match?(/^\d+\.\d+\.\d+$/)

        version = Gem::Version.new(original_version)
        release_date = version_data["created_at"] ? Date.parse(version_data["created_at"]) : nil
        built_at = version_data["built_at"] ? Date.parse(version_data["built_at"]) : nil

        version_hash = {
          version: version.to_s,
          release_date: release_date&.iso8601,
          built_at: built_at&.iso8601,
          license: version_data["licenses"]&.first,
          prerelease: version_data["prerelease"] || false,
          platform: version_data["platform"] || "ruby",
          ruby_version: version_data["ruby_version"],
          rubygems_version: version_data["rubygems_version"],
          downloads_count: version_data["downloads_count"],
          sha: version_data["sha"],
          spec_sha: version_data["spec_sha"],
          requirements: version_data["requirements"] || [],
          metadata: version_data["metadata"] || {}
        }

        version_hash
      end

      versions = versions.compact

      # Cache for 1 hour (gem versions don't change once published)
      self.class.cache.set(cache_key, versions, 3600) if @cache_enabled

      result = apply_pagination_and_sort(versions, limit: limit, offset: offset, sort: sort)
      select_fields(result, fields)
    end

    # Get latest Ruby version with release date
    #
    # @return [Hash] Hash with :version and :release_date (as ISO 8601 string)
    def get_latest_ruby_version
      versions = get_ruby_versions
      versions.first || {version: nil, release_date: nil}
    end

    # Get Ruby maintenance status for all versions
    #
    # @return [Array<Hash>] Array of hashes with maintenance information:
    #   - :version (String) - Ruby version (e.g., "3.4", "3.3")
    #   - :status (String) - Maintenance status: "normal maintenance", "security maintenance", "eol", or "preview"
    #   - :release_date (String, nil) - Release date as ISO 8601 string
    #   - :normal_maintenance_until (String, nil) - End of normal maintenance as ISO 8601 string or "TBD"
    #   - :eol (String, nil) - End of life date as ISO 8601 string or "TBD"
    def get_ruby_maintenance_status
      cache_key = "ruby_maintenance_status"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI(RUBY_BRANCHES_URL)
      response = make_request(uri, parse_html: true)
      return [] unless response

      maintenance_data = []

      # Find all h3 tags that contain Ruby version numbers
      response.css("h3").each do |h3|
        version_match = h3.text.match(/Ruby ([\d.]+)/)
        next unless version_match

        version = version_match[1]
        next unless version.match?(/^\d+\.\d+$/) # Match major.minor format

        # Find the following paragraph with maintenance info
        p_tag = h3.next_element
        next unless p_tag&.name == "p"

        status_text = p_tag.text

        # Extract status from the "status: ..." line specifically
        status_match = status_text.match(/status:\s*([^\n<]+)/i)
        status_value = status_match ? status_match[1].strip.downcase : ""

        # Parse status - check in order of specificity
        status = if status_value.include?("preview")
          "preview"
        elsif status_value.include?("eol") || status_value.include?("end-of-life")
          "eol"
        elsif status_value.include?("security")
          "security maintenance"
        elsif status_value.include?("normal")
          "normal maintenance"
        else
          "unknown"
        end

        # Parse release date
        release_date_match = status_text.match(/release date:\s*(\d{4}-\d{2}-\d{2})/i)
        release_date = release_date_match ? release_date_match[1] : nil

        # Parse normal maintenance until
        normal_maintenance_match = status_text.match(/normal maintenance until:\s*([^<\n]+)/i)
        normal_maintenance_until = if normal_maintenance_match
          date_str = normal_maintenance_match[1].strip
          (date_str == "TBD") ? "TBD" : begin
            Date.parse(date_str).iso8601
          rescue
            date_str
          end
        end

        # Parse EOL date
        eol_match = status_text.match(/EOL:\s*([^<\n]+)/i)
        eol = if eol_match
          date_str = eol_match[1].strip
          # Handle "2027-03-31 (expected)" format
          date_str = date_str.split("(").first.strip if date_str.include?("(")
          (date_str == "TBD") ? "TBD" : begin
            Date.parse(date_str).iso8601
          rescue
            date_str
          end
        end

        maintenance_data << {
          version: version,
          status: status,
          release_date: release_date,
          normal_maintenance_until: normal_maintenance_until,
          eol: eol
        }
      end

      # Sort by version descending
      maintenance_data.sort_by { |v| Gem::Version.new(v[:version]) }.reverse

      # Cache for 24 hours (maintenance status changes infrequently)
      self.class.cache.set(cache_key, maintenance_data, 86400) if @cache_enabled

      maintenance_data
    end

    # Get all Ruby versions with release dates
    #
    # @param limit [Integer, nil] Maximum number of versions to return (nil = all)
    # @param offset [Integer] Number of versions to skip (for pagination)
    # @param sort [Symbol] Sort order: :version_desc (default), :version_asc, :date_desc, :date_asc
    # @return [Array<Hash>] Array of hashes with :version and :release_date
    def get_ruby_versions(limit: nil, offset: 0, sort: :version_desc)
      cache_key = "ruby_versions"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return apply_pagination_and_sort(cached, limit: limit, offset: offset, sort: sort) if cached
      end

      uri = URI(RUBY_RELEASES_URL)

      response = make_request(uri, parse_html: true)
      return [] unless response

      versions = response.css("table.release-list tr").map do |element|
        version_match = element.css("td:nth-child(1)").text.match(/Ruby (.+)/)
        next if version_match.nil? || version_match[1].nil?

        version_string = version_match[1].strip
        next unless version_string.match?(/^\d+\.\d+\.\d+/)

        version = Gem::Version.new(version_string)
        release_date_text = element.css("td:nth-child(2)").text.strip
        release_date = begin
          Date.parse(release_date_text)
        rescue Date::Error
          nil
        end

        # Extract download URL
        download_link = element.css("td:nth-child(3) a").first
        download_url = download_link ? download_link["href"] : nil

        # Extract release notes URL (convert relative to absolute)
        release_notes_link = element.css("td:nth-child(4) a").first
        release_notes_url = if release_notes_link
          notes_href = release_notes_link["href"]
          notes_href.start_with?("http") ? notes_href : "https://www.ruby-lang.org#{notes_href}"
        end

        {
          version: version.to_s,
          release_date: release_date,
          download_url: download_url,
          release_notes_url: release_notes_url
        }
      end

      # Sort and convert dates to ISO 8601 strings for JSON serialization
      versions.compact.sort_by { |v| Gem::Version.new(v[:version]) }.reverse.map do |v|
        v[:release_date] = v[:release_date]&.iso8601
        v
      end
    end

    # Get full changelog content for a Ruby version from release notes
    #
    # @param version [String] Ruby version (e.g., "3.4.7")
    # @return [Hash] Hash with :version, :release_notes_url, and :content (full content)
    def get_ruby_version_changelog(version)
      # First get the release notes URL for this version
      versions = get_ruby_versions
      version_data = versions.find { |v| v[:version] == version }
      return {version: version, release_notes_url: nil, content: nil, error: "Version not found"} unless version_data

      release_notes_url = version_data[:release_notes_url]
      return {version: version, release_notes_url: nil, content: nil, error: "No release notes available"} unless release_notes_url

      cache_key = "ruby_changelog:#{version}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI(release_notes_url)
      response = make_request(uri, parse_html: true)
      return {version: version, release_notes_url: release_notes_url, content: nil, error: "Failed to fetch release notes"} unless response

      # Extract the main content - Ruby release notes use div#content
      content = response.css("div#content").first || response.css("div.content, div.entry-content, article, main").first

      if content
        # Remove navigation and metadata elements
        content.css("p.post-info, .post-info, nav, .navigation, header, footer, .sidebar").remove

        # Get the full text content, preserving structure
        text = content.text.strip

        # Clean up excessive whitespace but preserve paragraph structure
        text = text.gsub(/\n{3,}/, "\n\n")
        text = text.gsub(/[ \t]+/, " ")

        # Remove empty lines at start/end
        text = text.strip
      else
        text = nil
      end

      result = {
        version: version,
        release_notes_url: release_notes_url,
        content: text
      }

      # Cache for 24 hours
      self.class.cache.set(cache_key, result, 86400) if @cache_enabled

      result
    end

    # Get reverse dependencies (gems that depend on this gem)
    #
    # @param gem_name [String] Gem name
    # @return [Array<String>] Array of gem names that depend on this gem
    def get_gem_reverse_dependencies(gem_name)
      cache_key = "gem_reverse_deps:#{gem_name}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI("#{RUBYGEMS_API_BASE}/gems/#{gem_name}/reverse_dependencies.json")

      response = make_request(uri)
      return [] unless response.is_a?(Array)

      # Cache for 1 hour
      self.class.cache.set(cache_key, response, 3600) if @cache_enabled

      response
    end

    # Get download statistics for a specific gem version
    #
    # @param gem_name [String] Gem name
    # @param version [String] Gem version (e.g., "1.0.0")
    # @return [Hash] Hash with :version_downloads and :total_downloads
    def get_gem_version_downloads(gem_name, version)
      cache_key = "gem_downloads:#{gem_name}:#{version}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI("#{RUBYGEMS_API_BASE}/downloads/#{gem_name}-#{version}.json")

      response = make_request(uri)
      return {version_downloads: nil, total_downloads: nil} unless response.is_a?(Hash)

      result = {
        gem_name: gem_name,
        version: version,
        version_downloads: response["version_downloads"],
        total_downloads: response["total_downloads"]
      }

      # Cache for 1 hour
      self.class.cache.set(cache_key, result, 3600) if @cache_enabled

      result
    end

    # Get latest gems (most recently added)
    #
    # @param limit [Integer, nil] Maximum number of gems to return (default: 30, max: 50)
    # @return [Array<Hash>] Array of gem information
    def get_latest_gems(limit: 30)
      limit = [limit || 30, 50].min # API returns max 50
      cache_key = "latest_gems:#{limit}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI("#{RUBYGEMS_API_BASE}/activity/latest.json")

      response = make_request(uri)
      return [] unless response.is_a?(Array)

      gems = response.first(limit).map do |gem_data|
        {
          name: gem_data["name"],
          version: gem_data["version"],
          downloads: gem_data["downloads"],
          info: gem_data["info"],
          authors: gem_data["authors"],
          homepage: gem_data["homepage_uri"],
          source_code: gem_data["source_code_uri"],
          documentation: gem_data["documentation_uri"],
          licenses: gem_data["licenses"] || []
        }
      end

      # Cache for 15 minutes (activity changes frequently)
      self.class.cache.set(cache_key, gems, 900) if @cache_enabled

      gems
    end

    # Get recently updated gems
    #
    # @param limit [Integer, nil] Maximum number of gems to return (default: 30, max: 50)
    # @return [Array<Hash>] Array of gem version information
    def get_recently_updated_gems(limit: 30)
      limit = [limit || 30, 50].min # API returns max 50
      cache_key = "recently_updated_gems:#{limit}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI("#{RUBYGEMS_API_BASE}/activity/just_updated.json")

      response = make_request(uri)
      return [] unless response.is_a?(Array)

      gems = response.first(limit).map do |gem_data|
        {
          name: gem_data["name"],
          version: gem_data["version"],
          downloads: gem_data["downloads"],
          version_downloads: gem_data["version_downloads"],
          info: gem_data["info"],
          authors: gem_data["authors"],
          homepage: gem_data["homepage_uri"],
          source_code: gem_data["source_code_uri"],
          documentation: gem_data["documentation_uri"],
          licenses: gem_data["licenses"] || [],
          created_at: gem_data["created_at"]
        }
      end

      # Cache for 15 minutes (activity changes frequently)
      self.class.cache.set(cache_key, gems, 900) if @cache_enabled

      gems
    end

    # Get changelog summary for a gem from its changelog_uri
    #
    # @param gem_name [String] Gem name
    # @param version [String, nil] Gem version (optional, uses latest if not provided)
    # @return [Hash] Hash with :gem_name, :version, :changelog_uri, and :summary
    def get_gem_changelog(gem_name, version: nil)
      # Get gem info to find changelog_uri
      gem_info = get_gem_info(gem_name)
      return {gem_name: gem_name, version: nil, changelog_uri: nil, summary: nil, error: "Gem not found"} if gem_info.empty?

      version ||= gem_info[:version]
      changelog_uri = gem_info[:changelog_uri]

      return {gem_name: gem_name, version: version, changelog_uri: nil, summary: nil, error: "No changelog URI available"} unless changelog_uri

      cache_key = "gem_changelog:#{gem_name}:#{version}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        return cached if cached
      end

      uri = URI(changelog_uri)
      response = make_request(uri, parse_html: true)
      return {gem_name: gem_name, version: version, changelog_uri: changelog_uri, summary: nil, error: "Failed to fetch changelog"} unless response

      # Extract the main content - try GitHub release page first, then generic selectors
      content = if changelog_uri.include?("github.com") && changelog_uri.include?("/releases/")
        # GitHub release page - look for release notes in markdown-body
        response.css(".markdown-body").first ||
          response.css("[data-testid='release-body'], .release-body").first ||
          response.css("div.repository-content article").first
      else
        # Generic changelog page
        response.css("div.content, div.entry-content, article, main, .markdown-body").first
      end

      content ||= response.css("body").first

      summary = if content
        # Remove UI elements, navigation, and error messages
        content.css("nav, header, footer, .navigation, .sidebar, .blankslate, details, summary, .Box-footer, .Counter, [data-view-component], script, style").remove

        # Remove elements with common UI classes
        content.css("[class*='blankslate'], [class*='Box-footer'], [class*='Counter'], [class*='details-toggle']").remove

        # Get text content
        text = content.text.strip

        # Remove common GitHub UI text patterns
        text = text.gsub(/Notifications.*?signed in.*?reload/im, "")
        text = text.gsub(/You must be signed in.*?reload/im, "")
        text = text.gsub(/There was an error.*?reload/im, "")
        text = text.gsub(/Please reload this page.*?/im, "")
        text = text.gsub(/Loading.*?/im, "")
        text = text.gsub(/Uh oh!.*?/im, "")
        text = text.gsub(/Assets.*?\d+.*?/im, "")

        # Remove commit hashes and issue references that are just links without context
        text = text.gsub(/\b[a-f0-9]{7,40}\b/, "") # Remove commit hashes
        text = text.gsub(/#\d+\s*$/, "") # Remove trailing issue numbers without context

        # Clean up whitespace
        text = text.gsub(/\n{3,}/, "\n\n")
        text = text.gsub(/[ \t]{2,}/, " ")

        # Split into lines and filter out irrelevant content
        lines = text.split(/\n+/)

        # Filter out lines that are likely UI elements or irrelevant
        filtered_lines = []
        prev_line_was_meaningful = false

        lines.each_with_index do |line, idx|
          stripped = line.strip
          next if stripped.empty?

          # Skip UI elements
          next if stripped.match?(/^(Notifications|You must|There was|Please reload|Loading|Uh oh|Assets|\d+\s*$)/i)
          next if stripped.match?(/^\/\s*$/)
          next if stripped.match?(/^[a-f0-9]{7,40}$/) # Standalone commit hashes
          next if stripped.match?(/^\s*#\d+\s*$/) # Standalone issue numbers

          # Skip author names that appear alone (pattern: First Last or First Middle Last)
          # Author names typically appear after a change description ends with punctuation
          if stripped.match?(/^[A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,2}$/) && stripped.length < 50 && !stripped.match?(/^[A-Z][a-z]+ [A-Z]\./) # Not initials like "J. Smith"
            # Check if previous line ends with punctuation (end of sentence = author attribution follows)
            if idx > 0 && filtered_lines.any?
              prev = filtered_lines.last.to_s.strip
              # If previous line ends with punctuation, this standalone name is likely an author
              if prev.match?(/[.!]$/)
                next
              end
            elsif idx == 0
              # First line that's just a name, skip it
              next
            end
          end

          # Keep meaningful lines
          if stripped.length >= 10
            filtered_lines << line
            prev_line_was_meaningful = true
          end
        end

        # Remove trailing "No changes." and similar repetitive endings
        while filtered_lines.last&.strip&.match?(/^(No changes\.?|Guides)$/i)
          filtered_lines.pop
        end

        # Join back and clean up
        summary_text = filtered_lines.join("\n").strip

        # Remove excessive blank lines
        summary_text = summary_text.gsub(/\n{3,}/, "\n\n")

        # Limit length but keep it reasonable for changelogs
        if summary_text.length > 10000
          # Try to cut at a reasonable point (end of a section)
          cut_point = summary_text[0..10000].rindex(/\n\n/)
          summary_text = summary_text[0..(cut_point || 10000)].strip + "\n\n..."
        end

        summary_text.empty? ? nil : summary_text
      end

      result = {
        gem_name: gem_name,
        version: version,
        changelog_uri: changelog_uri,
        summary: summary
      }

      # Cache for 24 hours
      self.class.cache.set(cache_key, result, 86400) if @cache_enabled

      result
    end

    # Get gem information (summary, homepage, etc.)
    #
    # @param gem_name [String] Gem name
    # @param fields [Array<String>, nil] GraphQL-like field selection (nil = all fields)
    #   Available fields: name, version, summary, description, homepage, source_code,
    #   documentation, licenses, authors, info, downloads, version_downloads, yanked,
    #   dependencies, changelog_uri, funding_uri, platform, sha, spec_sha, metadata
    # @return [Hash] Hash with selected gem information
    def get_gem_info(gem_name, fields: nil)
      cache_key = "gem_info:#{gem_name}"

      if @cache_enabled
        cached = self.class.cache.get(cache_key)
        if cached
          return select_fields([cached], fields).first if fields
          return cached
        end
      end

      uri = URI("#{RUBYGEMS_API_BASE}/gems/#{gem_name}.json")

      response = make_request(uri)
      return {} unless response.is_a?(Hash)

      gem_info = {
        name: response["name"],
        version: response["version"],
        summary: response["summary"] || response["info"],
        description: response["description"],
        homepage: response["homepage_uri"],
        source_code: response["source_code_uri"],
        documentation: response["documentation_uri"],
        licenses: response["licenses"] || [],
        authors: response["authors"],
        info: response["info"],
        downloads: response["downloads"],
        version_downloads: response["version_downloads"],
        yanked: response["yanked"] || false,
        dependencies: response["dependencies"] || {runtime: [], development: []},
        changelog_uri: response["changelog_uri"] || response.dig("metadata", "changelog_uri"),
        funding_uri: response["funding_uri"] || response.dig("metadata", "funding_uri"),
        platform: response["platform"] || "ruby",
        sha: response["sha"],
        spec_sha: response["spec_sha"],
        metadata: response["metadata"] || {}
      }

      # Cache for 1 hour
      self.class.cache.set(cache_key, gem_info, 3600) if @cache_enabled

      select_fields([gem_info], fields).first || gem_info
    end

    # Search for gems by name
    #
    # @param query [String] Search query
    # @param limit [Integer, nil] Maximum number of results to return (nil = all)
    # @param offset [Integer] Number of results to skip (for pagination)
    # @return [Array<Hash>] Array of hashes with gem information
    def search_gems(query, limit: nil, offset: 0)
      # Don't cache search results as they can change frequently
      uri = URI("#{RUBYGEMS_API_BASE}/search.json")
      uri.query = URI.encode_www_form(query: query)

      response = make_request(uri)
      return [] unless response.is_a?(Array)

      results = response.map do |gem_data|
        {
          name: gem_data["name"],
          version: gem_data["version"],
          info: gem_data["info"],
          homepage: gem_data["homepage_uri"],
          source_code: gem_data["source_code_uri"],
          documentation: gem_data["documentation_uri"]
        }
      end

      # Apply pagination
      results = results[offset..] if offset > 0
      results = results.first(limit) if limit
      results
    end

    private

    # Apply pagination and sorting to a version array
    #
    # @param versions [Array<Hash>] Array of version hashes
    # @param limit [Integer, nil] Maximum number of versions to return
    # @param offset [Integer] Number of versions to skip
    # @param sort [Symbol] Sort order: :version_desc, :version_asc, :date_desc, :date_asc
    # @return [Array<Hash>] Paginated and sorted array
    def apply_pagination_and_sort(versions, limit: nil, offset: 0, sort: :version_desc)
      # Sort first
      sorted = case sort
      when :version_desc
        versions.sort_by { |v| Gem::Version.new(v[:version]) }.reverse
      when :version_asc
        versions.sort_by { |v| Gem::Version.new(v[:version]) }
      when :date_desc
        versions.sort_by { |v| v[:release_date] || "" }.reverse
      when :date_asc
        versions.sort_by { |v| v[:release_date] || "" }
      else
        versions.sort_by { |v| Gem::Version.new(v[:version]) }.reverse
      end

      # Apply pagination
      paginated = sorted[offset..] || []
      paginated = paginated.first(limit) if limit
      paginated
    end

    # GraphQL-like field selection
    #
    # @param data [Array<Hash>] Array of hashes to filter
    # @param fields [Array<String>, nil] Fields to include (nil = all fields)
    # @return [Array<Hash>] Filtered array with only selected fields
    def select_fields(data, fields)
      return data if fields.nil? || fields.empty?

      data.map do |item|
        item.select { |key, _| fields.include?(key.to_s) || fields.include?(key.to_sym) }
      end
    end

    # Build HTTP client
    #
    # @param uri [URI] URI object for the request
    # @return [Net::HTTP] Configured HTTP client
    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.open_timeout = 10

      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        # Set ca_file directly - this is the simplest and most reliable approach
        # Try SSL_CERT_FILE first, then default cert file
        ca_file = if ENV["SSL_CERT_FILE"] && File.file?(ENV["SSL_CERT_FILE"])
          ENV["SSL_CERT_FILE"]
        elsif File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
          OpenSSL::X509::DEFAULT_CERT_FILE
        end

        http.ca_file = ca_file if ca_file
      end

      http
    end

    def make_request(uri, parse_html: false)
      http = build_http_client(uri)

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = parse_html ? "text/html" : "application/json"
      request["User-Agent"] = "rubygems_mcp/#{RubygemsMcp::VERSION}"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        # Check response size before processing
        # Note: response.body may be nil for some responses, so check first
        response_body = response.body || ""
        response_size = response_body.bytesize
        if response_size > MAX_RESPONSE_SIZE
          raise ResponseSizeExceededError.new(response_size, MAX_RESPONSE_SIZE)
        end

        # Validate and parse response
        if parse_html
          validate_and_parse_html(response_body, uri)
        else
          validate_and_parse_json(response_body, uri)
        end
      when Net::HTTPNotFound
        raise "Resource not found. Response: #{response.body[0..500]}"
      else
        raise "API request failed: #{response.code} #{response.message}\n#{response.body[0..500]}"
      end
    rescue ResponseSizeExceededError, CorruptedDataError
      # Re-raise our custom errors as-is (don't cache corrupted data)
      raise
    rescue OpenSSL::SSL::SSLError => e
      raise "SSL verification failed: #{e.message}. This may be due to system certificate configuration issues."
    rescue => e
      raise "Request failed: #{e.class} - #{e.message}"
    end

    # Validate and parse JSON response
    # @param body [String] Response body
    # @param uri [URI] Request URI for error context
    # @return [Hash, Array] Parsed JSON data
    # @raise [CorruptedDataError] If JSON is invalid or corrupted
    def validate_and_parse_json(body, uri)
      # Check for common crawler protection patterns
      # Only check if body looks like HTML (starts with <) to avoid false positives
      if body.strip.start_with?("<") && body.match?(/cloudflare|ddos protection|access denied|blocked|captcha/i)
        raise CorruptedDataError.new(
          "Response appears to be a crawler protection page from #{uri}",
          response_size: body.bytesize
        )
      end

      begin
        parsed = JSON.parse(body)

        # Additional validation: ensure it's actually JSON data, not HTML error page
        unless parsed.is_a?(Hash) || parsed.is_a?(Array)
          raise CorruptedDataError.new(
            "Invalid JSON structure: expected Hash or Array, got #{parsed.class}",
            response_size: body.bytesize
          )
        end

        parsed
      rescue JSON::ParserError => e
        # Check if response is HTML (common for error pages)
        if body.strip.start_with?("<!DOCTYPE", "<html", "<HTML")
          raise CorruptedDataError.new(
            "Received HTML instead of JSON from #{uri}. This may indicate an error page or crawler protection.",
            original_error: e,
            response_size: body.bytesize
          )
        end

        raise CorruptedDataError.new(
          "Failed to parse JSON response from #{uri}: #{e.message}",
          original_error: e,
          response_size: body.bytesize
        )
      end
    end

    # Validate and parse HTML response
    # @param body [String] Response body
    # @param uri [URI] Request URI for error context
    # @return [Nokogiri::HTML::Document] Parsed HTML document
    # @raise [CorruptedDataError] If HTML is invalid or appears to be an error page
    def validate_and_parse_html(body, uri)
      # Check for common crawler protection patterns
      if body.match?(/cloudflare|ddos protection|access denied|blocked|captcha|rate limit/i)
        raise CorruptedDataError.new(
          "Response appears to be a crawler protection page from #{uri}",
          response_size: body.bytesize
        )
      end

      # Check if response is actually HTML
      unless body.strip.start_with?("<!DOCTYPE", "<html", "<HTML") || body.include?("<html")
        raise CorruptedDataError.new(
          "Response from #{uri} does not appear to be HTML",
          response_size: body.bytesize
        )
      end

      begin
        doc = Nokogiri::HTML(body)

        # Check if HTML is empty or appears to be an error page
        if doc.text.strip.length < 50
          raise CorruptedDataError.new(
            "HTML response from #{uri} appears to be empty or too short",
            response_size: body.bytesize
          )
        end

        # Check for common error page indicators
        error_indicators = [
          /error 404/i,
          /page not found/i,
          /access denied/i,
          /forbidden/i,
          /internal server error/i
        ]

        if error_indicators.any? { |pattern| doc.text.match?(pattern) }
          raise CorruptedDataError.new(
            "HTML response from #{uri} appears to be an error page",
            response_size: body.bytesize
          )
        end

        doc
      rescue Nokogiri::XML::SyntaxError => e
        raise CorruptedDataError.new(
          "Failed to parse HTML from #{uri}: #{e.message}",
          original_error: e,
          response_size: body.bytesize
        )
      end
    end
  end
end
