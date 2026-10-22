import "dotenv/config";

function required(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}

function optionalNumber(name: string, fallback: number): number {
    const raw = process.env[name];
    if (!raw) {
        return fallback;
    }
    const parsed = Number(raw);
    if (Number.isNaN(parsed)) {
        throw new Error(`Invalid number for environment variable: ${name}, got: ${raw}`);
    }
    return parsed;
}

export const env = {
    nodeEnv: process.env.NODE_ENV || "development",
    databaseUrl: required("DATABASE_URL"),
    apiPort: optionalNumber("API_PORT", 4000),
    logLevel: process.env.LOG_LEVEL ?? "info",
    providerMinLatencyMs: optionalNumber("PROVIDER_MIN_LATENCY_MS", 100),
    providerMaxLatencyMs: optionalNumber("PROVIDER_MAX_LATENCY_MS", 800),
    providerTimeoutMs: optionalNumber("PROVIDER_TIMEOUT_MS", 6000),
    idempotencyTtlHours: optionalNumber("IDEMPOTENCY_TTL_HOURS", 24),
} as const;