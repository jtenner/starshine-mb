import type { OpaqueHandle, StarshineResult } from "../shared.js";
import type { Module } from "../../lib.js";

export type AbstractTypeRefiningPassProps = OpaqueHandle<"passes.AbstractTypeRefiningPassProps">;
export type AsyncifyPassProps = OpaqueHandle<"passes.AsyncifyPassProps">;
export type BlockLiveness = OpaqueHandle<"passes.BlockLiveness">;
export type CFPState = OpaqueHandle<"passes.CFPState">;
export type ConstHoistingState = OpaqueHandle<"passes.ConstHoistingState">;
export type ConstKey = OpaqueHandle<"passes.ConstKey">;
export type EquivalentClass = OpaqueHandle<"passes.EquivalentClass">;
export type FieldValue = OpaqueHandle<"passes.FieldValue">;
export type ILCallKind = OpaqueHandle<"passes.ILCallKind">;
export type ILTrivialKind = OpaqueHandle<"passes.ILTrivialKind">;
export type InliningOptions = OpaqueHandle<"passes.InliningOptions">;
export type Literal = OpaqueHandle<"passes.Literal">;
export type LiteralKind = OpaqueHandle<"passes.LiteralKind">;
export type MSFCallSite = OpaqueHandle<"passes.MSFCallSite">;
export type MSFDefinedFunc = OpaqueHandle<"passes.MSFDefinedFunc">;
export type MSFHashBucketKey = OpaqueHandle<"passes.MSFHashBucketKey">;
export type MSFHashState = OpaqueHandle<"passes.MSFHashState">;
export type MSFOrderedSite = OpaqueHandle<"passes.MSFOrderedSite">;
export type MSFParamKey = OpaqueHandle<"passes.MSFParamKey">;
export type MSFParamKind = OpaqueHandle<"passes.MSFParamKind">;
export type MSFSiteValue = OpaqueHandle<"passes.MSFSiteValue">;
export type MemoryPackingPassProps = OpaqueHandle<"passes.MemoryPackingPassProps">;
export type ModulePass = OpaqueHandle<"passes.ModulePass">;
export type OptimizeOptions = OpaqueHandle<"passes.OptimizeOptions">;
export type OptimizePostEncodeFailureRepro = OpaqueHandle<"passes.OptimizePostEncodeFailureRepro">;
export type OptimizeTracingLevel = OpaqueHandle<"passes.OptimizeTracingLevel">;
export type OptimizeValidationPolicy = OpaqueHandle<"passes.OptimizeValidationPolicy">;
export type ParamInfo = OpaqueHandle<"passes.ParamInfo">;
export type SquareMatrix = OpaqueHandle<"passes.SquareMatrix">;
export type Tail = OpaqueHandle<"passes.Tail">;

export function defaultFunctionOptimizationPasses(arg0: Module, arg1: OptimizeOptions): Array<ModulePass>;
export function defaultGlobalOptimizationPostPasses(arg0: Module, arg1: OptimizeOptions): Array<ModulePass>;
export function defaultGlobalOptimizationPrePasses(arg0: Module, arg1: OptimizeOptions, closedWorld?: boolean): Array<ModulePass>;
export function optimizeFindPostEncodeFailureSegment(arg0: Module, arg1: Array<ModulePass>, arg2: OptimizeOptions): StarshineResult<OptimizePostEncodeFailureRepro | null, string>;
export function optimizeFindPostEncodeFailureSegmentWithProbe(...args: never[]): never;
export function optimizeModule(arg0: Module, arg1: Array<ModulePass>): StarshineResult<Module, string>;
export function optimizeModuleWithOptions(arg0: Module, arg1: Array<ModulePass>, arg2: OptimizeOptions): StarshineResult<Module, string>;
export function optimizeModuleWithOptionsTrace(...args: never[]): never;

export const AbstractTypeRefiningPassProps: {
  new(trapsNeverHappen?: boolean): AbstractTypeRefiningPassProps;
  show(value: AbstractTypeRefiningPassProps): string;
};

export const AsyncifyPassProps: {
  show(value: AsyncifyPassProps): string;
};

export const BlockLiveness: {
  show(value: BlockLiveness): string;
};

export const CFPState: {
};

export const ConstHoistingState: {
};

export const ConstKey: {
};

export const EquivalentClass: {
  show(value: EquivalentClass): string;
};

export const FieldValue: {
};

export const ILCallKind: {
};

export const ILTrivialKind: {
};

export const InliningOptions: {
  new(alwaysInlineMaxSize?: number, oneCallerInlineMaxSize?: number, flexibleInlineMaxSize?: number, maxCombinedBinarySize?: number, allowFunctionsWithLoops?: boolean, partialInliningIfs?: number): InliningOptions;
};

export const Literal: {
  show(value: Literal): string;
};

export const LiteralKind: {
  show(value: LiteralKind): string;
};

export const MSFCallSite: {
  show(value: MSFCallSite): string;
};

export const MSFDefinedFunc: {
  show(value: MSFDefinedFunc): string;
};

export const MSFHashBucketKey: {
};

export const MSFHashState: {
  show(value: MSFHashState): string;
};

export const MSFOrderedSite: {
  show(value: MSFOrderedSite): string;
};

export const MSFParamKey: {
};

export const MSFParamKind: {
  show(value: MSFParamKind): string;
};

export const MSFSiteValue: {
  show(value: MSFSiteValue): string;
};

export const MemoryPackingPassProps: {
  new(zeroFilledMemory?: boolean, trapsNeverHappen?: boolean, maxDataSegments?: number): MemoryPackingPassProps;
  show(value: MemoryPackingPassProps): string;
};

export const ModulePass: {
  show(value: ModulePass): string;
};

export const OptimizeOptions: {
  new(optimizeLevel?: number, shrinkLevel?: number, inlining?: InliningOptions, monomorphizeMinBenefit?: number, lowMemoryUnused?: boolean, lowMemoryBound?: bigint, trapsNeverHappen?: boolean, validationPolicy?: OptimizeValidationPolicy, stackFunctionPasses?: boolean): OptimizeOptions;
};

export const OptimizePostEncodeFailureRepro: {
  new(arg0: Module, arg1: Array<ModulePass>): OptimizePostEncodeFailureRepro;
  show(value: OptimizePostEncodeFailureRepro): string;
};

export const OptimizeTracingLevel: {
  helper(): OptimizeTracingLevel;
  pass(): OptimizeTracingLevel;
  phase(): OptimizeTracingLevel;
  show(value: OptimizeTracingLevel): string;
};

export const OptimizeValidationPolicy: {
  afterSegment(): OptimizeValidationPolicy;
  finalModuleOnly(): OptimizeValidationPolicy;
  show(value: OptimizeValidationPolicy): string;
};

export const ParamInfo: {
  show(value: ParamInfo): string;
};

export const SquareMatrix: {
};

export const Tail: {
};
