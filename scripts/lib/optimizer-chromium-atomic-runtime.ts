import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { pathToFileURL } from "node:url";

export type ChromiumAcquireReleaseAtomicObservationV1 = {
  returnI32: number;
  memoryI32: number;
};

export type ChromiumAcquireReleaseAtomicCapabilityV1 = {
  schema: "starshine.chromium-acquire-release-atomic-capability.v1";
  runtime: string;
  status: "complete" | "blocked";
  observation: ChromiumAcquireReleaseAtomicObservationV1 | null;
  detail: string | null;
};

const RESULT_ATTRIBUTE = "data-starshine-atomic-result";
const RESULT_LIMIT = 1024 * 1024;

function blocked(runtime: string, detail: string): ChromiumAcquireReleaseAtomicCapabilityV1 {
  return {
    schema: "starshine.chromium-acquire-release-atomic-capability.v1",
    runtime,
    status: "blocked",
    observation: null,
    detail,
  };
}

function pageSource(wasmBase64: string): string {
  return `<!doctype html><meta charset="utf-8"><body>running<script>
    const finish = (message) => {
      const json = JSON.stringify(message);
      const bytes = new TextEncoder().encode(json);
      let binary = "";
      for (const byte of bytes) binary += String.fromCharCode(byte);
      document.documentElement.setAttribute(${JSON.stringify(RESULT_ATTRIBUTE)}, btoa(binary));
      document.body.textContent = "complete";
    };
    (async () => {
      const binary = atob(${JSON.stringify(wasmBase64)});
      const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
      const module = await WebAssembly.compile(bytes);
      const memory = new WebAssembly.Memory({ initial: 1, maximum: 1, shared: true });
      const instance = await WebAssembly.instantiate(module, { env: { memory } });
      if (typeof instance.exports.run !== "function") throw new Error("missing i32 export run");
      const raw = instance.exports.run();
      if (typeof raw !== "number" || !Number.isInteger(raw)) {
        throw new Error("AcqRel probe run export must return one i32");
      }
      finish({
        ok: true,
        runtime: "chromium:" + navigator.userAgent + ":--experimental-wasm-acquire-release",
        observation: { returnI32: raw | 0, memoryI32: new Int32Array(memory.buffer)[0] | 0 },
      });
    })().catch((error) => finish({
      ok: false,
      runtime: "chromium:" + navigator.userAgent + ":--experimental-wasm-acquire-release",
      detail: error instanceof Error ? error.message : String(error),
    }));
  </script>`;
}

function parsePayload(output: string): {
  ok: boolean;
  runtime?: string;
  observation?: ChromiumAcquireReleaseAtomicObservationV1;
  detail?: string;
} {
  const match = output.match(new RegExp(`${RESULT_ATTRIBUTE}="([A-Za-z0-9+/=]+)"`));
  if (match === null) throw new Error("Chromium returned no capability payload");
  return JSON.parse(Buffer.from(match[1], "base64").toString("utf8"));
}

export async function probeChromiumAcquireReleaseAtomicRuntimeV1(
  wasmPath: string,
  options: { chromiumBin: string; timeoutMs: number },
): Promise<ChromiumAcquireReleaseAtomicCapabilityV1> {
  if (wasmPath.length === 0) throw new Error("Chromium AcqRel atomic probe requires a wasm path");
  if (options.chromiumBin.length === 0) throw new Error("Chromium AcqRel atomic probe requires an explicit Chromium binary");
  if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 1 || options.timeoutMs > 60000) {
    throw new Error("Chromium AcqRel atomic probe timeout must be between 1 and 60000 milliseconds");
  }

  const fallbackRuntime = `chromium:${options.chromiumBin}:--experimental-wasm-acquire-release`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-chromium-acqrel-"));
  const pagePath = path.join(dir, "probe.html");
  fs.writeFileSync(pagePath, pageSource(fs.readFileSync(wasmPath).toString("base64")));

  return await new Promise((resolve) => {
    const child = spawn(options.chromiumBin, [
      "--headless=new",
      "--no-sandbox",
      "--disable-gpu",
      "--disable-background-networking",
      "--disable-component-update",
      "--no-first-run",
      `--user-data-dir=${path.join(dir, "profile")}`,
      "--virtual-time-budget=1000",
      "--js-flags=--experimental-wasm-acquire-release",
      "--dump-dom",
      pathToFileURL(pagePath).href,
    ], { stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    let diagnostic = "";
    let timedOut = false;
    let spawnError: Error | undefined;
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      output += chunk;
      if (output.length > RESULT_LIMIT) child.kill("SIGKILL");
    });
    child.stderr.on("data", (chunk: string) => {
      diagnostic += chunk;
      if (diagnostic.length > RESULT_LIMIT) child.kill("SIGKILL");
    });
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, options.timeoutMs);
    child.on("error", (error) => { spawnError = error; });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      fs.rmSync(dir, { recursive: true, force: true });
      if (timedOut) return resolve(blocked(fallbackRuntime, `timeout:${options.timeoutMs}ms`));
      if (spawnError !== undefined) return resolve(blocked(fallbackRuntime, `probe-failure:spawn:${spawnError.message}`));
      if (output.length > RESULT_LIMIT || diagnostic.length > RESULT_LIMIT) {
        return resolve(blocked(fallbackRuntime, `probe-failure:Chromium output exceeded ${RESULT_LIMIT} bytes`));
      }
      if (code !== 0) {
        return resolve(blocked(fallbackRuntime, `probe-failure:Chromium exited ${code ?? signal}: ${diagnostic.trim()}`));
      }
      try {
        const message = parsePayload(output);
        const runtime = message.runtime ?? fallbackRuntime;
        if (!message.ok || message.observation === undefined) {
          return resolve(blocked(runtime, `runtime-unsupported:${message.detail ?? "Chromium returned no observation"}`));
        }
        resolve({
          schema: "starshine.chromium-acquire-release-atomic-capability.v1",
          runtime,
          status: "complete",
          observation: message.observation,
          detail: null,
        });
      } catch (error) {
        resolve(blocked(fallbackRuntime, `probe-failure:invalid Chromium response: ${String(error)}; ${diagnostic.trim()}`));
      }
    });
  });
}
