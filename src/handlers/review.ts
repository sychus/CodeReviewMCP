/**
 * Review request handlers
 */

import { Logger } from "../logger.ts";
import { validateReviewArgs, validateNLRequest } from "../validation.ts";
import { runReviewWithTimeout } from "../utils/command-runner.ts";
import { parseNL } from "../utils/nl-parser.ts";
import type { ReviewArgs, NLRequest } from "../types.ts";

/**
 * Create standardized error response
 */
function createErrorResponse(message: string, status = 400): Response {
  Logger.warn("Request validation error", { message, status });
  return new Response(
    JSON.stringify({ 
      status: "error", 
      error: message,
      timestamp: new Date().toISOString(),
    }), 
    {
      status,
      headers: { "content-type": "application/json" },
    }
  );
}

/**
 * Create standardized success response
 */
function createSuccessResponse(data: unknown, status = 200): Response {
  return new Response(
    JSON.stringify({
      status: status >= 400 ? "error" : "success",
      timestamp: new Date().toISOString(),
      ...data,
    }, null, 2), 
    {
      status,
      headers: { "content-type": "application/json" },
    }
  );
}

/**
 * Handle structured review requests
 */
export async function handleReview(req: Request): Promise<Response> {
  const requestId = crypto.randomUUID();
  Logger.info("Processing review request", { request_id: requestId });
  
  let body: unknown;
  try {
    body = await req.json();
  } catch (error) {
    Logger.error("Invalid JSON in request body", error, { request_id: requestId });
    return createErrorResponse("Invalid JSON format");
  }

  // Validate request body
  const validation = validateReviewArgs(body);
  if (!validation.success) {
    return createErrorResponse(validation.error);
  }

  const args = validation.data;
  
  Logger.info("Review request validated", {
    request_id: requestId,
    urls_count: args.urls.length,
    context_file: args.context_file,
    prefer_cli: args.prefer_cli,
    debug: args.debug,
  });

  try {
    const result = await runReviewWithTimeout(args);
    
    Logger.info("Review completed", {
      request_id: requestId,
      success: result.ok,
      exit_code: result.code,
      duration_ms: result.duration_ms,
    });

    const status = result.ok ? 200 : 500;
    return createSuccessResponse({
      request_id: requestId,
      ...result,
    }, status);
    
  } catch (error) {
    Logger.error("Review execution error", error, { request_id: requestId });
    return createSuccessResponse({
      request_id: requestId,
      ok: false,
      code: -1,
      out: "",
      err: `Unexpected error: ${error.message}`,
    }, 500);
  }
}

/**
 * Handle natural language review requests
 */
export async function handleReviewNL(req: Request): Promise<Response> {
  const requestId = crypto.randomUUID();
  Logger.info("Processing NL review request", { request_id: requestId });

  let body: unknown;
  try {
    body = await req.json();
  } catch (error) {
    Logger.error("Invalid JSON in NL request body", error, { request_id: requestId });
    return createErrorResponse("Invalid JSON format");
  }

  // Validate NL request
  const validation = validateNLRequest(body);
  if (!validation.success) {
    return createErrorResponse(validation.error);
  }

  const nlRequest = validation.data;
  
  Logger.info("NL request validated", {
    request_id: requestId,
    query_length: nlRequest.query.length,
  });

  // Parse natural language to structured format
  const parsed = parseNL(nlRequest.query);
  
  // Validate parsed results
  const parsedValidation = validateReviewArgs(parsed);
  if (!parsedValidation.success) {
    return createErrorResponse(
      `Could not extract valid PR information from query: ${parsedValidation.error}`
    );
  }

  const args = parsedValidation.data;
  
  Logger.info("NL parsing successful", {
    request_id: requestId,
    urls_found: args.urls.length,
    context_file: args.context_file,
    prefer_cli: args.prefer_cli,
  });

  try {
    const result = await runReviewWithTimeout(args);
    
    Logger.info("NL review completed", {
      request_id: requestId,
      success: result.ok,
      exit_code: result.code,
      duration_ms: result.duration_ms,
    });

    const status = result.ok ? 200 : 500;
    return createSuccessResponse({
      request_id: requestId,
      query: nlRequest.query,
      parsed_args: args,
      ...result,
    }, status);
    
  } catch (error) {
    Logger.error("NL review execution error", error, { request_id: requestId });
    return createSuccessResponse({
      request_id: requestId,
      query: nlRequest.query,
      parsed_args: args,
      ok: false,
      code: -1,
      out: "",
      err: `Unexpected error: ${error.message}`,
    }, 500);
  }
}
