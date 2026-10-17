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
