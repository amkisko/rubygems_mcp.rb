# Security Policy

## Supported Versions

We actively support the following versions of `rubygems_mcp` with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in `rubygems_mcp`, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email security details to: **contact@kiskolabs.com**
3. Include the following information:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### Response Timeline

- We will acknowledge receipt of your report within **48 hours**
- We will provide an initial assessment within **7 days**
- We will keep you informed of our progress and resolution timeline

### Disclosure Policy

- We will work with you to understand and resolve the issue quickly
- We will credit you for the discovery (unless you prefer to remain anonymous)
- We will publish a security advisory after the vulnerability is patched
- We will coordinate public disclosure with you

## Security Considerations

### API Access

This gem accesses public RubyGems and Ruby version information via public APIs. No authentication is required as all endpoints are public.

**What this gem does:**
- Fetches public gem information from RubyGems API
- Fetches public Ruby version information from ruby-lang.org
- Provides MCP server tools for querying this information

**What this gem does NOT do:**
- Store or cache sensitive data
- Require authentication or API keys
- Access private or protected resources
- Execute arbitrary code or commands

### Network Security

- All API requests use HTTPS
- The gem validates SSL certificates by default
- Network requests are made to trusted public endpoints (rubygems.org, ruby-lang.org)

### Input Validation

- Gem names and search queries are validated before making API requests
- URL parameters are properly encoded
- The gem handles network errors and malformed responses gracefully

### Dependency Security

Keep dependencies up to date:

```bash
# Check for security vulnerabilities
bundle audit

# Update dependencies regularly
bundle update
```

## Security Updates

Security updates will be released as patch versions (e.g., 0.1.0 → 0.1.1) for supported versions.

For critical security vulnerabilities, we may release a security advisory and recommend immediate upgrade.

## Additional Resources

- [RubyGems Security](https://guides.rubygems.org/security/)
- [Ruby Security Guide](https://www.ruby-lang.org/en/documentation/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

## Contact

For security concerns, contact: **contact@kiskolabs.com**

For general support, open an issue on GitHub: https://github.com/amkisko/rubygems_mcp.rb/issues

