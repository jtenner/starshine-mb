///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
using @lib {
  expand_locals,
  sub_type,
  single_rec_type,
  comp_type_sub_type,
  struct_comp_type,
  func_idx,
  func_comp_type,
  table_idx,
  tlocals_to_locals,
  type AbsHeapType,
  type TInstr,
  type TInstrKind,
  type LocalIdx,
  type ValType,
  type Func,
  type LoadOp,
  type StoreOp,
  type AtomicRmwOp,
  type AtomicCmpxchgOp,
  type V128LoadLaneOp,
  type MemType,
  type TExpr,
  type I32,
  type I64,
  type F32,
  type F64,
  type U32,
  type FuncIdx,
  type TableIdx,
  type TypeIdx,
  type Module,
  type LabelIdx,
  type RecType,
  type HeapType,
  type ElemKind,
  type Instruction,
  type Expr,
  type Elem,
  type ElemSec,
  type Limits,
  type TableSec,
  type Table,
  type BlockType,
  type Catch,
  type BinaryOp,
  type MemArg,
  type LaneIdx,
  type ReplaceLaneOp,
  type UnaryOp,
  type CodeSec,
  type RefType,
  type ElemMode,
  type MemIdx,
  type ElemIdx,
  type GlobalIdx,
  type TableType,
  type GlobalType,
  type Global,
  type TypeSec,
  type FuncSec,
  type GlobalSec,
  type SubType,
  type CompType,
  type FuncType,
  type ImportSec,
  type MemSec,
  type TagIdx,
  type DataIdx,
  type DataSec,
  type TagSec,
  type ExportSec,
  type StartSec,
  type ExternType,
  type Import,
  type DataCntSec,
  type ExternIdx,
  type Export,
  type Name,
  type Data,
  type DataMode,
  type Locals,
  type FieldType,
  type PackType,
  type StorageType,
  type TagType,
}

///|
using @binary {size_signed}

///|
using @transformer {
  type ModuleTransformer,
  type TransformerResult,
  change,
  unchanged,
}

///|
using @validate {type Env, to_texpr, validate_module, trait Match}

///|
using @ir {
  type IRContext,
  type LocalGraph,
  type LocalSet,
  compat_is_f32_nan,
  compat_is_f64_nan,
  compat_is_f64_non_finite,
  compat_trunc_f64_to_i64_s,
  compat_trunc_f64_to_i64_u,
}
