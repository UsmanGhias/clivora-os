#!/usr/bin/env node
/**
 * Next.js start that always binds process.env.PORT.
 * Always bind process.env.PORT (platform-injected). Shell ${PORT:-3000}
 * in package.json is unreliable under some hosts' npm wrappers.
 */
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const nextBin = require.resolve("next/dist/bin/next");
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const port = String(process.env.PORT || process.env.APP_PORT || "3000").trim() || "3000";
const host = "0.0.0.0";

console.log(`[clivora] next start -H ${host} -p ${port} (PORT=${process.env.PORT ?? "unset"})`);

const child = spawn(process.execPath, [nextBin, "start", "-H", host, "-p", port], {
  stdio: "inherit",
  env: process.env,
  cwd: root,
});

child.on("exit", (code, signal) => {
  if (signal) {
    console.error(`[clivora] next exited signal=${signal}`);
    process.exit(1);
  }
  process.exit(code ?? 1);
});
