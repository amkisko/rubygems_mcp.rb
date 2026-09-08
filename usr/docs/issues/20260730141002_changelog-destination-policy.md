# Changelog destination policy

## Decisions

Gem-provided changelog metadata is treated as untrusted input. Changelog fetches permit only HTTP and HTTPS, reject URL credentials and private or reserved network destinations, fail closed when DNS cannot be resolved, and pin the validated address for the connection.

## Effects

A gem author can no longer direct get_gem_changelog to loopback or internal services. The behavioral suite covers literal private destinations, hostnames resolving privately, URL userinfo, and normal public changelog parsing with deterministic DNS doubles.

The compatible VCR/WebMock root graph was materialized and the complete make test command passed.

## Next

- Route any future changelog redirects through the same policy.
- Consider a recognized source-host allowlist if open-world changelog fetching is no longer required.

## Source

- lib/rubygems_mcp/network_policy.rb
- lib/rubygems_mcp/client.rb
- spec/rubygems_mcp/client_spec.rb
