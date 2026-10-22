import { readdir, readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { env } from "../src/infra/env.ts";

const MIGRATIONS_DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");

async function waitForDatabaseConnection(pool: pg.Pool, attempts = 20): Promise<void> {
    for (let i= 1; i <= attempts; i++) {
        try {
            await pool.query("SELECT 1");
            return;
        } catch {
            if (i === attempts) throw new Error("Database is not reachable");
            console.warn(`Database not ready (attempt ${i}/${attempts}), retrying in 1s...`);
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
};

async function main(): Promise<void> {
    const pool = new pg.Pool({ connectionString: env.databaseUrl });
    await waitForDatabaseConnection(pool);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS _migrations (
       name        text PRIMARY KEY,
       applied_at  timestamptz NOT NULL DEFAULT now()
      )
   `);
   const applied = new Set(
   (await pool.query<{ name: string }>("SELECT name FROM _migrations")).rows.map((r) => r.name),); 
   const files = (await readdir(MIGRATIONS_DIR)).filter((f) => f.endsWith(".sql")).sort();

    let _ran = 0
   for (const file of files) {
    if (applied.has(file)) {
        continue;
    }
    const sql = await readFile(join(MIGRATIONS_DIR, file), "utf-8");
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        await client.query(sql);
        await client.query("INSERT INTO _migrations (name) VALUES ($1)", [file]);
        await client.query("COMMIT");
        console.warn(`applied ${file}`);
        _ran++;
    } catch (err) {
        await client.query("ROLLBACK");
        console.error(`failed to apply ${file}:`, err);
        throw err;
    } finally {
      client.release();
    }
   }
   console.warn(_ran === 0 ? "no pending migrations" : `${_ran} migration(s) applied`);
   await pool.end();
};

main().catch((err: unknown) => {
    console.error("Migration failed:", err);
    process.exit(1);
});
