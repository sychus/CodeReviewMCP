# 🚀 CodeReview API v2.0 - Complete Setup Guide

## 📦 Installation & Setup

### Prerequisites
- **Deno 2.5+** - [Install Deno](https://deno.com/)
- **CodeReview Script** - Make sure `codereview.sh` is in the root directory
- **GitHub MCP Setup** - Configured with Claude, Gemini, or Codex

### Quick Start

1. **Clone and setup:**
   ```bash
   git clone https://github.com/sychus/CodeReviewMCP.git
   cd CodeReviewMCP
   
   # Make scripts executable
   chmod +x codereview.sh dev.sh
   
   # Copy environment template
   cp .env.example .env
   ```

2. **Configure environment (optional):**
   ```bash
   # Edit .env with your preferences
   nano .env
   ```

3. **Start development server:**
   ```bash
   ./dev.sh
   # OR
   deno task dev
   ```

4. **Start production server:**
   ```bash
   deno task start
   ```

## 🔧 Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8787` | Server port |
| `HOST` | `localhost` | Server host |
| `NODE_ENV` | `development` | Environment mode |
| `LOG_LEVEL` | `info` | Logging level (debug/info/warn/error) |
| `SCRIPT_PATH` | `./codereview.sh` | Path to review script |
| `RATE_LIMIT_REQUESTS` | `10` | Requests per window |
| `RATE_LIMIT_WINDOW_MS` | `60000` | Rate limit window (ms) |
| `MAX_URLS` | `10` | Maximum URLs per request |
| `TIMEOUT_MS` | `300000` | Command timeout (ms) |
| `CORS_ORIGINS` | `*` | CORS allowed origins |

### Production Configuration Example

```bash
# .env for production
PORT=3000
HOST=0.0.0.0
NODE_ENV=production
LOG_LEVEL=warn
SCRIPT_PATH=/app/codereview.sh
RATE_LIMIT_REQUESTS=50
RATE_LIMIT_WINDOW_MS=60000
MAX_URLS=20
TIMEOUT_MS=600000
CORS_ORIGINS=https://yourdomain.com,https://api.yourdomain.com
```

## 📡 API Endpoints

### Core Endpoints

#### `POST /review`
Structured review request with validation.

**Request:**
```json
{
  "context_file": "review.md",
  "urls": [
    "https://github.com/owner/repo/pull/123",
    "https://github.com/owner/repo/pull/124"
  ],
  "prefer_cli": "claude",
  "debug": false
}
```

**Response:**
```json
{
  "status": "success",
  "timestamp": "2024-03-01T10:00:00.000Z",
  "request_id": "uuid-here",
  "ok": true,
  "code": 0,
  "out": "Review output...",
  "duration_ms": 5000
}
```

#### `POST /review/nl`
Natural language review request.

**Request:**
```json
{
  "query": "Review PRs 123 and 124 from owner/repo using claude with debug mode"
}
```

**Response:**
```json
{
  "status": "success",
  "timestamp": "2024-03-01T10:00:00.000Z",
  "request_id": "uuid-here",
  "query": "Review PRs 123 and 124...",
  "parsed_args": {
    "context_file": "review.md",
    "urls": ["https://github.com/owner/repo/pull/123"],
    "prefer_cli": "claude",
    "debug": true
  },
  "ok": true,
  "code": 0,
  "out": "Review output...",
  "duration_ms": 5000
}
```

### Health & Monitoring

#### `GET /health`
Complete health check with dependencies.

#### `GET /health/live`
Simple liveness probe for load balancers.

#### `GET /health/ready`
Readiness probe with script verification.

#### `GET /metrics`
Prometheus-format metrics.

#### `GET /metrics.json`
JSON-format metrics for custom monitoring.

#### `GET /`
API information and documentation.

## 🛠️ Development

### Available Scripts

```bash
# Development with hot reload
deno task dev

# Production start
deno task start

# Code formatting
deno task fmt

# Linting
deno task lint

# Type checking
deno task check

# Quick development server
./dev.sh
```

### Natural Language Parsing Examples

The enhanced NL parser supports various input patterns:

```javascript
// Batch PRs from same repo
"Review PRs 123, 124, 125 from owner/repo using claude"

// Explicit URLs
"Review https://github.com/owner/repo/pull/123 with gemini"

// Context file specification
"Review PR 123 from owner/repo using template custom-review.md"

// Debug mode
"Review PR 123 from owner/repo with debug mode using codex"

// Multiple patterns combined
"Review PRs 123, 124 from owner/repo and https://github.com/other/repo/pull/456 using claude with debug and template api-review.md"
```

## 🔍 Monitoring & Observability

### Structured Logging

All logs are in JSON format for easy parsing:

```json
{
  "timestamp": "2024-03-01T10:00:00.000Z",
  "level": "INFO",
  "message": "Review completed",
  "request_id": "uuid-here",
  "success": true,
  "duration_ms": 5000
}
```

### Metrics Collection

The API exposes Prometheus metrics:

- `codereview_requests_total` - Total HTTP requests
- `codereview_reviews_total` - Total reviews processed
- `codereview_request_duration_seconds` - Request duration histogram

### Docker Integration

```dockerfile
FROM denoland/deno:alpine

WORKDIR /app
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8787/health/ready || exit 1

EXPOSE 8787
CMD ["deno", "task", "start"]
```

## 🚦 Rate Limiting

Built-in rate limiting protects against abuse:

- **Default**: 10 requests per minute per IP
- **Configurable**: Set `RATE_LIMIT_REQUESTS` and `RATE_LIMIT_WINDOW_MS`
- **Response**: HTTP 429 with `Retry-After` header

## 🔒 Security Features

### CORS Support
Configure allowed origins via `CORS_ORIGINS` environment variable.

### Security Headers
Automatic security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'`

### Input Validation
Comprehensive validation with Zod:
- GitHub URL format validation
- Request payload validation
- Natural language input sanitization

## 🐛 Troubleshooting

### Common Issues

1. **Server won't start**
   ```bash
   # Check Deno installation
   deno --version
   
   # Check script permissions
   ls -la codereview.sh
   chmod +x codereview.sh
   ```

2. **Script execution errors**
   ```bash
   # Test script manually
   ./codereview.sh review.md https://github.com/owner/repo/pull/123
   
   # Check environment
   echo $SCRIPT_PATH
   ```

3. **Rate limiting issues**
   ```bash
   # Increase limits in .env
   RATE_LIMIT_REQUESTS=50
   RATE_LIMIT_WINDOW_MS=60000
   ```

4. **CORS errors**
   ```bash
   # Allow your domain in .env
   CORS_ORIGINS=https://yourdomain.com
   ```

### Debug Mode

Enable detailed logging:

```bash
LOG_LEVEL=debug deno task start
```

## 📈 Performance Tuning

### Timeout Configuration
Adjust timeout for long reviews:
```bash
TIMEOUT_MS=600000  # 10 minutes
```

### Concurrent Requests
Deno handles concurrent requests efficiently. Monitor with:
```bash
curl http://localhost:8787/metrics.json
```

### Memory Usage
Monitor server memory and adjust Deno flags if needed:
```bash
deno task start --max-old-space-size=4096
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Style

Run formatting and linting:
```bash
deno task fmt
deno task lint
deno task check
```

## 📞 Support

- **GitHub Issues**: [Report bugs and feature requests](https://github.com/sychus/CodeReviewMCP/issues)
- **Documentation**: Check `MIGRATION.md` for v1 to v2 migration
- **Examples**: See `examples.ts` for usage examples

---

**🎉 Enjoy your enhanced CodeReview API v2.0!**
