import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module as lib_Module, PrettyPrintContext as lib_PrettyPrintContext } from "./lib.js";
import type { Module as wast_Module, TokenType as wast_TokenType, WastScript as wast_WastScript } from "./wast.js";

export type WatRoundtripFuzzStats = OpaqueHandle<"wat.WatRoundtripFuzzStats">;

export function libModuleToWat(arg0: lib_Module): StarshineResult<string, string>;
export function lookupKeyword(arg0: string): (wast_TokenType) | null;
export function moduleToWat(arg0: wast_Module): StarshineResult<string, string>;
export function moduleToWatWithContext(arg0: wast_Module, arg1: lib_PrettyPrintContext): StarshineResult<string, string>;
export function runWatRoundtripFuzz(arg0: string, arg1: bigint): StarshineResult<WatRoundtripFuzzStats, string>;
export function scriptToWat(arg0: wast_WastScript): StarshineResult<string, string>;
export function scriptToWatWithContext(arg0: wast_WastScript, arg1: lib_PrettyPrintContext): StarshineResult<string, string>;
export function watToModule(arg0: string, filename?: string): StarshineResult<wast_Module, string>;
export function watToScript(arg0: string, filename?: string): StarshineResult<wast_WastScript, string>;

export const WatRoundtripFuzzStats: {
};
