import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module } from "./lib.js";

export type BinaryDecodeError = OpaqueHandle<"binary.BinaryDecodeError">;
export type BinaryEncodeError = OpaqueHandle<"binary.BinaryEncodeError">;
export type DecodeError = OpaqueHandle<"binary.DecodeError">;
export type EncodeError = OpaqueHandle<"binary.EncodeError">;
export type ModuleDecodeErrorDetail = OpaqueHandle<"binary.ModuleDecodeErrorDetail">;

export function decodeModule(arg0: Uint8Array): StarshineResult<Module, DecodeError>;
export function decodeModuleWithDetail(arg0: Uint8Array, arg1: number): StarshineResult<[Module, number], ModuleDecodeErrorDetail>;
export function encodeModule(arg0: Module): StarshineResult<Uint8Array, EncodeError>;
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
  show(value: ModuleDecodeErrorDetail): string;
};
