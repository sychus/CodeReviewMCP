# Contributing to CodeReview MCP Claude

First off, thank you for considering contributing to CodeReview MCP Claude! 🎉

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps which reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed after following the steps**
- **Explain which behavior you expected to see instead and why**
- **Include screenshots and animated GIFs if applicable**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a step-by-step description of the suggested enhancement**
- **Provide specific examples to demonstrate the steps**
- **Describe the current behavior and explain which behavior you expected to see instead**
- **Explain why this enhancement would be useful**

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code lints
6. Issue that pull request!

## Development Process

### Setting Up Development Environment

1. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR-USERNAME/codereview-mcp-claude-code.git
   cd codereview-mcp-claude-code
   ```

2. **Install dependencies:**
   ```bash
   # Install Claude CLI if not already installed
   npm install -g claude-cli
   ```

3. **Make the script executable:**
   ```bash
   chmod +x codereview.sh
   ```

### Testing Your Changes

Before submitting a pull request, please test your changes:

```bash
# Test script syntax
bash -n codereview.sh

# Test with a sample PR
./codereview.sh review.md https://github.com/octocat/Hello-World/pull/1
```

### Coding Standards

- **Shell Scripts**: Follow [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Documentation**: Use clear, concise language with examples
- **Comments**: Add comments for complex logic
- **Error Handling**: Include proper error handling and user feedback

### Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples:
- `feat: add support for GitLab MCP integration`
- `fix: handle empty PR descriptions gracefully`
- `docs: update installation instructions`
- `refactor: simplify error handling logic`

## Project Structure

```
codereview-mcp-claude-code/
├── codereview.sh           # Main automation script
├── review.md               # Default review guidelines  
├── .gitignore             # Git ignore patterns
├── README.md              # Project documentation
├── LICENSE                # MIT license
├── CONTRIBUTING.md        # This file
└── examples/              # Example configurations (optional)
```

## Areas for Contribution

### High Priority
- [ ] GitHub Actions CI/CD pipeline
- [ ] Comprehensive test suite
- [ ] Support for other MCP servers (GitLab, Bitbucket)
- [ ] Template system for different review types

### Medium Priority
- [ ] Configuration file support (YAML/JSON)
- [ ] Batch processing multiple PRs
- [ ] Review analytics and reporting
- [ ] Integration with popular IDEs

### Documentation
- [ ] Video tutorials
- [ ] Advanced usage examples
- [ ] Troubleshooting guide
- [ ] Best practices documentation

## Getting Help

- **Documentation**: Check the [README](README.md) and [Wiki](https://github.com/sychus/codereview-mcp-claude-code/wiki)
- **Discussions**: Use [GitHub Discussions](https://github.com/sychus/codereview-mcp-claude-code/discussions) for questions
- **Issues**: Create an issue for bugs or feature requests

## Recognition

Contributors will be recognized in our README and releases. We appreciate all forms of contribution, from code to documentation to community support!

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
