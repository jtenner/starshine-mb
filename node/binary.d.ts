import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Expr as lib_Expr, Instruction as lib_Instruction, Module as lib_Module } from "./lib.js";

export type BinaryDecodeError = OpaqueHandle<"binary.BinaryDecodeError">;
export type BinaryEncodeError = OpaqueHandle<"binary.BinaryEncodeError">;
export type DecodeError = OpaqueHandle<"binary.DecodeError">;
export type EncodeError = OpaqueHandle<"binary.EncodeError">;
export type ModuleDecodeErrorDetail = OpaqueHandle<"binary.ModuleDecodeErrorDetail">;

export function compilerFactModuleOpcodeOffsets(arg0: lib_Module): StarshineResult<Array<Array<number>>, BinaryEncodeError>;
export function compilerFactModuleOpcodeSites(arg0: lib_Module): StarshineResult<Array<Array<[number, lib_Instruction]>>, BinaryEncodeError>;
export function compilerFactOpcodeOffsets(arg0: lib_Expr, stringrefs?: (Array<Uint8Array>) | null): StarshineResult<Array<number>, BinaryEncodeError>;
export function compilerFactOpcodeSites(arg0: lib_Expr, stringrefs?: (Array<Uint8Array>) | null): StarshineResult<Array<[number, lib_Instruction]>, BinaryEncodeError>;
export function decodeModule(arg0: Uint8Array): StarshineResult<lib_Module, DecodeError>;
export function decodeModuleWithDetail(arg0: Uint8Array, arg1: number): StarshineResult<[lib_Module, number], ModuleDecodeErrorDetail>;
export function encodeModule(arg0: lib_Module, compactImports?: boolean): StarshineResult<Uint8Array, EncodeError>;
export function encodedModuleSizes(arg0: lib_Module, arg1: lib_Module): StarshineResult<[number, number], EncodeError>;
export function sizeSigned(arg0: bigint, arg1: number): StarshineResult<number, BinaryEncodeError>;
export function sizeUnsigned(arg0: bigint, arg1: number): StarshineResult<number, BinaryEncodeError>;

export const BinaryDecodeError: {
  show(value: BinaryDecodeError): string;
};

export const BinaryEncodeError: {
  show(value: BinaryEncodeError): string;
};

export const DecodeError: {
  show(value: DecodeError): string;
};

export const EncodeError: {
  show(value: EncodeError): string;
};

export const ModuleDecodeErrorDetail: {
};
