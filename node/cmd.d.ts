// Generated from the FFI schema and explicit JavaScript facade projections. DO NOT EDIT.
import type { OpaqueHandle, StarshineResult } from './internal/shared.js';
import type { Module as lib_Module } from './lib.js';
import type { EncodeError as binary_EncodeError } from './binary.js';
import type { CliInputFormat as cli_CliInputFormat } from './cli.js';
// JavaScript callback/record representations. Function signatures are generated from FFI.
/** Structured encode failure surfaced through the Node cmd bridge. */
export interface CmdEncodeError {
  readonly __starshineBrand: "cmd.CmdEncodeError";
  readonly kind: "adapter" | "encode";
  readonly display: string;
  readonly cause?: binary_EncodeError | string;
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
  readonly encodeModule: (mod: lib_Module) => StarshineResult<Uint8Array, CmdEncodeError>;
  /**
   * Compatibility parity hook for MoonBit `CmdIO.print_text_module`.
   *
   * The current Node wrapper keeps this field so `.d.ts`, runtime objects, and
   * the intended public MoonBit shape stay aligned even though the checked-in JS
   * command bridge does not yet route any pipeline through it.
   */
  readonly printTextModule: (mod: lib_Module) => StarshineResult<Uint8Array, string>;
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
    format: cli_CliInputFormat,
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
export function differentialValidateWasm(arg0: Uint8Array, adapters?: DifferentialAdapters): StarshineResult<DifferentialValidationReport, string>;
export function minimizeFuzzPasses(arg0: Array<string>, arg1: (arg0: Array<string>) => boolean): Array<string>;
export function nativeDifferentialToolsAvailable(): [boolean, boolean];
export function persistFuzzFailureReport(arg0: FuzzFailureReport, arg1: FuzzFailurePersistIO, corpusDir?: string): StarshineResult<[string, (string) | null], string>;
export function runCmd(arg0: Array<string>): StarshineResult<CmdRunSummary, CmdError>;
export function runCmdExitCode(arg0: Array<string>): number;
export function runCmdExitCodeWithAdapter(arg0: Array<string>, arg1: CmdIO, configJson?: (string) | null): number;
export function runCmdWithAdapter(arg0: Array<string>, arg1: CmdIO, configJson?: (string) | null): StarshineResult<CmdRunSummary, CmdError>;
export function runCmdFuzzHarness(arg0: number, seed?: bigint, optimizePasses?: Array<string>, differentialAdapters?: (DifferentialAdapters) | null, differentialEvery?: number, onFailure?: ((arg0: FuzzFailureReport) => StarshineResult<void, string>) | null): StarshineResult<CmdFuzzStats, string>;
export function runCmdFuzzHarnessProfile(arg0: string, arg1: bigint): StarshineResult<CmdFuzzStats, string>;
export function verifyReadmeApiSignatures(arg0: string, arg1: Array<[string, string]>): StarshineResult<void, string>;
export function verifyReadmeApiSignaturesWithRequiredBlocks(arg0: string, arg1: Array<[string, string]>, arg2: Array<string>): StarshineResult<void, string>;
export const CmdEncodeError: {
  adapter(arg0: string): CmdEncodeError;
  encode(arg0: binary_EncodeError): CmdEncodeError;
  show(value: CmdEncodeError): string;
};
export const CmdError: {
  ambiguousOutputFile(arg0: string): CmdError;
  unknownPassFlag(arg0: string): CmdError;
  show(value: CmdError): string;
};
export const CmdIO: {
  "new"(getEnv?: (arg0: string) => (string) | null, fileExists?: (arg0: string) => boolean, readFile?: (arg0: string) => StarshineResult<Uint8Array, string>, encodeModule?: (arg0: lib_Module) => StarshineResult<Uint8Array, CmdEncodeError>, printTextModule?: (arg0: lib_Module) => StarshineResult<Uint8Array, string>, writeFile?: (arg0: string, arg1: Uint8Array) => StarshineResult<void, string>, writeStdout?: (arg0: Uint8Array) => StarshineResult<void, string>, writeStderr?: (arg0: Uint8Array) => StarshineResult<void, string>, listCandidates?: () => Array<string>, lowerTextModule?: (arg0: string, arg1: cli_CliInputFormat, arg2: Uint8Array) => StarshineResult<Uint8Array, string>): CmdIO;
};
export const CmdRunSummary: {
  "new"(inputFiles?: Array<string>, outputFiles?: Array<string>, resolvedPasses?: Array<string>, optimizeLevel?: number, shrinkLevel?: number, trapsNeverHappen?: boolean, monomorphizeMinBenefit?: number, closedWorld?: boolean, lowMemoryUnused?: boolean, lowMemoryBound?: bigint): CmdRunSummary;
  show(value: CmdRunSummary): string;
};
export const DifferentialAdapters: {
  "new"(wasmToolsValidate?: (arg0: Uint8Array) => StarshineResult<boolean, string>, binaryenValidate?: (arg0: Uint8Array) => StarshineResult<boolean, string>): DifferentialAdapters;
};
export const DifferentialValidationReport: {
  show(value: DifferentialValidationReport): string;
};
export const FuzzFailurePersistIO: {
  "new"(ensureDir?: (arg0: string) => StarshineResult<void, string>, writeFile?: (arg0: string, arg1: Uint8Array) => StarshineResult<void, string>): FuzzFailurePersistIO;
};
export const FuzzFailureReport: {
  "new"(arg0: bigint, arg1: number, arg2: number, arg3: string, arg4: string, optimizePasses?: Array<string>, minimizedPasses?: Array<string>, wasm?: (Uint8Array) | null): FuzzFailureReport;
  show(value: FuzzFailureReport): string;
};
export const ReadmeApiVerifyBlock: {
  show(value: ReadmeApiVerifyBlock): string;
};
export const CmdFuzzStats: {
  "new"(attempts?: number, generatedValid?: number, generatedInvalid?: number, pipelineValidated?: number, optimized?: number, roundtripped?: number, differentialChecked?: number): CmdFuzzStats;
  show(value: CmdFuzzStats): string;
};
export const WasmSmithFuzzStats: typeof CmdFuzzStats;
export const runWasmSmithFuzzHarness: typeof runCmdFuzzHarness;
export const runWasmSmithFuzzHarnessProfile: typeof runCmdFuzzHarnessProfile;
