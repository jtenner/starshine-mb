import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module as lib_Module } from "./lib.js";

export function optimizeModule(arg0: lib_Module, arg1: Array<string>, optimizeLevel?: number, shrinkLevel?: number): StarshineResult<lib_Module, string>;
