import type { EncodeError } from "./binary.js";
import type { CliInputFormat } from "./cli.js";
import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module } from "./lib.js";

/** Structured encode failure surfaced through the Node cmd bridge. */
export interface CmdEncodeError {
  readonly __starshineBrand: "cmd.CmdEncodeError";
  readonly kind: "adapter" | "encode";
  readonly display: string;
  readonly cause?: EncodeError | string;
}

/** Structured command failure surfaced through the Node cmd bridge. */
export interface CmdError {
  readonly __starshineBrand: "cmd.CmdError";
  readonly kind: string;
  readonly display: string;
  readonly cause?: unknown;
}

/**
 * Host-side IO adapter used by `runCmdWithAdapter()` and `runCmdExitCodeWithAdapter()`.
 *
 * This lets JS callers run the packaged CLI pipeline against custom filesystems,
 * in-memory buffers, or test doubles. `printTextModule` is currently carried for
 * MoonBit API parity; the checked-in Node bridge does not call it yet.
 */
export interface CmdIO {
  readonly __starshineBrand: "cmd.CmdIO";
  /** Lookup an environment variable or return `null` when it is unset. */
  readonly getEnv: (name: string) => string | null;
  /** Report whether a path exists from the adapter's point of view. */
  readonly fileExists: (path: string) => boolean;
  /** Read a file as raw bytes for wasm, wat, wast, or config inputs. */
  readonly readFile: (path: string) => StarshineResult<Uint8Array, string>;
  /** Encode an in-memory module back to binary wasm bytes. */
  readonly encodeModule: (mod: Module) => StarshineResult<Uint8Array, CmdEncodeError>;
  /**
   * Compatibility parity hook for MoonBit `CmdIO.print_text_module`.
   *
   * The current Node wrapper keeps this field so `.d.ts`, runtime objects, and
   * the intended public MoonBit shape stay aligned even though the checked-in JS
   * command bridge does not yet route any pipeline through it.
   */
  readonly printTextModule: (mod: Module) => StarshineResult<Uint8Array, string>;
  /** Write a named output file. */
  readonly writeFile: (path: string, bytes: Uint8Array) => StarshineResult<void, string>;
  /** Write bytes to stdout. */
  readonly writeStdout: (bytes: Uint8Array) => StarshineResult<void, string>;
  /** Write bytes to stderr. */
  readonly writeStderr: (bytes: Uint8Array) => StarshineResult<void, string>;
  /** Enumerate candidate files for glob expansion. */
  readonly listCandidates: () => Array<string>;
  /** Lower a text module to binary wasm bytes. */
  readonly lowerTextModule: (
    path: string,
    format: CliInputFormat,
    bytes: Uint8Array,
  ) => StarshineResult<Uint8Array, string>;
}

/**
 * Summary returned by the packaged command pipeline.
 *
 * `closedWorld` is a truthful summary of the packaged cmd bridge's resolved
 * config/env/CLI closed-world state. The separate `node/cli` wrapper still lags
 * full MoonBit closed-world parser parity.
 */
export interface CmdRunSummary {
  readonly __starshineBrand: "cmd.CmdRunSummary";
  readonly inputFiles: Array<string>;
  readonly outputFiles: Array<string>;
  readonly resolvedPasses: Array<string>;
  readonly optimizeLevel: number;
  readonly shrinkLevel: number;
  readonly trapsNeverHappen: boolean;
  readonly monomorphizeMinBenefit: number;
  readonly closedWorld: boolean;
  readonly lowMemoryUnused: boolean;
  readonly lowMemoryBound: bigint;
}

/** Differential validation callbacks for external wasm validators. */
export interface DifferentialAdapters {
  readonly __starshineBrand: "cmd.DifferentialAdapters";
  readonly wasmToolsValidate: (bytes: Uint8Array) => StarshineResult<boolean, string>;
  readonly binaryenValidate: (bytes: Uint8Array) => StarshineResult<boolean, string>;
}

/** Combined report returned by `differentialValidateWasm()`. */
export interface DifferentialValidationReport {
  readonly __starshineBrand: "cmd.DifferentialValidationReport";
  readonly internalValid: boolean;
  readonly wasmToolsValid: boolean | null;
  readonly binaryenValid: boolean | null;
}

/** IO hooks used by `persistFuzzFailureReport()`. */
export interface FuzzFailurePersistIO {
  readonly __starshineBrand: "cmd.FuzzFailurePersistIO";
  readonly ensureDir: (path: string) => StarshineResult<void, string>;
  readonly writeFile: (path: string, bytes: Uint8Array) => StarshineResult<void, string>;
}

/** Failure record passed to the optional fuzz harness callback. */
export interface FuzzFailureReport {
  readonly __starshineBrand: "cmd.FuzzFailureReport";
  readonly seed: bigint;
  readonly attempt: number;
  readonly generatedValid: number;
  readonly stage: string;
  readonly message: string;
  readonly optimizePasses: Array<string>;
  readonly minimizedPasses: Array<string>;
  readonly wasm: Uint8Array | null;
}

export type ReadmeApiVerifyBlock = OpaqueHandle<"cmd.ReadmeApiVerifyBlock">;

/**
 * Public command-fuzz harness counters.
 *
 * This is the parity name for the MoonBit `CmdFuzzStats` record. The legacy
 * `WasmSmithFuzzStats` export remains available as a documented compatibility alias.
 */
export interface CmdFuzzStats {
  readonly __starshineBrand: "cmd.CmdFuzzStats";
  readonly attempts: number;
  readonly generatedValid: number;
  readonly generatedInvalid: number;
  readonly pipelineValidated: number;
  readonly optimized: number;
  readonly roundtripped: number;
  readonly differentialChecked: number;
}

export function cmdHelpText(): string;
export function cmdVersionText(): string;
export function differentialValidateWasm(
  bytes: Uint8Array,
  adapters?: DifferentialAdapters,
): StarshineResult<DifferentialValidationReport, string>;
export function minimizeFuzzPasses(
  passes: Array<string>,
  reproduces: (passes: Array<string>) => boolean,
): Array<string>;
export function nativeDifferentialToolsAvailable(): [boolean, boolean];
export function persistFuzzFailureReport(
  report: FuzzFailureReport,
  io: FuzzFailurePersistIO,
  corpusDir?: string,
): StarshineResult<[string, string | null], string>;
export function runCmd(args: Array<string>): StarshineResult<CmdRunSummary, CmdError>;
export function runCmdExitCode(args: Array<string>): number;
export function runCmdExitCodeWithAdapter(
  args: Array<string>,
  io: CmdIO,
  configJson?: string | null,
): number;
export function runCmdWithAdapter(
  args: Array<string>,
  io: CmdIO,
  configJson?: string | null,
): StarshineResult<CmdRunSummary, CmdError>;
/**
 * Run the public command fuzz harness.
 *
 * `validTarget` is the number of valid modules to reach before the harness succeeds.
 * `optimizePasses` should be pass-name strings. `differentialAdapters` and
 * `differentialEvery` enable periodic external cross-checking. `onFailure` can
 * persist or inspect the final failure report before the error string is returned.
 */
export function runCmdFuzzHarness(
  validTarget: number,
  seed?: bigint,
  optimizePasses?: Array<string>,
  differentialAdapters?: DifferentialAdapters | null,
  differentialEvery?: number,
  onFailure?: ((report: FuzzFailureReport) => StarshineResult<void, string>) | null,
): StarshineResult<CmdFuzzStats, string>;
/**
 * Run a named command-fuzz profile.
 *
 * Supported profile names currently match the MoonBit implementation: `smoke`,
 * `ci`, and `stress`. Unknown profile names return an error result instead of throwing.
 */
export function runCmdFuzzHarnessProfile(
  profile: string,
  seed: bigint,
): StarshineResult<CmdFuzzStats, string>;
/**
 * Compatibility alias for older Node consumers that still import the pre-rename
 * `runWasmSmithFuzzHarness` symbol.
 *
 * The behavior matches `runCmdFuzzHarness()`. Prefer the parity name in new code.
 */
export function runWasmSmithFuzzHarness(
  validTarget: number,
  seed?: bigint,
  optimizePasses?: Array<string>,
  differentialAdapters?: DifferentialAdapters | null,
  differentialEvery?: number,
  onFailure?: ((report: FuzzFailureReport) => StarshineResult<void, string>) | null,
): StarshineResult<CmdFuzzStats, string>;
/**
 * Compatibility alias for older Node consumers that still import the pre-rename
 * `runWasmSmithFuzzHarnessProfile` symbol.
 *
 * The behavior matches `runCmdFuzzHarnessProfile()`. Prefer the parity name in new code.
 */
export function runWasmSmithFuzzHarnessProfile(
  profile: string,
  seed: bigint,
): StarshineResult<CmdFuzzStats, string>;
export function verifyReadmeApiSignatures(
  text: string,
  signatures: Array<[string, string]>,
): StarshineResult<void, string>;
export function verifyReadmeApiSignaturesWithRequiredBlocks(
  text: string,
  signatures: Array<[string, string]>,
  requiredBlocks: Array<string>,
): StarshineResult<void, string>;

export const CmdEncodeError: {
  adapter(message: string): CmdEncodeError;
  encode(value: EncodeError): CmdEncodeError;
  show(value: CmdEncodeError): string;
};

export const CmdError: {
  ambiguousOutputFile(path: string): CmdError;
  unknownPassFlag(flag: string): CmdError;
  show(value: CmdError): string;
};

export const CmdIO: {
  /** Create a host-side cmd IO adapter with optional hooks in MoonBit field order. */
  new(
    getEnv?: (name: string) => string | null,
    fileExists?: (path: string) => boolean,
    readFile?: (path: string) => StarshineResult<Uint8Array, string>,
    encodeModule?: (mod: Module) => StarshineResult<Uint8Array, CmdEncodeError>,
    printTextModule?: (mod: Module) => StarshineResult<Uint8Array, string>,
    writeFile?: (path: string, bytes: Uint8Array) => StarshineResult<void, string>,
    writeStdout?: (bytes: Uint8Array) => StarshineResult<void, string>,
    writeStderr?: (bytes: Uint8Array) => StarshineResult<void, string>,
    listCandidates?: () => Array<string>,
    lowerTextModule?: (
      path: string,
      format: CliInputFormat,
      bytes: Uint8Array,
    ) => StarshineResult<Uint8Array, string>,
  ): CmdIO;
};

export const CmdRunSummary: {
  /** Build a summary object in MoonBit field order. */
  new(
    inputFiles?: Array<string>,
    outputFiles?: Array<string>,
    resolvedPasses?: Array<string>,
    optimizeLevel?: number,
    shrinkLevel?: number,
    trapsNeverHappen?: boolean,
    monomorphizeMinBenefit?: number,
    closedWorld?: boolean,
    lowMemoryUnused?: boolean,
    lowMemoryBound?: bigint,
  ): CmdRunSummary;
  show(value: CmdRunSummary): string;
};

export const DifferentialAdapters: {
  new(
    wasmToolsValidate?: (bytes: Uint8Array) => StarshineResult<boolean, string>,
    binaryenValidate?: (bytes: Uint8Array) => StarshineResult<boolean, string>,
  ): DifferentialAdapters;
};

export const DifferentialValidationReport: {
  show(value: DifferentialValidationReport): string;
};

export const FuzzFailurePersistIO: {
  new(
    ensureDir?: (path: string) => StarshineResult<void, string>,
    writeFile?: (path: string, bytes: Uint8Array) => StarshineResult<void, string>,
  ): FuzzFailurePersistIO;
};

export const FuzzFailureReport: {
  new(
    seed: bigint,
    attempt: number,
    generatedValid: number,
    stage: string,
    message: string,
    optimizePasses?: Array<string>,
    minimizedPasses?: Array<string>,
    wasm?: Uint8Array | null,
  ): FuzzFailureReport;
  show(value: FuzzFailureReport): string;
};

export const ReadmeApiVerifyBlock: {
  show(value: ReadmeApiVerifyBlock): string;
};

export const CmdFuzzStats: {
  /** Create a parity-shaped `CmdFuzzStats` value. */
  new(
    attempts?: number,
    generatedValid?: number,
    generatedInvalid?: number,
    pipelineValidated?: number,
    optimized?: number,
    roundtripped?: number,
    differentialChecked?: number,
  ): CmdFuzzStats;
  show(value: CmdFuzzStats): string;
};

export const WasmSmithFuzzStats: {
  /** Compatibility alias for `CmdFuzzStats`. Prefer `CmdFuzzStats` in new code. */
  new(
    attempts?: number,
    generatedValid?: number,
    generatedInvalid?: number,
    pipelineValidated?: number,
    optimized?: number,
    roundtripped?: number,
    differentialChecked?: number,
  ): CmdFuzzStats;
  show(value: CmdFuzzStats): string;
};
