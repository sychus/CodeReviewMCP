/**
 * Health check handler
 */

import { CONFIG } from "../config.ts";
import { Logger } from "../logger.ts";
import { checkScriptHealth } from "../utils/command-runner.ts";
import type { HealthResponse } from "../validation.ts";

const SERVER_START_TIME = Date.now();

/**
 * Enhanced health check with dependency verification
 */
export async function handleHealthCheck(): Promise<Response> {
  const startTime = Date.now();
  
  try {
    const scriptHealth = await checkScriptHealth();
    
    const health: HealthResponse = {
      status: "ok",
      timestamp: new Date().toISOString(),
      server: {
        port: CONFIG.PORT,
        uptime: Date.now() - SERVER_START_TIME,
        version: CONFIG.VERSION,
      },
      dependencies: {
        script: {
          path: CONFIG.SCRIPT_PATH,
          exists: scriptHealth.exists,
          executable: scriptHealth.executable,
        },
      },
    };

    // Determine overall health status
    const allHealthy = scriptHealth.exists && scriptHealth.executable;
    
    if (!allHealthy) {
      health.status = "degraded";
      if (!scriptHealth.exists) {
        health.status = "error";
      }
    }

    const statusCode = health.status === "ok" ? 200 : 
                      health.status === "degraded" ? 200 : 503;

    const duration = Date.now() - startTime;
    
    Logger.debug("Health check completed", {
      status: health.status,
      duration_ms: duration,
      script_exists: scriptHealth.exists,
      script_executable: scriptHealth.executable,
    });

    return new Response(JSON.stringify(health, null, 2), {
      status: statusCode,
      headers: {
        "content-type": "application/json",
        "cache-control": "no-cache",
      },
    });
    
  } catch (error) {
    Logger.error("Health check failed", error);
    
    const errorHealth: HealthResponse = {
      status: "error",
      timestamp: new Date().toISOString(),
      server: {
        port: CONFIG.PORT,
        uptime: Date.now() - SERVER_START_TIME,
        version: CONFIG.VERSION,
      },
      dependencies: {
        script: {
          path: CONFIG.SCRIPT_PATH,
          exists: false,
          executable: false,
        },
      },
    };

    return new Response(JSON.stringify(errorHealth, null, 2), {
      status: 503,
      headers: {
        "content-type": "application/json",
        "cache-control": "no-cache",
      },
    });
  }
}

/**
 * Simple liveness probe
 */
export function handleLiveness(): Response {
  return new Response(JSON.stringify({ status: "alive" }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

/**
 * Readiness probe with basic checks
 */
export async function handleReadiness(): Promise<Response> {
  try {
    const scriptHealth = await checkScriptHealth();
    const ready = scriptHealth.exists && scriptHealth.executable;
    
    return new Response(JSON.stringify({ 
      status: ready ? "ready" : "not_ready",
      checks: {
        script: ready,
      },
    }), {
      status: ready ? 200 : 503,
      headers: { "content-type": "application/json" },
    });
  } catch {
    return new Response(JSON.stringify({ 
      status: "not_ready",
      checks: { script: false },
    }), {
      status: 503,
      headers: { "content-type": "application/json" },
    });
  }
}
