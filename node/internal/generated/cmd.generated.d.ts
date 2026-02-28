import type { OpaqueHandle, StarshineResult } from "../shared.js";
import type { EncodeError } from "../../binary.js";

export type CmdEncodeError = OpaqueHandle<"cmd.CmdEncodeError">;
export type CmdError = OpaqueHandle<"cmd.CmdError">;
export type CmdIO = OpaqueHandle<"cmd.CmdIO">;
export type CmdRunSummary = OpaqueHandle<"cmd.CmdRunSummary">;
export type DifferentialAdapters = OpaqueHandle<"cmd.DifferentialAdapters">;
export type DifferentialValidationReport = OpaqueHandle<"cmd.DifferentialValidationReport">;
export type FuzzFailurePersistIO = OpaqueHandle<"cmd.FuzzFailurePersistIO">;
export type FuzzFailureReport = OpaqueHandle<"cmd.FuzzFailureReport">;
export type ReadmeApiVerifyBlock = OpaqueHandle<"cmd.ReadmeApiVerifyBlock">;
export type WasmSmithFuzzStats = OpaqueHandle<"cmd.WasmSmithFuzzStats">;

export function cmdHelpText(): string;
export function cmdVersionText(): string;
export function differentialValidateWasm(arg0: Uint8Array, adapters?: DifferentialAdapters): StarshineResult<DifferentialValidationReport, string>;
export function minimizeFuzzPasses(...args: never[]): never;
export function nativeDifferentialToolsAvailable(): [boolean, boolean];
export function persistFuzzFailureReport(arg0: FuzzFailureReport, arg1: FuzzFailurePersistIO, corpusDir?: string): StarshineResult<[string, string | null], string>;
export function runCmd(arg0: Array<string>): StarshineResult<CmdRunSummary, CmdError>;
export function runCmdExitCode(arg0: Array<string>): number;
export function runCmdExitCodeWithAdapter(arg0: Array<string>, arg1: CmdIO, configJson?: string | null): number;
export function runCmdWithAdapter(arg0: Array<string>, arg1: CmdIO, configJson?: string | null): StarshineResult<CmdRunSummary, CmdError>;
export function runWasmSmithFuzzHarness(...args: never[]): never;
export function verifyReadmeApiSignatures(arg0: string, arg1: Array<[string, string]>): StarshineResult<void, string>;
export function verifyReadmeApiSignaturesWithRequiredBlocks(arg0: string, arg1: Array<[string, string]>, arg2: Array<string>): StarshineResult<void, string>;

export const CmdEncodeError: {
  adapter(arg0: string): CmdEncodeError;
  encode(arg0: EncodeError): CmdEncodeError;
  show(value: CmdEncodeError): string;
};

export const CmdError: {
  ambiguousOutputFile(arg0: string): CmdError;
  unknownPassFlag(arg0: string): CmdError;
  show(value: CmdError): string;
};

export const CmdIO: {
  new(...args: never[]): never;
};

export const CmdRunSummary: {
  new(inputFiles?: Array<string>, outputFiles?: Array<string>, resolvedPasses?: Array<string>, optimizeLevel?: number, shrinkLevel?: number, trapsNeverHappen?: boolean, monomorphizeMinBenefit?: number, lowMemoryUnused?: boolean, lowMemoryBound?: bigint): CmdRunSummary;
  show(value: CmdRunSummary): string;
};

export const DifferentialAdapters: {
  new(...args: never[]): never;
};

export const DifferentialValidationReport: {
  show(value: DifferentialValidationReport): string;
};

export const FuzzFailurePersistIO: {
  new(...args: never[]): never;
};

export const FuzzFailureReport: {
  new(arg0: bigint, arg1: number, arg2: number, arg3: string, arg4: string, optimizePasses?: Array<string>, minimizedPasses?: Array<string>, wasm?: Uint8Array | null): FuzzFailureReport;
  show(value: FuzzFailureReport): string;
};

export const ReadmeApiVerifyBlock: {
  show(value: ReadmeApiVerifyBlock): string;
};

export const WasmSmithFuzzStats: {
  new(attempts?: number, generatedValid?: number, generatedInvalid?: number, pipelineValidated?: number, optimized?: number, roundtripped?: number, differentialChecked?: number): WasmSmithFuzzStats;
  show(value: WasmSmithFuzzStats): string;
};
