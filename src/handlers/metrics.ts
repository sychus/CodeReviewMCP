/**
 * Metrics and monitoring endpoints
 */

import { Logger } from "../logger.ts";

// Simple in-memory metrics store
class MetricsStore {
  private metrics = new Map<string, number>();
  private histograms = new Map<string, number[]>();

  increment(name: string, value = 1): void {
    const current = this.metrics.get(name) || 0;
    this.metrics.set(name, current + value);
  }

  recordDuration(name: string, duration: number): void {
    const current = this.histograms.get(name) || [];
    current.push(duration);
    
    // Keep only last 1000 values to prevent memory leak
    if (current.length > 1000) {
      current.shift();
    }
    
    this.histograms.set(name, current);
  }

  getCounter(name: string): number {
    return this.metrics.get(name) || 0;
  }

  getHistogramBuckets(name: string, buckets: number[]): Map<number, number> {
    const durations = this.histograms.get(name) || [];
    const bucketCounts = new Map<number, number>();
    
    for (const bucket of buckets) {
      const count = durations.filter(d => d <= bucket * 1000).length; // Convert to ms
      bucketCounts.set(bucket, count);
    }
    
    return bucketCounts;
  }

  getAllMetrics(): Record<string, unknown> {
    const counters = Object.fromEntries(this.metrics);
    const histogramSummaries = Object.fromEntries(
      Array.from(this.histograms.entries()).map(([name, durations]) => [
        name,
        {
          count: durations.length,
          avg: durations.length > 0 ? durations.reduce((a, b) => a + b, 0) / durations.length : 0,
          min: durations.length > 0 ? Math.min(...durations) : 0,
          max: durations.length > 0 ? Math.max(...durations) : 0,
        }
      ])
    );
    
    return {
      counters,
      histograms: histogramSummaries,
    };
  }
}

export const metrics = new MetricsStore();

/**
 * Prometheus-style metrics endpoint
 */
export function handleMetrics(): Response {
  const requestsTotal = metrics.getCounter("requests_total");
  const requestsSuccess = metrics.getCounter("requests_success");
  const requestsError = metrics.getCounter("requests_error");
  const reviewsTotal = metrics.getCounter("reviews_total");
  const reviewsSuccess = metrics.getCounter("reviews_success");
  const reviewsError = metrics.getCounter("reviews_error");
  
  const durationBuckets = metrics.getHistogramBuckets("request_duration", [1, 5, 10, 30, 60, 120, 300]);
  
  const prometheusFormat = `
# HELP codereview_requests_total Total number of HTTP requests
# TYPE codereview_requests_total counter
codereview_requests_total{status="total"} ${requestsTotal}
codereview_requests_total{status="success"} ${requestsSuccess}
codereview_requests_total{status="error"} ${requestsError}

# HELP codereview_reviews_total Total number of code reviews
# TYPE codereview_reviews_total counter
codereview_reviews_total{status="total"} ${reviewsTotal}
codereview_reviews_total{status="success"} ${reviewsSuccess}
codereview_reviews_total{status="error"} ${reviewsError}

# HELP codereview_request_duration_seconds Duration of HTTP requests
# TYPE codereview_request_duration_seconds histogram
${Array.from(durationBuckets.entries())
  .map(([bucket, count]) => `codereview_request_duration_seconds_bucket{le="${bucket}"} ${count}`)
  .join('\n')}
codereview_request_duration_seconds_bucket{le="+Inf"} ${requestsTotal}
  `.trim();

  return new Response(prometheusFormat, {
    headers: { "content-type": "text/plain" },
  });
}

/**
 * JSON metrics endpoint
 */
export function handleMetricsJSON(): Response {
  const allMetrics = metrics.getAllMetrics();
  
  return new Response(JSON.stringify({
    timestamp: new Date().toISOString(),
    metrics: allMetrics,
  }, null, 2), {
    headers: { "content-type": "application/json" },
  });
}

/**
 * Record request metrics
 */
export function recordRequestMetrics(
  method: string,
  path: string,
  status: number,
  duration: number,
): void {
  metrics.increment("requests_total");
  metrics.increment(`requests_${method.toLowerCase()}_total`);
  
  if (status >= 200 && status < 400) {
    metrics.increment("requests_success");
  } else {
    metrics.increment("requests_error");
  }
  
  metrics.recordDuration("request_duration", duration);
  
  Logger.debug("Request metrics recorded", {
    method,
    path,
    status,
    duration_ms: duration,
  });
}

/**
 * Record review metrics
 */
export function recordReviewMetrics(success: boolean, duration: number, urlsCount: number): void {
  metrics.increment("reviews_total");
  metrics.increment("urls_processed_total", urlsCount);
  
  if (success) {
    metrics.increment("reviews_success");
  } else {
    metrics.increment("reviews_error");
  }
  
  metrics.recordDuration("review_duration", duration);
  
  Logger.debug("Review metrics recorded", {
    success,
    duration_ms: duration,
    urls_count: urlsCount,
  });
}
