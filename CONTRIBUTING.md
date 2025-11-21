# Contributing to rubygems_mcp

Thank you for your interest in contributing to `rubygems_mcp`! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Ruby version and gem version
- Any relevant error messages or logs

### Suggesting Features

Feature suggestions are welcome! Please open an issue to discuss:
- The use case or problem you're trying to solve
- How the feature would work
- Any potential implementation considerations

**Note**: New features are not necessarily added to the gem. We prioritize stability and maintainability.

### Pull Requests

Pull requests are welcome! Please follow these guidelines:

#### Before Submitting

1. **Fork the repository** and create a topic branch from `main`
2. **Run the test suite** to ensure everything passes:
   ```bash
   bundle install
   bundle exec rspec
   ```
3. **Run linting** and fix any issues:
   ```bash
   bundle exec standardrb --fix
   ```
4. **Validate RBS type signatures**:
   ```bash
   bundle exec rbs validate
   ```
5. **Add test coverage** for any new functionality or bug fixes
6. **Update the CHANGELOG.md** with a brief description of your changes

#### Pull Request Requirements

- **Test Coverage**: Pull requests should have test coverage for affected parts
- **Changelog Entry**: Pull requests should include a changelog entry in `CHANGELOG.md`
- **Code Style**: Follow the existing code style (enforced by StandardRB)
- **Type Signatures**: Update RBS type signatures if you modify public APIs
- **Documentation**: Update README.md if you add new features or change behavior

#### Review Policy

Please be patient with reviews:
- Critical fixes: Up to 2 calendar weeks to review and merge
- Regular pull requests: Up to 6 calendar months to review and merge
- Issues: Up to 1 calendar year to review

## Development Setup

### Prerequisites

- Ruby 3.1 or higher
- Bundler

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/amkisko/rubygems_mcp.rb.git
   cd rubygems_mcp.rb
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Run tests:
   ```bash
   bundle exec rspec
   ```

4. Run tests across multiple Ruby versions:
   ```bash
   bundle exec appraisal install
   bundle exec appraisal rspec
   ```

5. Run linting:
   ```bash
   bundle exec standardrb --fix
   ```

6. Validate RBS type signatures:
   ```bash
   bundle exec rbs validate
   ```

## Code Style

This project uses [StandardRB](https://github.com/standardrb/standard) for code formatting and linting. Run `bundle exec standardrb --fix` before committing.

## Testing

- Write tests for all new functionality
- Ensure all tests pass before submitting a pull request
- Use RSpec for testing
- Mock external API calls using WebMock and VCR

## Type Signatures

This project uses RBS (Ruby Type Signatures) for type checking. When modifying public APIs:

1. Update the corresponding `.rbs` file in the `sig/` directory
2. Run `bundle exec rbs validate` to check for errors
3. Ensure type signatures accurately reflect the code

## Commit Messages

Write clear, descriptive commit messages:
- Use the imperative mood ("Add feature" not "Added feature")
- Reference issue numbers when applicable
- Keep the first line under 72 characters
- Add more details in the body if needed

Example:
```
Add support for gem search functionality

Implements the search_gems method to query RubyGems API
for gem search. Includes tests and RBS type signatures.

Fixes #123
```

## Questions?

If you have questions about contributing, please:
- Open an issue on GitHub
- Check the existing issues and discussions

Thank you for contributing to `rubygems_mcp`! 🎉

