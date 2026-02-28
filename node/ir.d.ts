import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module, TExpr, TInstr, ValType } from "./lib.js";

export type BasicBlock = OpaqueHandle<"ir.BasicBlock">;
export type BlockId = OpaqueHandle<"ir.BlockId">;
export type CFG = OpaqueHandle<"ir.CFG">;
export type GVNKey = OpaqueHandle<"ir.GVNKey">;
export type GVNState = OpaqueHandle<"ir.GVNState">;
export type IRContext = OpaqueHandle<"ir.IRContext">;
export type LivenessInfo = OpaqueHandle<"ir.LivenessInfo">;
export type LocalGraph = OpaqueHandle<"ir.LocalGraph">;
export type LocalSet = OpaqueHandle<"ir.LocalSet">;
export type PhiNode = OpaqueHandle<"ir.PhiNode">;
export type SSABlock = OpaqueHandle<"ir.SSABlock">;
export type SSACFG = OpaqueHandle<"ir.SSACFG">;
export type SSADef = OpaqueHandle<"ir.SSADef">;
export type SSADestructor = OpaqueHandle<"ir.SSADestructor">;
export type SSAInstr = OpaqueHandle<"ir.SSAInstr">;
export type SSALiteral = OpaqueHandle<"ir.SSALiteral">;
export type SSAOp = OpaqueHandle<"ir.SSAOp">;
export type SSATerminator = OpaqueHandle<"ir.SSATerminator">;
export type SSATypeInfo = OpaqueHandle<"ir.SSATypeInfo">;
export type SSAUse = OpaqueHandle<"ir.SSAUse">;
export type SSAValue = OpaqueHandle<"ir.SSAValue">;
export type SplatOp = OpaqueHandle<"ir.SplatOp">;
export type Terminator = OpaqueHandle<"ir.Terminator">;
export type TypeContext = OpaqueHandle<"ir.TypeContext">;
export type UseDefInfo = OpaqueHandle<"ir.UseDefInfo">;

export function compatIsF32Nan(arg0: number): boolean;
export function compatIsF64Nan(arg0: number): boolean;
export function compatIsF64NonFinite(arg0: number): boolean;
export function compatTruncF64ToI64S(arg0: number): bigint | null;
export function compatTruncF64ToI64U(arg0: number): bigint | null;
export function inferSsaTypes(arg0: SSACFG, arg1: TypeContext): SSATypeInfo;
export function runGvn(arg0: SSACFG, arg1: OpaqueHandle<"Map[BlockId, BlockId]">): SSACFG;

export const BasicBlock: {
  show(value: BasicBlock): string;
};

export const BlockId: {
  inner(arg0: BlockId): number;
  show(value: BlockId): string;
};

export const CFG: {
  block(arg0: CFG, arg1: BlockId): BasicBlock | null;
  build(arg0: TExpr): CFG;
  dominanceFrontier(arg0: CFG): OpaqueHandle<"Map[BlockId, @set.Set[BlockId]]">;
  dominates(arg0: CFG, arg1: BlockId, arg2: BlockId): boolean;
  dominators(arg0: CFG): OpaqueHandle<"Map[BlockId, BlockId]">;
  entry(arg0: CFG): BlockId;
  predecessors(arg0: CFG, arg1: BlockId): Array<BlockId>;
  strictDominates(arg0: CFG, arg1: BlockId, arg2: BlockId): boolean;
  successors(arg0: CFG, arg1: BlockId): Array<BlockId>;
  toSsa(arg0: CFG, arg1: OpaqueHandle<"Map[BlockId, BlockId]">, arg2: OpaqueHandle<"Map[BlockId, @set.Set[BlockId]]">, arg3: number): SSACFG;
  validate(arg0: CFG): StarshineResult<void, string>;
  show(value: CFG): string;
};

export const GVNKey: {
};

export const GVNState: {
};

export const IRContext: {
  applyGvn(arg0: IRContext): void;
  applySsaOptimize(arg0: IRContext): void;
  cfgDirty(arg0: IRContext): void;
  getCfg(arg0: IRContext): CFG;
  getGvn(arg0: IRContext): SSACFG;
  getLiveness(arg0: IRContext): LivenessInfo;
  getLocalGraph(arg0: IRContext): LocalGraph;
  getMod(arg0: IRContext): Module | null;
  getSsa(arg0: IRContext): SSACFG;
  getTypeCtx(arg0: IRContext): StarshineResult<TypeContext, string>;
  getTypes(arg0: IRContext): SSATypeInfo | null;
  getUsedef(arg0: IRContext): UseDefInfo;
  gvnDirty(arg0: IRContext): void;
  livenessDirty(arg0: IRContext): void;
  localGraphDirty(arg0: IRContext): void;
  lowerToCfg(arg0: IRContext): CFG;
  new(): IRContext;
  optimizeBodyWithSsa(arg0: IRContext): TExpr | null;
  optimizeBodyWithSsaTrace(...args: never[]): never;
  setBody(arg0: IRContext, arg1: TExpr): void;
  setLocals(arg0: IRContext, arg1: Array<ValType>): void;
  setMod(arg0: IRContext, arg1: Module): void;
  ssaDirty(arg0: IRContext): void;
  typesDirty(arg0: IRContext): void;
  usedefDirty(arg0: IRContext): void;
  validate(arg0: IRContext): StarshineResult<void, string>;
};

export const LivenessInfo: {
  getLiveIn(arg0: LivenessInfo, arg1: BlockId): OpaqueHandle<"@set.Set[SSAValue]">;
  getLiveOut(arg0: LivenessInfo, arg1: BlockId): OpaqueHandle<"@set.Set[SSAValue]">;
  isLiveIn(arg0: LivenessInfo, arg1: BlockId, arg2: SSAValue): boolean;
  isLiveOut(arg0: LivenessInfo, arg1: BlockId, arg2: SSAValue): boolean;
};

export const LocalGraph: {
  getSets(arg0: LocalGraph, arg1: number): OpaqueHandle<"@set.Set[LocalSet]">;
  new(arg0: Array<TInstr>): LocalGraph;
};

export const LocalSet: {
};

export const PhiNode: {
  show(value: PhiNode): string;
};

export const SSABlock: {
  show(value: SSABlock): string;
};

export const SSACFG: {
  buildUseDef(arg0: SSACFG): UseDefInfo;
  computeLiveness(arg0: SSACFG): LivenessInfo;
  optimize(arg0: SSACFG): SSACFG;
  splitCriticalEdges(arg0: SSACFG): SSACFG;
  toCfg(arg0: SSACFG, arg1: number): CFG;
  show(value: SSACFG): string;
};

export const SSADef: {
};

export const SSADestructor: {
};

export const SSAInstr: {
  show(value: SSAInstr): string;
};

export const SSALiteral: {
  show(value: SSALiteral): string;
};

export const SSAOp: {
  show(value: SSAOp): string;
};

export const SSATerminator: {
  show(value: SSATerminator): string;
};

export const SSATypeInfo: {
  get(arg0: SSATypeInfo, arg1: SSAValue): ValType | null;
};

export const SSAUse: {
};

export const SSAValue: {
  inner(arg0: SSAValue): number;
  show(value: SSAValue): string;
};

export const SplatOp: {
  show(value: SplatOp): string;
};

export const Terminator: {
  show(value: Terminator): string;
};

export const TypeContext: {
  empty(): TypeContext;
  fromModule(arg0: Module, arg1: Array<ValType>): TypeContext;
};

export const UseDefInfo: {
  getDef(arg0: UseDefInfo, arg1: SSAValue): [BlockId, SSADef] | null;
  getUses(arg0: UseDefInfo, arg1: SSAValue): Array<SSAUse>;
  isDead(arg0: UseDefInfo, arg1: SSAValue): boolean;
};
