# Changelog destination policy

## Decisions

Gem-provided changelog metadata is treated as untrusted input. Changelog fetches permit HTTPS only, require a host on the GitHub, GitLab, RubyGems, or ruby-lang.org suffix list, reject URL credentials and private or reserved network destinations, fail closed when DNS cannot be resolved, and pin the validated address for the connection. Host allowlist runs before DNS.

## Effects

A gem author can no longer direct get_gem_changelog to HTTP, loopback, internal services, or an off-list host. Fetch results include source_host. The behavioral suite covers HTTP scheme refusal, allowlist before DNS, userinfo, private destinations, and normal public changelog parsing with deterministic DNS doubles.

## Next

Route any future changelog redirects through the same policy.

## Source

- lib/rubygems_mcp/network_policy.rb
- lib/rubygems_mcp/client.rb
- spec/rubygems_mcp/client_spec.rb
- spec/rubygems_mcp/network_policy_spec.rb
