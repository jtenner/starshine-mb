///|
using @lib {
  type CodeSec,
  type CompType,
  type Data,
  type DataCntSec,
  type DataIdx,
  type DataSec,
  type Elem,
  type ElemIdx,
  type ElemSec,
  type ExternType,
  type Func,
  type FuncIdx,
  type FuncSec,
  type FuncType,
  type Global,
  type GlobalIdx,
  type GlobalSec,
  type Import,
  type ImportSec,
  type IndirectNameAssoc,
  type IndirectNameMap,
  type Module,
  type MemIdx,
  type MemSec,
  type MemType,
  type NameAssoc,
  type NameMap,
  type NameSec,
  type RecType,
  type SubType,
  type Table,
  type TableIdx,
  type TableSec,
  type TagIdx,
  type TagSec,
  type TagType,
  type TypeIdx,
  type U32,
}

///|
using @transformer {type ModuleTransformer, change, skip, unchanged}

///|
using @validate {validate_module}
