/**
 * HTTP middleware functions
 */

import { CONFIG } from "./config.ts";
import { Logger } from "./logger.ts";

export type MiddlewareResult = Response | null;

/**
 * CORS middleware
 */
export function corsMiddleware(req: Request): MiddlewareResult {
  const origin = req.headers.get("origin");
  const allowedOrigins = CONFIG.CORS_ORIGINS;
  
  const corsHeaders: Record<string, string> = {
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "86400",
  };

  // Check if origin is allowed
  if (allowedOrigins.includes("*") || (origin && allowedOrigins.includes(origin))) {
    corsHeaders["Access-Control-Allow-Origin"] = origin || "*";
  }

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  // Add CORS headers to response (will be handled by main server)
  return null;
}

/**
 * Rate limiting middleware
 */
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

export function rateLimitMiddleware(req: Request): MiddlewareResult {
  const clientIP = req.headers.get("x-forwarded-for") || 
                   req.headers.get("x-real-ip") || 
                   "unknown";
  const now = Date.now();
  
  const current = rateLimitMap.get(clientIP) || { 
    count: 0, 
    resetTime: now + CONFIG.RATE_LIMIT_WINDOW_MS 
  };
  
  if (now > current.resetTime) {
    current.count = 0;
    current.resetTime = now + CONFIG.RATE_LIMIT_WINDOW_MS;
  }
  
  current.count++;
  rateLimitMap.set(clientIP, current);
  
  if (current.count > CONFIG.RATE_LIMIT_REQUESTS) {
    Logger.warn("Rate limit exceeded", { clientIP, count: current.count });
    return new Response(
      JSON.stringify({ 
        status: "error", 
        error: "Rate limit exceeded. Try again later.",
        retry_after: Math.ceil((current.resetTime - now) / 1000)
      }), 
      {
        status: 429,
        headers: { 
          "content-type": "application/json",
          "retry-after": Math.ceil((current.resetTime - now) / 1000).toString()
        },
      }
    );
  }
  
  return null;
}

/**
 * Request logging middleware
 */
export function loggingMiddleware(req: Request): { startTime: number } {
  const startTime = Date.now();
  Logger.debug("Incoming request", {
    method: req.method,
    url: req.url,
    user_agent: req.headers.get("user-agent"),
  });
  return { startTime };
}

/**
 * Security headers middleware
 */
export function securityHeadersMiddleware(): Record<string, string> {
  return {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "X-XSS-Protection": "1; mode=block",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Content-Security-Policy": "default-src 'self'",
  };
}
