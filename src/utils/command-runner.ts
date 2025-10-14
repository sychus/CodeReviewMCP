/**
 * Enhanced command execution utilities
 */

import { CONFIG } from "../config.ts";
import { Logger } from "../logger.ts";
import type { ReviewArgs, RunResult } from "../types.ts";

/**
 * Build command arguments from ReviewArgs
 */
function buildArgs(args: ReviewArgs): string[] {
  const cmdArgs: string[] = [];
  
  if (args.debug) {
    cmdArgs.push("--debug");
  }
  
  cmdArgs.push(args.context_file || "review.md");
  cmdArgs.push(...args.urls);
  
  return cmdArgs;
}

/**
 * Build environment variables
 */
function buildEnv(args: ReviewArgs): Record<string, string> {
  const env: Record<string, string> = { ...Deno.env.toObject() };
  
  if (args.prefer_cli) {
    env.PREFERRED_CLI = args.prefer_cli;
    Logger.debug("Setting PREFERRED_CLI environment variable", { 
      prefer_cli: args.prefer_cli 
    });
  }
  
  return env;
}

/**
 * Check if script file exists and is executable
 */
export async function checkScriptHealth(): Promise<{
  exists: boolean;
  executable: boolean;
  error?: string;
}> {
  try {
    const stat = await Deno.stat(CONFIG.SCRIPT_PATH);
    
    if (!stat.isFile) {
      return { exists: false, executable: false, error: "Path is not a file" };
    }
    
    // Check if file is executable (Unix permissions)
    const executable = (stat.mode! & 0o111) !== 0;
    
    return { exists: true, executable };
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) {
      return { exists: false, executable: false, error: "File not found" };
    }
    return { exists: false, executable: false, error: error.message };
  }
}

/**
 * Run review command with timeout and better error handling
 */
export async function runReviewWithTimeout(args: ReviewArgs): Promise<RunResult> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => {
    Logger.warn("Command timeout", { timeout_ms: CONFIG.TIMEOUT_MS, args });
    controller.abort();
  }, CONFIG.TIMEOUT_MS);
  
  const startTime = Date.now();
  
  try {
    Logger.info("Starting review command", { 
      script: CONFIG.SCRIPT_PATH, 
      urls_count: args.urls.length,
      debug: args.debug,
      prefer_cli: args.prefer_cli
    });
    
    const cmdArgs = buildArgs(args);
    const cmdEnv = buildEnv(args);
    
    Logger.debug("Command execution details", {
      args: cmdArgs,
      env_preferred_cli: cmdEnv.PREFERRED_CLI,
      script_path: CONFIG.SCRIPT_PATH
    });
    
    const cmd = new Deno.Command(CONFIG.SCRIPT_PATH, {
      args: cmdArgs,
      env: cmdEnv,
      signal: controller.signal,
      stdout: "piped",
      stderr: "piped",
    });
    
    const { code, stdout, stderr } = await cmd.output();
    
    const duration = Date.now() - startTime;
    const out = new TextDecoder().decode(stdout);
    const err = new TextDecoder().decode(stderr);
    
    Logger.info("Review command completed", {
      exit_code: code,
      duration_ms: duration,
      stdout_length: out.length,
      stderr_length: err.length,
    });
    
    if (code === 0) {
      return { ok: true, code, out, duration_ms: duration };
    } else {
      Logger.error("Review command failed", undefined, {
        exit_code: code,
        stderr: err.substring(0, 500), // Limit error log size
      });
      return { ok: false, code, out, err, duration_ms: duration };
    }
    
  } catch (error) {
    const duration = Date.now() - startTime;
    
    if (error.name === "AbortError") {
      Logger.error("Review command timed out", error, { 
        timeout_ms: CONFIG.TIMEOUT_MS,
        duration_ms: duration 
      });
      return { 
        ok: false, 
        code: -1, 
        out: "", 
        err: `Command timed out after ${CONFIG.TIMEOUT_MS}ms`,
        duration_ms: duration
      };
    }
    
    Logger.error("Review command error", error, { duration_ms: duration });
    return { 
      ok: false, 
      code: -2, 
      out: "", 
      err: `Command execution error: ${error.message}`,
      duration_ms: duration
    };
  } finally {
    clearTimeout(timeoutId);
  }
}
