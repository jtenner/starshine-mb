import type { EncodeError } from "./binary.js";
import type { CliInputFormat, CliOptimizationFlag, CliOutputTarget, TrapMode } from "./cli.js";
import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module } from "./lib.js";
import type { ModulePass } from "./passes.js";

export interface CmdEncodeError {
  readonly __starshineBrand: "cmd.CmdEncodeError";
  readonly kind: "adapter" | "encode";
  readonly display: string;
  readonly cause?: EncodeError | string;
}

export interface CmdError {
  readonly __starshineBrand: "cmd.CmdError";
  readonly kind: string;
  readonly display: string;
  readonly cause?: unknown;
}

export interface CmdIO {
  readonly __starshineBrand: "cmd.CmdIO";
  readonly getEnv: (name: string) => string | null;
  readonly fileExists: (path: string) => boolean;
  readonly readFile: (path: string) => StarshineResult<Uint8Array, string>;
  readonly encodeModule: (mod: Module) => StarshineResult<Uint8Array, CmdEncodeError>;
  readonly writeFile: (path: string, bytes: Uint8Array) => StarshineResult<void, string>;
  readonly writeStdout: (bytes: Uint8Array) => StarshineResult<void, string>;
  readonly writeStderr: (bytes: Uint8Array) => StarshineResult<void, string>;
  readonly listCandidates: () => Array<string>;
  readonly lowerTextModule: (
    path: string,
    format: CliInputFormat,
    bytes: Uint8Array,
  ) => StarshineResult<Uint8Array, string>;
}

export interface CmdRunSummary {
  readonly __starshineBrand: "cmd.CmdRunSummary";
  readonly inputFiles: Array<string>;
  readonly outputFiles: Array<string>;
  readonly resolvedPasses: Array<string>;
  readonly optimizeLevel: number;
  readonly shrinkLevel: number;
  readonly trapsNeverHappen: boolean;
  readonly monomorphizeMinBenefit: number;
  readonly lowMemoryUnused: boolean;
  readonly lowMemoryBound: bigint;
}

export interface DifferentialAdapters {
  readonly __starshineBrand: "cmd.DifferentialAdapters";
  readonly wasmToolsValidate: (bytes: Uint8Array) => StarshineResult<boolean, string>;
  readonly binaryenValidate: (bytes: Uint8Array) => StarshineResult<boolean, string>;
}

export interface DifferentialValidationReport {
  readonly __starshineBrand: "cmd.DifferentialValidationReport";
  readonly internalValid: boolean;
  readonly wasmToolsValid: boolean | null;
  readonly binaryenValid: boolean | null;
}

export interface FuzzFailurePersistIO {
  readonly __starshineBrand: "cmd.FuzzFailurePersistIO";
  readonly ensureDir: (path: string) => StarshineResult<void, string>;
  readonly writeFile: (path: string, bytes: Uint8Array) => StarshineResult<void, string>;
}

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

export interface WasmSmithFuzzStats {
  readonly __starshineBrand: "cmd.WasmSmithFuzzStats";
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
export function runWasmSmithFuzzHarness(
  validTarget: number,
  seed?: bigint,
  optimizePasses?: Array<ModulePass>,
  optimizePassNames?: Array<string> | null,
  differentialAdapters?: DifferentialAdapters | null,
  differentialEvery?: number,
  onFailure?: ((report: FuzzFailureReport) => StarshineResult<void, string>) | null,
): StarshineResult<WasmSmithFuzzStats, string>;
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
  new(
    getEnv?: (name: string) => string | null,
    fileExists?: (path: string) => boolean,
    readFile?: (path: string) => StarshineResult<Uint8Array, string>,
    encodeModule?: (mod: Module) => StarshineResult<Uint8Array, CmdEncodeError>,
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
  new(
    inputFiles?: Array<string>,
    outputFiles?: Array<string>,
    resolvedPasses?: Array<string>,
    optimizeLevel?: number,
    shrinkLevel?: number,
    trapsNeverHappen?: boolean,
    monomorphizeMinBenefit?: number,
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

export const WasmSmithFuzzStats: {
  new(
    attempts?: number,
    generatedValid?: number,
    generatedInvalid?: number,
    pipelineValidated?: number,
    optimized?: number,
    roundtripped?: number,
    differentialChecked?: number,
  ): WasmSmithFuzzStats;
  show(value: WasmSmithFuzzStats): string;
};
