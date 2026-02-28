import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { PrettyPrintContext } from "./lib.js";
import type { Module, TokenType, WastScript } from "./wast.js";

export function lookupKeyword(arg0: string): TokenType | null;
export function moduleToWat(arg0: Module): StarshineResult<string, string>;
export function moduleToWatWithContext(arg0: Module, arg1: PrettyPrintContext): StarshineResult<string, string>;
export function scriptToWat(arg0: WastScript): StarshineResult<string, string>;
export function scriptToWatWithContext(arg0: WastScript, arg1: PrettyPrintContext): StarshineResult<string, string>;
export function watToModule(arg0: string, filename?: string): StarshineResult<Module, string>;
export function watToScript(arg0: string, filename?: string): StarshineResult<WastScript, string>;
