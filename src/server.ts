/**
 * Enhanced CodeReview API Server with comprehensive improvements
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Import our enhanced modules
import { CONFIG, validateConfig } from "./config.ts";
import { Logger } from "./logger.ts";
import {
  corsMiddleware,
  rateLimitMiddleware,
  loggingMiddleware,
  securityHeadersMiddleware,
} from "./middleware.ts";
import { handleHealthCheck, handleLiveness, handleReadiness } from "./handlers/health.ts";
import { handleReview, handleReviewNL } from "./handlers/review.ts";
import { handleMetrics, handleMetricsJSON, recordRequestMetrics } from "./handlers/metrics.ts";

/**
 * Main request handler with middleware chain
 */
async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const { startTime } = loggingMiddleware(req);

  try {
    // Apply middleware chain
    let response: Response | null = null;

    // CORS middleware
    response = corsMiddleware(req);
    if (response) return addSecurityHeaders(response);

    // Rate limiting middleware
    response = rateLimitMiddleware(req);
    if (response) return addSecurityHeaders(response);

    // Route handling
    response = await routeRequest(req, url);
    
    // Add security headers to response
    const finalResponse = addSecurityHeaders(response);
    
    // Record metrics
    recordRequestMetrics(
      req.method,
      url.pathname,
      finalResponse.status,
      Date.now() - startTime
    );

    // Log request completion
    Logger.request(req, startTime, finalResponse.status);

    return finalResponse;

  } catch (error) {
    Logger.error("Unhandled request error", error, {
      method: req.method,
      url: req.url,
    });

    const errorResponse = new Response(
      JSON.stringify({
        status: "error",
        error: "Internal server error",
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { "content-type": "application/json" },
      }
    );

    recordRequestMetrics(req.method, url.pathname, 500, Date.now() - startTime);
    return addSecurityHeaders(errorResponse);
  }
}

/**
 * Route requests to appropriate handlers
 */
async function routeRequest(req: Request, url: URL): Promise<Response> {
  const { method, pathname } = { method: req.method, pathname: url.pathname };

  // Health check endpoints
  if (method === "GET") {
    switch (pathname) {
      case "/health":
        return await handleHealthCheck();
      case "/health/live":
        return handleLiveness();
      case "/health/ready":
        return await handleReadiness();
      case "/metrics":
        return handleMetrics();
      case "/metrics.json":
        return handleMetricsJSON();
    }
  }

  // Review endpoints
  if (method === "POST") {
    switch (pathname) {
      case "/review":
        return await handleReview(req);
      case "/review/nl":
        return await handleReviewNL(req);
    }
  }

  // API info endpoint
  if (method === "GET" && pathname === "/") {
    return handleAPIInfo();
  }

  // 404 Not Found
  return new Response(
    JSON.stringify({
      status: "error",
      error: "Not Found",
      message: `${method} ${pathname} is not a valid endpoint`,
      timestamp: new Date().toISOString(),
      available_endpoints: {
        "GET /": "API information",
        "GET /health": "Health check with dependencies",
        "GET /health/live": "Liveness probe",
        "GET /health/ready": "Readiness probe",
        "GET /metrics": "Prometheus metrics",
        "GET /metrics.json": "JSON metrics",
        "POST /review": "Structured review request",
        "POST /review/nl": "Natural language review request",
      },
    }, null, 2),
    {
      status: 404,
      headers: { "content-type": "application/json" },
    }
  );
}

/**
 * Add security headers to response
 */
function addSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  const securityHeaders = securityHeadersMiddleware();
  
  for (const [key, value] of Object.entries(securityHeaders)) {
    headers.set(key, value);
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

/**
 * API information endpoint
 */
function handleAPIInfo(): Response {
  return new Response(
    JSON.stringify({
      name: "CodeReview API",
      version: CONFIG.VERSION,
      description: "AI-powered code review service supporting Claude, Gemini, and Codex",
      endpoints: {
        health: {
          "GET /health": "Comprehensive health check with dependency status",
          "GET /health/live": "Simple liveness probe",
          "GET /health/ready": "Readiness probe for load balancer",
        },
        review: {
          "POST /review": "Submit structured review request",
          "POST /review/nl": "Submit natural language review request",
        },
        monitoring: {
          "GET /metrics": "Prometheus-format metrics",
          "GET /metrics.json": "JSON-format metrics",
        },
      },
      documentation: {
        github: "https://github.com/sychus/CodeReviewMCP",
        readme: "See README.md for detailed usage instructions",
      },
      server: {
        timestamp: new Date().toISOString(),
        node_env: CONFIG.NODE_ENV,
        log_level: CONFIG.LOG_LEVEL,
      },
    }, null, 2),
    {
      headers: { "content-type": "application/json" },
    }
  );
}

/**
 * Graceful shutdown handler
 */
function setupGracefulShutdown(abortController: AbortController): void {
  const signals: Deno.Signal[] = ["SIGINT", "SIGTERM"];
  
  for (const signal of signals) {
    Deno.addSignalListener(signal, () => {
      Logger.info(`Received ${signal}, shutting down gracefully...`);
      abortController.abort();
    });
  }
}

/**
 * Server startup and initialization
 */
async function startServer(): Promise<void> {
  try {
    // Validate configuration
    validateConfig();
    
    // Set log level from config
    Logger.setLevel(CONFIG.LOG_LEVEL as "debug" | "info" | "warn" | "error");
    
    Logger.info("Starting CodeReview API Server", {
      version: CONFIG.VERSION,
      port: CONFIG.PORT,
      host: CONFIG.HOST,
      node_env: CONFIG.NODE_ENV,
      script_path: CONFIG.SCRIPT_PATH,
      log_level: CONFIG.LOG_LEVEL,
    });

    // Create abort controller for graceful shutdown
    const abortController = new AbortController();
    setupGracefulShutdown(abortController);

    // Start the server
    const serverOptions = {
      port: CONFIG.PORT,
      hostname: CONFIG.HOST,
      signal: abortController.signal,
    };

    Logger.info(`🚀 CodeReview API Server listening on http://${CONFIG.HOST}:${CONFIG.PORT}`);
    Logger.info("📚 Available endpoints:", {
      health: `http://${CONFIG.HOST}:${CONFIG.PORT}/health`,
      review: `http://${CONFIG.HOST}:${CONFIG.PORT}/review`,
      review_nl: `http://${CONFIG.HOST}:${CONFIG.PORT}/review/nl`,
      metrics: `http://${CONFIG.HOST}:${CONFIG.PORT}/metrics`,
    });

    await serve(handleRequest, serverOptions);
    
  } catch (error) {
    Logger.error("Failed to start server", error);
    Deno.exit(1);
  }
}

/**
 * Handle unhandled promise rejections and uncaught exceptions
 */
globalThis.addEventListener("unhandledrejection", (event) => {
  Logger.error("Unhandled promise rejection", event.reason);
  event.preventDefault();
});

globalThis.addEventListener("error", (event) => {
  Logger.error("Uncaught exception", event.error);
});

// Start the server
if (import.meta.main) {
  await startServer();
}
