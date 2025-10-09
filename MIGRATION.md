# CodeReview API - Migration Guide

## 🔄 Migration from v1 to v2

### What's New in v2.0

- **Enhanced Architecture**: Modular design with proper separation of concerns
- **Better Error Handling**: Comprehensive validation with Zod
- **Improved Logging**: Structured JSON logging with configurable levels
- **Security Features**: CORS, rate limiting, security headers
- **Monitoring**: Prometheus metrics and health checks
- **Configuration**: Environment-based configuration management

### Breaking Changes

#### 1. Response Format Changes

**Before (v1):**
```json
{
  "status": "success",
  "ok": true,
  "code": 0,
  "out": "review output"
}
```

**After (v2):**
```json
{
  "status": "success",
  "timestamp": "2024-03-01T10:00:00.000Z",
  "request_id": "uuid-here",
  "ok": true,
  "code": 0,
  "out": "review output",
  "duration_ms": 5000
}
```

#### 2. Error Response Changes

**Before (v1):**
```json
{
  "status": "error",
  "error": "Simple error message"
}
```

**After (v2):**
```json
{
  "status": "error",
  "error": "Detailed error message",
  "timestamp": "2024-03-01T10:00:00.000Z",
  "request_id": "uuid-here"
}
```

#### 3. New Environment Variables

Required environment variables (with defaults):
- `PORT=8787`
- `HOST=localhost`
- `NODE_ENV=development`
- `LOG_LEVEL=info`
- `SCRIPT_PATH=./codereview.sh`

### New Endpoints

- `GET /` - API information
- `GET /health/live` - Liveness probe
- `GET /health/ready` - Readiness probe
- `GET /metrics` - Prometheus metrics
- `GET /metrics.json` - JSON metrics

### Migration Steps

1. **Update Environment Variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Update Client Code**
   - Handle new response format with `request_id` and `timestamp`
   - Update error handling for new error format
   - Use new health check endpoints for monitoring

3. **Update Deployment**
   - Use new liveness/readiness probes
   - Set up metrics collection
   - Configure CORS if needed

4. **Test Migration**
   ```bash
   # Start development server
   ./dev.sh
   
   # Test health check
   curl http://localhost:8787/health
   
   # Test API info
   curl http://localhost:8787/
   ```

### Backward Compatibility

The core functionality remains the same:
- `/review` endpoint works as before (with enhanced responses)
- `/review/nl` endpoint works as before (with enhanced responses)
- `/health` endpoint works as before (with additional information)

### Configuration Options

```bash
# .env file
PORT=8787
HOST=localhost
NODE_ENV=production
LOG_LEVEL=info
SCRIPT_PATH=./codereview.sh
RATE_LIMIT_REQUESTS=20
RATE_LIMIT_WINDOW_MS=60000
MAX_URLS=15
TIMEOUT_MS=600000
CORS_ORIGINS=https://yourdomain.com,https://api.yourdomain.com
```

### Monitoring Setup

#### Prometheus Metrics
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'codereview-api'
    static_configs:
      - targets: ['localhost:8787']
    metrics_path: '/metrics'
```

#### Docker Health Checks
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8787/health/ready || exit 1
```

### Performance Improvements

- **Request Timeouts**: Configurable timeout for long reviews
- **Rate Limiting**: Prevents API abuse
- **Structured Logging**: Better debugging and monitoring
- **Graceful Shutdown**: Proper cleanup on termination

### Troubleshooting

#### Common Issues

1. **Invalid JSON responses**
   - Check that `Content-Type: application/json` is set
   - Validate JSON payload format

2. **Rate limit errors**
   - Increase `RATE_LIMIT_REQUESTS` or `RATE_LIMIT_WINDOW_MS`
   - Implement client-side retry logic

3. **Script execution failures**
   - Check `SCRIPT_PATH` points to executable file
   - Verify script permissions with `ls -la codereview.sh`

4. **Log verbosity**
   - Set `LOG_LEVEL=debug` for detailed logging
   - Check server logs for error details

### Support

For issues or questions about migration:
- Check GitHub Issues: https://github.com/sychus/CodeReviewMCP/issues
- Review examples in `examples.ts`
- Use the development script: `./dev.sh`
