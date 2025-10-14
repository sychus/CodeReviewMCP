/**
 * Structured logging utility
 */

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogMeta {
  [key: string]: unknown;
}

export class Logger {
  private static readonly LOG_LEVELS: Record<LogLevel, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
  };

  private static currentLevel: LogLevel = "info";

  static setLevel(level: LogLevel): void {
    this.currentLevel = level;
  }

  private static shouldLog(level: LogLevel): boolean {
    return this.LOG_LEVELS[level] >= this.LOG_LEVELS[this.currentLevel];
  }

  private static formatMessage(
    level: LogLevel,
    message: string,
    meta?: LogMeta,
  ): string {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level: level.toUpperCase(),
      message,
      ...meta,
    };
    return JSON.stringify(logEntry);
  }

  static debug(message: string, meta?: LogMeta): void {
    if (this.shouldLog("debug")) {
      console.debug(this.formatMessage("debug", message, meta));
    }
  }

  static info(message: string, meta?: LogMeta): void {
    if (this.shouldLog("info")) {
      console.log(this.formatMessage("info", message, meta));
    }
  }

  static warn(message: string, meta?: LogMeta): void {
    if (this.shouldLog("warn")) {
      console.warn(this.formatMessage("warn", message, meta));
    }
  }

  static error(message: string, error?: Error, meta?: LogMeta): void {
    if (this.shouldLog("error")) {
      console.error(
        this.formatMessage("error", message, {
          ...meta,
          error: error?.message,
          stack: error?.stack,
        }),
      );
    }
  }

  static request(req: Request, startTime: number, status: number): void {
    const duration = Date.now() - startTime;
    this.info("HTTP Request", {
      method: req.method,
      url: req.url,
      status,
      duration_ms: duration,
      user_agent: req.headers.get("user-agent"),
    });
  }
}
