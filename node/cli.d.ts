import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";

export const defaultConfigPath: string;

export type CliInputFormat = OpaqueHandle<"cli.CliInputFormat">;
export type CliOptimizationFlag = OpaqueHandle<"cli.CliOptimizationFlag">;
export type CliOutputTarget = OpaqueHandle<"cli.CliOutputTarget">;
export type CliParseError = OpaqueHandle<"cli.CliParseError">;
export type CliParseResult = OpaqueHandle<"cli.CliParseResult">;
export type TrapMode = OpaqueHandle<"cli.TrapMode">;

export function cliConfigSchemaJson(): string;
export function expandGlobs(arg0: Array<string>, arg1: Array<string>): Array<string>;
export function expandGlobsWithAdapter(...args: never[]): never;
export function globMatch(arg0: string, arg1: string): boolean;
export function inferInputFormat(arg0: string): CliInputFormat | null;
export function normalizeCliPath(arg0: string): string;
export function parseCliArgs(arg0: Array<string>, starshineInput?: string | null): StarshineResult<CliParseResult, CliParseError>;
export function parseStarshineInputEnv(arg0: string | null): Array<string>;
export function resolvePassFlags(arg0: CliParseResult): Array<string>;
export function resolveTrapsNeverHappen(arg0: CliParseResult, defaultArg?: boolean): boolean;

export const CliInputFormat: {
  wasm(): CliInputFormat;
  wast(): CliInputFormat;
  wat(): CliInputFormat;
  show(value: CliInputFormat): string;
};

export const CliOptimizationFlag: {
  olevel(arg0: number, arg1: boolean): CliOptimizationFlag;
  optimize(): CliOptimizationFlag;
  shrink(): CliOptimizationFlag;
  show(value: CliOptimizationFlag): string;
};

export const CliOutputTarget: {
  dir(arg0: string): CliOutputTarget;
  file(arg0: string): CliOutputTarget;
  stdout(): CliOutputTarget;
  show(value: CliOutputTarget): string;
};

export const CliParseError: {
  invalidInputFormat(arg0: string): CliParseError;
  invalidLongFlag(arg0: string): CliParseError;
  invalidOptimizationFlag(arg0: string): CliParseError;
  invalidTrapMode(arg0: string): CliParseError;
  missingFlagValue(arg0: string): CliParseError;
  stdinNeedsFormat(): CliParseError;
  unexpectedFlagValue(arg0: string): CliParseError;
  unknownShortFlag(arg0: number): CliParseError;
  show(value: CliParseError): string;
};

export const CliParseResult: {
  new(configPath?: string | null, inputGlobs?: Array<string>, globEnabled?: boolean, helpRequested?: boolean, versionRequested?: boolean, readStdin?: boolean, inputFormat?: CliInputFormat | null, outputTargets?: Array<CliOutputTarget>, passFlags?: Array<string>, optimizeFlags?: Array<CliOptimizationFlag>, trapMode?: TrapMode | null, monomorphizeMinBenefit?: number | null, lowMemoryUnused?: boolean | null, lowMemoryBound?: bigint | null): CliParseResult;
  show(value: CliParseResult): string;
};

export const TrapMode: {
  allow(): TrapMode;
  never(): TrapMode;
  show(value: TrapMode): string;
};
