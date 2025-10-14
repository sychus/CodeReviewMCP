/**
 * Example usage and testing for CodeReview API
 */

// Example 1: Structured review request
const structuredReviewExample = {
  method: "POST",
  url: "http://localhost:8787/review",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    context_file: "review.md",
    urls: [
      "https://github.com/owner/repo/pull/123",
      "https://github.com/owner/repo/pull/124"
    ],
    prefer_cli: "claude",
    debug: false
  })
};

// Example 2: Natural language review request
const nlReviewExample = {
  method: "POST", 
  url: "http://localhost:8787/review/nl",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    query: "Review PRs 123 and 124 from owner/repo using claude with debug mode"
  })
};

// Example 3: Health check
const healthCheckExample = {
  method: "GET",
  url: "http://localhost:8787/health"
};

export {
  structuredReviewExample,
  nlReviewExample, 
  healthCheckExample
};
