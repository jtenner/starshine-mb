// Generated from src/lib/pkg.generated.mbti. DO NOT EDIT.

///|
fn core_ir_bytes(value : FixedArray[Byte]) -> Bytes {
  Bytes::from_iter(value.iter())
}

///|
fn core_ir_bytes_option(value : FixedArray[Byte]?) -> Bytes? {
  match value {
    Some(value) => Some(core_ir_bytes(value))
    None => None
  }
}

///|
fn core_ir_bytes_array(values : Array[FixedArray[Byte]]) -> Array[Bytes] {
  values.map(fn(value) { core_ir_bytes(value) })
}

///|
fn core_ir_byte_array(value : FixedArray[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  for byte in value {
    result.push(byte)
  }
  result
}

///|
let core_ir_abs_heap_type_values : Array[@lib.AbsHeapType?] = []

///|
let core_ir_abs_heap_type_free_reps : Array[Int] = []

///|
fn core_ir_abs_heap_type_store(value : @lib.AbsHeapType) -> AbsHeapType {
  let rep = match core_ir_abs_heap_type_free_reps.pop() {
    Some(rep) => {
      core_ir_abs_heap_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_abs_heap_type_values.length()
      core_ir_abs_heap_type_values.push(Some(value))
      rep
    }
  }
  AbsHeapType::new(rep)
}

///|
fn core_ir_abs_heap_type_get(value : AbsHeapType) -> @lib.AbsHeapType {
  let AbsHeapType(rep) = value
  if rep < 0 || rep >= core_ir_abs_heap_type_values.length() {
    abort("invalid core-ir abs-heap-type handle")
  }
  match core_ir_abs_heap_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir abs-heap-type handle")
  }
}

///|
fn core_ir_abs_heap_type_option(value : AbsHeapType?) -> @lib.AbsHeapType? {
  match value {
    Some(value) => Some(core_ir_abs_heap_type_get(value))
    None => None
  }
}

///|
fn core_ir_abs_heap_type_array(values : Array[AbsHeapType]) -> Array[@lib.AbsHeapType] {
  values.map(fn(value) { core_ir_abs_heap_type_get(value) })
}

///|
pub fn AbsHeapType::dtor(self : AbsHeapType) -> Unit {
  let AbsHeapType(rep) = self
  if rep >= 0 && rep < core_ir_abs_heap_type_values.length() {
    core_ir_abs_heap_type_values[rep] = None
    core_ir_abs_heap_type_free_reps.push(rep)
  }
}

///|
let core_ir_aggregate_atomic_rmw_op_values : Array[@lib.AggregateAtomicRmwOp?] = []

///|
let core_ir_aggregate_atomic_rmw_op_free_reps : Array[Int] = []

///|
fn core_ir_aggregate_atomic_rmw_op_store(value : @lib.AggregateAtomicRmwOp) -> AggregateAtomicRmwOp {
  let rep = match core_ir_aggregate_atomic_rmw_op_free_reps.pop() {
    Some(rep) => {
      core_ir_aggregate_atomic_rmw_op_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_aggregate_atomic_rmw_op_values.length()
      core_ir_aggregate_atomic_rmw_op_values.push(Some(value))
      rep
    }
  }
  AggregateAtomicRmwOp::new(rep)
}

///|
fn core_ir_aggregate_atomic_rmw_op_get(value : AggregateAtomicRmwOp) -> @lib.AggregateAtomicRmwOp {
  let AggregateAtomicRmwOp(rep) = value
  if rep < 0 || rep >= core_ir_aggregate_atomic_rmw_op_values.length() {
    abort("invalid core-ir aggregate-atomic-rmw-op handle")
  }
  match core_ir_aggregate_atomic_rmw_op_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir aggregate-atomic-rmw-op handle")
  }
}

///|
fn core_ir_aggregate_atomic_rmw_op_option(value : AggregateAtomicRmwOp?) -> @lib.AggregateAtomicRmwOp? {
  match value {
    Some(value) => Some(core_ir_aggregate_atomic_rmw_op_get(value))
    None => None
  }
}

///|
fn core_ir_aggregate_atomic_rmw_op_array(values : Array[AggregateAtomicRmwOp]) -> Array[@lib.AggregateAtomicRmwOp] {
  values.map(fn(value) { core_ir_aggregate_atomic_rmw_op_get(value) })
}

///|
pub fn AggregateAtomicRmwOp::dtor(self : AggregateAtomicRmwOp) -> Unit {
  let AggregateAtomicRmwOp(rep) = self
  if rep >= 0 && rep < core_ir_aggregate_atomic_rmw_op_values.length() {
    core_ir_aggregate_atomic_rmw_op_values[rep] = None
    core_ir_aggregate_atomic_rmw_op_free_reps.push(rep)
  }
}

///|
let core_ir_atomic_cmpxchg_op_values : Array[@lib.AtomicCmpxchgOp?] = []

///|
let core_ir_atomic_cmpxchg_op_free_reps : Array[Int] = []

///|
fn core_ir_atomic_cmpxchg_op_store(value : @lib.AtomicCmpxchgOp) -> AtomicCmpxchgOp {
  let rep = match core_ir_atomic_cmpxchg_op_free_reps.pop() {
    Some(rep) => {
      core_ir_atomic_cmpxchg_op_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_atomic_cmpxchg_op_values.length()
      core_ir_atomic_cmpxchg_op_values.push(Some(value))
      rep
    }
  }
  AtomicCmpxchgOp::new(rep)
}

///|
fn core_ir_atomic_cmpxchg_op_get(value : AtomicCmpxchgOp) -> @lib.AtomicCmpxchgOp {
  let AtomicCmpxchgOp(rep) = value
  if rep < 0 || rep >= core_ir_atomic_cmpxchg_op_values.length() {
    abort("invalid core-ir atomic-cmpxchg-op handle")
  }
  match core_ir_atomic_cmpxchg_op_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir atomic-cmpxchg-op handle")
  }
}

///|
fn core_ir_atomic_cmpxchg_op_option(value : AtomicCmpxchgOp?) -> @lib.AtomicCmpxchgOp? {
  match value {
    Some(value) => Some(core_ir_atomic_cmpxchg_op_get(value))
    None => None
  }
}

///|
fn core_ir_atomic_cmpxchg_op_array(values : Array[AtomicCmpxchgOp]) -> Array[@lib.AtomicCmpxchgOp] {
  values.map(fn(value) { core_ir_atomic_cmpxchg_op_get(value) })
}

///|
pub fn AtomicCmpxchgOp::dtor(self : AtomicCmpxchgOp) -> Unit {
  let AtomicCmpxchgOp(rep) = self
  if rep >= 0 && rep < core_ir_atomic_cmpxchg_op_values.length() {
    core_ir_atomic_cmpxchg_op_values[rep] = None
    core_ir_atomic_cmpxchg_op_free_reps.push(rep)
  }
}

///|
let core_ir_atomic_order_values : Array[@lib.AtomicOrder?] = []

///|
let core_ir_atomic_order_free_reps : Array[Int] = []

///|
fn core_ir_atomic_order_store(value : @lib.AtomicOrder) -> AtomicOrder {
  let rep = match core_ir_atomic_order_free_reps.pop() {
    Some(rep) => {
      core_ir_atomic_order_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_atomic_order_values.length()
      core_ir_atomic_order_values.push(Some(value))
      rep
    }
  }
  AtomicOrder::new(rep)
}

///|
fn core_ir_atomic_order_get(value : AtomicOrder) -> @lib.AtomicOrder {
  let AtomicOrder(rep) = value
  if rep < 0 || rep >= core_ir_atomic_order_values.length() {
    abort("invalid core-ir atomic-order handle")
  }
  match core_ir_atomic_order_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir atomic-order handle")
  }
}

///|
fn core_ir_atomic_order_option(value : AtomicOrder?) -> @lib.AtomicOrder? {
  match value {
    Some(value) => Some(core_ir_atomic_order_get(value))
    None => None
  }
}

///|
fn core_ir_atomic_order_array(values : Array[AtomicOrder]) -> Array[@lib.AtomicOrder] {
  values.map(fn(value) { core_ir_atomic_order_get(value) })
}

///|
pub fn AtomicOrder::dtor(self : AtomicOrder) -> Unit {
  let AtomicOrder(rep) = self
  if rep >= 0 && rep < core_ir_atomic_order_values.length() {
    core_ir_atomic_order_values[rep] = None
    core_ir_atomic_order_free_reps.push(rep)
  }
}

///|
let core_ir_atomic_rmw_op_values : Array[@lib.AtomicRmwOp?] = []

///|
let core_ir_atomic_rmw_op_free_reps : Array[Int] = []

///|
fn core_ir_atomic_rmw_op_store(value : @lib.AtomicRmwOp) -> AtomicRmwOp {
  let rep = match core_ir_atomic_rmw_op_free_reps.pop() {
    Some(rep) => {
      core_ir_atomic_rmw_op_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_atomic_rmw_op_values.length()
      core_ir_atomic_rmw_op_values.push(Some(value))
      rep
    }
  }
  AtomicRmwOp::new(rep)
}

///|
fn core_ir_atomic_rmw_op_get(value : AtomicRmwOp) -> @lib.AtomicRmwOp {
  let AtomicRmwOp(rep) = value
  if rep < 0 || rep >= core_ir_atomic_rmw_op_values.length() {
    abort("invalid core-ir atomic-rmw-op handle")
  }
  match core_ir_atomic_rmw_op_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir atomic-rmw-op handle")
  }
}

///|
fn core_ir_atomic_rmw_op_option(value : AtomicRmwOp?) -> @lib.AtomicRmwOp? {
  match value {
    Some(value) => Some(core_ir_atomic_rmw_op_get(value))
    None => None
  }
}

///|
fn core_ir_atomic_rmw_op_array(values : Array[AtomicRmwOp]) -> Array[@lib.AtomicRmwOp] {
  values.map(fn(value) { core_ir_atomic_rmw_op_get(value) })
}

///|
pub fn AtomicRmwOp::dtor(self : AtomicRmwOp) -> Unit {
  let AtomicRmwOp(rep) = self
  if rep >= 0 && rep < core_ir_atomic_rmw_op_values.length() {
    core_ir_atomic_rmw_op_values[rep] = None
    core_ir_atomic_rmw_op_free_reps.push(rep)
  }
}

///|
let core_ir_block_type_values : Array[@lib.BlockType?] = []

///|
let core_ir_block_type_free_reps : Array[Int] = []

///|
fn core_ir_block_type_store(value : @lib.BlockType) -> BlockType {
  let rep = match core_ir_block_type_free_reps.pop() {
    Some(rep) => {
      core_ir_block_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_block_type_values.length()
      core_ir_block_type_values.push(Some(value))
      rep
    }
  }
  BlockType::new(rep)
}

///|
fn core_ir_block_type_get(value : BlockType) -> @lib.BlockType {
  let BlockType(rep) = value
  if rep < 0 || rep >= core_ir_block_type_values.length() {
    abort("invalid core-ir block-type handle")
  }
  match core_ir_block_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir block-type handle")
  }
}

///|
fn core_ir_block_type_option(value : BlockType?) -> @lib.BlockType? {
  match value {
    Some(value) => Some(core_ir_block_type_get(value))
    None => None
  }
}

///|
fn core_ir_block_type_array(values : Array[BlockType]) -> Array[@lib.BlockType] {
  values.map(fn(value) { core_ir_block_type_get(value) })
}

///|
pub fn BlockType::dtor(self : BlockType) -> Unit {
  let BlockType(rep) = self
  if rep >= 0 && rep < core_ir_block_type_values.length() {
    core_ir_block_type_values[rep] = None
    core_ir_block_type_free_reps.push(rep)
  }
}

///|
let core_ir_catch_values : Array[@lib.Catch?] = []

///|
let core_ir_catch_free_reps : Array[Int] = []

///|
fn core_ir_catch_store(value : @lib.Catch) -> Catch {
  let rep = match core_ir_catch_free_reps.pop() {
    Some(rep) => {
      core_ir_catch_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_catch_values.length()
      core_ir_catch_values.push(Some(value))
      rep
    }
  }
  Catch::new(rep)
}

///|
fn core_ir_catch_get(value : Catch) -> @lib.Catch {
  let Catch(rep) = value
  if rep < 0 || rep >= core_ir_catch_values.length() {
    abort("invalid core-ir catch handle")
  }
  match core_ir_catch_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir catch handle")
  }
}

///|
fn core_ir_catch_option(value : Catch?) -> @lib.Catch? {
  match value {
    Some(value) => Some(core_ir_catch_get(value))
    None => None
  }
}

///|
fn core_ir_catch_array(values : Array[Catch]) -> Array[@lib.Catch] {
  values.map(fn(value) { core_ir_catch_get(value) })
}

///|
pub fn Catch::dtor(self : Catch) -> Unit {
  let Catch(rep) = self
  if rep >= 0 && rep < core_ir_catch_values.length() {
    core_ir_catch_values[rep] = None
    core_ir_catch_free_reps.push(rep)
  }
}

///|
let core_ir_code_sec_values : Array[@lib.CodeSec?] = []

///|
let core_ir_code_sec_free_reps : Array[Int] = []

///|
fn core_ir_code_sec_store(value : @lib.CodeSec) -> CodeSec {
  let rep = match core_ir_code_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_code_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_code_sec_values.length()
      core_ir_code_sec_values.push(Some(value))
      rep
    }
  }
  CodeSec::new(rep)
}

///|
fn core_ir_code_sec_get(value : CodeSec) -> @lib.CodeSec {
  let CodeSec(rep) = value
  if rep < 0 || rep >= core_ir_code_sec_values.length() {
    abort("invalid core-ir code-sec handle")
  }
  match core_ir_code_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir code-sec handle")
  }
}

///|
fn core_ir_code_sec_option(value : CodeSec?) -> @lib.CodeSec? {
  match value {
    Some(value) => Some(core_ir_code_sec_get(value))
    None => None
  }
}

///|
fn core_ir_code_sec_array(values : Array[CodeSec]) -> Array[@lib.CodeSec] {
  values.map(fn(value) { core_ir_code_sec_get(value) })
}

///|
pub fn CodeSec::dtor(self : CodeSec) -> Unit {
  let CodeSec(rep) = self
  if rep >= 0 && rep < core_ir_code_sec_values.length() {
    core_ir_code_sec_values[rep] = None
    core_ir_code_sec_free_reps.push(rep)
  }
}

///|
let core_ir_comp_type_values : Array[@lib.CompType?] = []

///|
let core_ir_comp_type_free_reps : Array[Int] = []

///|
fn core_ir_comp_type_store(value : @lib.CompType) -> CompType {
  let rep = match core_ir_comp_type_free_reps.pop() {
    Some(rep) => {
      core_ir_comp_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_comp_type_values.length()
      core_ir_comp_type_values.push(Some(value))
      rep
    }
  }
  CompType::new(rep)
}

///|
fn core_ir_comp_type_get(value : CompType) -> @lib.CompType {
  let CompType(rep) = value
  if rep < 0 || rep >= core_ir_comp_type_values.length() {
    abort("invalid core-ir comp-type handle")
  }
  match core_ir_comp_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir comp-type handle")
  }
}

///|
fn core_ir_comp_type_option(value : CompType?) -> @lib.CompType? {
  match value {
    Some(value) => Some(core_ir_comp_type_get(value))
    None => None
  }
}

///|
fn core_ir_comp_type_array(values : Array[CompType]) -> Array[@lib.CompType] {
  values.map(fn(value) { core_ir_comp_type_get(value) })
}

///|
pub fn CompType::dtor(self : CompType) -> Unit {
  let CompType(rep) = self
  if rep >= 0 && rep < core_ir_comp_type_values.length() {
    core_ir_comp_type_values[rep] = None
    core_ir_comp_type_free_reps.push(rep)
  }
}

///|
let core_ir_custom_sec_values : Array[@lib.CustomSec?] = []

///|
let core_ir_custom_sec_free_reps : Array[Int] = []

///|
fn core_ir_custom_sec_store(value : @lib.CustomSec) -> CustomSec {
  let rep = match core_ir_custom_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_custom_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_custom_sec_values.length()
      core_ir_custom_sec_values.push(Some(value))
      rep
    }
  }
  CustomSec::new(rep)
}

///|
fn core_ir_custom_sec_get(value : CustomSec) -> @lib.CustomSec {
  let CustomSec(rep) = value
  if rep < 0 || rep >= core_ir_custom_sec_values.length() {
    abort("invalid core-ir custom-sec handle")
  }
  match core_ir_custom_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir custom-sec handle")
  }
}

///|
fn core_ir_custom_sec_option(value : CustomSec?) -> @lib.CustomSec? {
  match value {
    Some(value) => Some(core_ir_custom_sec_get(value))
    None => None
  }
}

///|
fn core_ir_custom_sec_array(values : Array[CustomSec]) -> Array[@lib.CustomSec] {
  values.map(fn(value) { core_ir_custom_sec_get(value) })
}

///|
pub fn CustomSec::dtor(self : CustomSec) -> Unit {
  let CustomSec(rep) = self
  if rep >= 0 && rep < core_ir_custom_sec_values.length() {
    core_ir_custom_sec_values[rep] = None
    core_ir_custom_sec_free_reps.push(rep)
  }
}

///|
let core_ir_data_values : Array[@lib.Data?] = []

///|
let core_ir_data_free_reps : Array[Int] = []

///|
fn core_ir_data_store(value : @lib.Data) -> Data {
  let rep = match core_ir_data_free_reps.pop() {
    Some(rep) => {
      core_ir_data_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_data_values.length()
      core_ir_data_values.push(Some(value))
      rep
    }
  }
  Data::new(rep)
}

///|
fn core_ir_data_get(value : Data) -> @lib.Data {
  let Data(rep) = value
  if rep < 0 || rep >= core_ir_data_values.length() {
    abort("invalid core-ir data handle")
  }
  match core_ir_data_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir data handle")
  }
}

///|
fn core_ir_data_option(value : Data?) -> @lib.Data? {
  match value {
    Some(value) => Some(core_ir_data_get(value))
    None => None
  }
}

///|
fn core_ir_data_array(values : Array[Data]) -> Array[@lib.Data] {
  values.map(fn(value) { core_ir_data_get(value) })
}

///|
pub fn Data::dtor(self : Data) -> Unit {
  let Data(rep) = self
  if rep >= 0 && rep < core_ir_data_values.length() {
    core_ir_data_values[rep] = None
    core_ir_data_free_reps.push(rep)
  }
}

///|
let core_ir_data_cnt_sec_values : Array[@lib.DataCntSec?] = []

///|
let core_ir_data_cnt_sec_free_reps : Array[Int] = []

///|
fn core_ir_data_cnt_sec_store(value : @lib.DataCntSec) -> DataCntSec {
  let rep = match core_ir_data_cnt_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_data_cnt_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_data_cnt_sec_values.length()
      core_ir_data_cnt_sec_values.push(Some(value))
      rep
    }
  }
  DataCntSec::new(rep)
}

///|
fn core_ir_data_cnt_sec_get(value : DataCntSec) -> @lib.DataCntSec {
  let DataCntSec(rep) = value
  if rep < 0 || rep >= core_ir_data_cnt_sec_values.length() {
    abort("invalid core-ir data-cnt-sec handle")
  }
  match core_ir_data_cnt_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir data-cnt-sec handle")
  }
}

///|
fn core_ir_data_cnt_sec_option(value : DataCntSec?) -> @lib.DataCntSec? {
  match value {
    Some(value) => Some(core_ir_data_cnt_sec_get(value))
    None => None
  }
}

///|
fn core_ir_data_cnt_sec_array(values : Array[DataCntSec]) -> Array[@lib.DataCntSec] {
  values.map(fn(value) { core_ir_data_cnt_sec_get(value) })
}

///|
pub fn DataCntSec::dtor(self : DataCntSec) -> Unit {
  let DataCntSec(rep) = self
  if rep >= 0 && rep < core_ir_data_cnt_sec_values.length() {
    core_ir_data_cnt_sec_values[rep] = None
    core_ir_data_cnt_sec_free_reps.push(rep)
  }
}

///|
let core_ir_data_idx_values : Array[@lib.DataIdx?] = []

///|
let core_ir_data_idx_free_reps : Array[Int] = []

///|
fn core_ir_data_idx_store(value : @lib.DataIdx) -> DataIdx {
  let rep = match core_ir_data_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_data_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_data_idx_values.length()
      core_ir_data_idx_values.push(Some(value))
      rep
    }
  }
  DataIdx::new(rep)
}

///|
fn core_ir_data_idx_get(value : DataIdx) -> @lib.DataIdx {
  let DataIdx(rep) = value
  if rep < 0 || rep >= core_ir_data_idx_values.length() {
    abort("invalid core-ir data-idx handle")
  }
  match core_ir_data_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir data-idx handle")
  }
}

///|
fn core_ir_data_idx_option(value : DataIdx?) -> @lib.DataIdx? {
  match value {
    Some(value) => Some(core_ir_data_idx_get(value))
    None => None
  }
}

///|
fn core_ir_data_idx_array(values : Array[DataIdx]) -> Array[@lib.DataIdx] {
  values.map(fn(value) { core_ir_data_idx_get(value) })
}

///|
pub fn DataIdx::dtor(self : DataIdx) -> Unit {
  let DataIdx(rep) = self
  if rep >= 0 && rep < core_ir_data_idx_values.length() {
    core_ir_data_idx_values[rep] = None
    core_ir_data_idx_free_reps.push(rep)
  }
}

///|
let core_ir_data_mode_values : Array[@lib.DataMode?] = []

///|
let core_ir_data_mode_free_reps : Array[Int] = []

///|
fn core_ir_data_mode_store(value : @lib.DataMode) -> DataMode {
  let rep = match core_ir_data_mode_free_reps.pop() {
    Some(rep) => {
      core_ir_data_mode_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_data_mode_values.length()
      core_ir_data_mode_values.push(Some(value))
      rep
    }
  }
  DataMode::new(rep)
}

///|
fn core_ir_data_mode_get(value : DataMode) -> @lib.DataMode {
  let DataMode(rep) = value
  if rep < 0 || rep >= core_ir_data_mode_values.length() {
    abort("invalid core-ir data-mode handle")
  }
  match core_ir_data_mode_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir data-mode handle")
  }
}

///|
fn core_ir_data_mode_option(value : DataMode?) -> @lib.DataMode? {
  match value {
    Some(value) => Some(core_ir_data_mode_get(value))
    None => None
  }
}

///|
fn core_ir_data_mode_array(values : Array[DataMode]) -> Array[@lib.DataMode] {
  values.map(fn(value) { core_ir_data_mode_get(value) })
}

///|
pub fn DataMode::dtor(self : DataMode) -> Unit {
  let DataMode(rep) = self
  if rep >= 0 && rep < core_ir_data_mode_values.length() {
    core_ir_data_mode_values[rep] = None
    core_ir_data_mode_free_reps.push(rep)
  }
}

///|
let core_ir_data_sec_values : Array[@lib.DataSec?] = []

///|
let core_ir_data_sec_free_reps : Array[Int] = []

///|
fn core_ir_data_sec_store(value : @lib.DataSec) -> DataSec {
  let rep = match core_ir_data_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_data_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_data_sec_values.length()
      core_ir_data_sec_values.push(Some(value))
      rep
    }
  }
  DataSec::new(rep)
}

///|
fn core_ir_data_sec_get(value : DataSec) -> @lib.DataSec {
  let DataSec(rep) = value
  if rep < 0 || rep >= core_ir_data_sec_values.length() {
    abort("invalid core-ir data-sec handle")
  }
  match core_ir_data_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir data-sec handle")
  }
}

///|
fn core_ir_data_sec_option(value : DataSec?) -> @lib.DataSec? {
  match value {
    Some(value) => Some(core_ir_data_sec_get(value))
    None => None
  }
}

///|
fn core_ir_data_sec_array(values : Array[DataSec]) -> Array[@lib.DataSec] {
  values.map(fn(value) { core_ir_data_sec_get(value) })
}

///|
pub fn DataSec::dtor(self : DataSec) -> Unit {
  let DataSec(rep) = self
  if rep >= 0 && rep < core_ir_data_sec_values.length() {
    core_ir_data_sec_values[rep] = None
    core_ir_data_sec_free_reps.push(rep)
  }
}

///|
let core_ir_def_type_values : Array[@lib.DefType?] = []

///|
let core_ir_def_type_free_reps : Array[Int] = []

///|
fn core_ir_def_type_store(value : @lib.DefType) -> DefType {
  let rep = match core_ir_def_type_free_reps.pop() {
    Some(rep) => {
      core_ir_def_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_def_type_values.length()
      core_ir_def_type_values.push(Some(value))
      rep
    }
  }
  DefType::new(rep)
}

///|
fn core_ir_def_type_get(value : DefType) -> @lib.DefType {
  let DefType(rep) = value
  if rep < 0 || rep >= core_ir_def_type_values.length() {
    abort("invalid core-ir def-type handle")
  }
  match core_ir_def_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir def-type handle")
  }
}

///|
fn core_ir_def_type_option(value : DefType?) -> @lib.DefType? {
  match value {
    Some(value) => Some(core_ir_def_type_get(value))
    None => None
  }
}

///|
fn core_ir_def_type_array(values : Array[DefType]) -> Array[@lib.DefType] {
  values.map(fn(value) { core_ir_def_type_get(value) })
}

///|
pub fn DefType::dtor(self : DefType) -> Unit {
  let DefType(rep) = self
  if rep >= 0 && rep < core_ir_def_type_values.length() {
    core_ir_def_type_values[rep] = None
    core_ir_def_type_free_reps.push(rep)
  }
}

///|
let core_ir_elem_values : Array[@lib.Elem?] = []

///|
let core_ir_elem_free_reps : Array[Int] = []

///|
fn core_ir_elem_store(value : @lib.Elem) -> Elem {
  let rep = match core_ir_elem_free_reps.pop() {
    Some(rep) => {
      core_ir_elem_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_elem_values.length()
      core_ir_elem_values.push(Some(value))
      rep
    }
  }
  Elem::new(rep)
}

///|
fn core_ir_elem_get(value : Elem) -> @lib.Elem {
  let Elem(rep) = value
  if rep < 0 || rep >= core_ir_elem_values.length() {
    abort("invalid core-ir elem handle")
  }
  match core_ir_elem_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir elem handle")
  }
}

///|
fn core_ir_elem_option(value : Elem?) -> @lib.Elem? {
  match value {
    Some(value) => Some(core_ir_elem_get(value))
    None => None
  }
}

///|
fn core_ir_elem_array(values : Array[Elem]) -> Array[@lib.Elem] {
  values.map(fn(value) { core_ir_elem_get(value) })
}

///|
pub fn Elem::dtor(self : Elem) -> Unit {
  let Elem(rep) = self
  if rep >= 0 && rep < core_ir_elem_values.length() {
    core_ir_elem_values[rep] = None
    core_ir_elem_free_reps.push(rep)
  }
}

///|
let core_ir_elem_idx_values : Array[@lib.ElemIdx?] = []

///|
let core_ir_elem_idx_free_reps : Array[Int] = []

///|
fn core_ir_elem_idx_store(value : @lib.ElemIdx) -> ElemIdx {
  let rep = match core_ir_elem_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_elem_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_elem_idx_values.length()
      core_ir_elem_idx_values.push(Some(value))
      rep
    }
  }
  ElemIdx::new(rep)
}

///|
fn core_ir_elem_idx_get(value : ElemIdx) -> @lib.ElemIdx {
  let ElemIdx(rep) = value
  if rep < 0 || rep >= core_ir_elem_idx_values.length() {
    abort("invalid core-ir elem-idx handle")
  }
  match core_ir_elem_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir elem-idx handle")
  }
}

///|
fn core_ir_elem_idx_option(value : ElemIdx?) -> @lib.ElemIdx? {
  match value {
    Some(value) => Some(core_ir_elem_idx_get(value))
    None => None
  }
}

///|
fn core_ir_elem_idx_array(values : Array[ElemIdx]) -> Array[@lib.ElemIdx] {
  values.map(fn(value) { core_ir_elem_idx_get(value) })
}

///|
pub fn ElemIdx::dtor(self : ElemIdx) -> Unit {
  let ElemIdx(rep) = self
  if rep >= 0 && rep < core_ir_elem_idx_values.length() {
    core_ir_elem_idx_values[rep] = None
    core_ir_elem_idx_free_reps.push(rep)
  }
}

///|
let core_ir_elem_kind_values : Array[@lib.ElemKind?] = []

///|
let core_ir_elem_kind_free_reps : Array[Int] = []

///|
fn core_ir_elem_kind_store(value : @lib.ElemKind) -> ElemKind {
  let rep = match core_ir_elem_kind_free_reps.pop() {
    Some(rep) => {
      core_ir_elem_kind_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_elem_kind_values.length()
      core_ir_elem_kind_values.push(Some(value))
      rep
    }
  }
  ElemKind::new(rep)
}

///|
fn core_ir_elem_kind_get(value : ElemKind) -> @lib.ElemKind {
  let ElemKind(rep) = value
  if rep < 0 || rep >= core_ir_elem_kind_values.length() {
    abort("invalid core-ir elem-kind handle")
  }
  match core_ir_elem_kind_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir elem-kind handle")
  }
}

///|
fn core_ir_elem_kind_option(value : ElemKind?) -> @lib.ElemKind? {
  match value {
    Some(value) => Some(core_ir_elem_kind_get(value))
    None => None
  }
}

///|
fn core_ir_elem_kind_array(values : Array[ElemKind]) -> Array[@lib.ElemKind] {
  values.map(fn(value) { core_ir_elem_kind_get(value) })
}

///|
pub fn ElemKind::dtor(self : ElemKind) -> Unit {
  let ElemKind(rep) = self
  if rep >= 0 && rep < core_ir_elem_kind_values.length() {
    core_ir_elem_kind_values[rep] = None
    core_ir_elem_kind_free_reps.push(rep)
  }
}

///|
let core_ir_elem_mode_values : Array[@lib.ElemMode?] = []

///|
let core_ir_elem_mode_free_reps : Array[Int] = []

///|
fn core_ir_elem_mode_store(value : @lib.ElemMode) -> ElemMode {
  let rep = match core_ir_elem_mode_free_reps.pop() {
    Some(rep) => {
      core_ir_elem_mode_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_elem_mode_values.length()
      core_ir_elem_mode_values.push(Some(value))
      rep
    }
  }
  ElemMode::new(rep)
}

///|
fn core_ir_elem_mode_get(value : ElemMode) -> @lib.ElemMode {
  let ElemMode(rep) = value
  if rep < 0 || rep >= core_ir_elem_mode_values.length() {
    abort("invalid core-ir elem-mode handle")
  }
  match core_ir_elem_mode_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir elem-mode handle")
  }
}

///|
fn core_ir_elem_mode_option(value : ElemMode?) -> @lib.ElemMode? {
  match value {
    Some(value) => Some(core_ir_elem_mode_get(value))
    None => None
  }
}

///|
fn core_ir_elem_mode_array(values : Array[ElemMode]) -> Array[@lib.ElemMode] {
  values.map(fn(value) { core_ir_elem_mode_get(value) })
}

///|
pub fn ElemMode::dtor(self : ElemMode) -> Unit {
  let ElemMode(rep) = self
  if rep >= 0 && rep < core_ir_elem_mode_values.length() {
    core_ir_elem_mode_values[rep] = None
    core_ir_elem_mode_free_reps.push(rep)
  }
}

///|
let core_ir_elem_sec_values : Array[@lib.ElemSec?] = []

///|
let core_ir_elem_sec_free_reps : Array[Int] = []

///|
fn core_ir_elem_sec_store(value : @lib.ElemSec) -> ElemSec {
  let rep = match core_ir_elem_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_elem_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_elem_sec_values.length()
      core_ir_elem_sec_values.push(Some(value))
      rep
    }
  }
  ElemSec::new(rep)
}

///|
fn core_ir_elem_sec_get(value : ElemSec) -> @lib.ElemSec {
  let ElemSec(rep) = value
  if rep < 0 || rep >= core_ir_elem_sec_values.length() {
    abort("invalid core-ir elem-sec handle")
  }
  match core_ir_elem_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir elem-sec handle")
  }
}

///|
fn core_ir_elem_sec_option(value : ElemSec?) -> @lib.ElemSec? {
  match value {
    Some(value) => Some(core_ir_elem_sec_get(value))
    None => None
  }
}

///|
fn core_ir_elem_sec_array(values : Array[ElemSec]) -> Array[@lib.ElemSec] {
  values.map(fn(value) { core_ir_elem_sec_get(value) })
}

///|
pub fn ElemSec::dtor(self : ElemSec) -> Unit {
  let ElemSec(rep) = self
  if rep >= 0 && rep < core_ir_elem_sec_values.length() {
    core_ir_elem_sec_values[rep] = None
    core_ir_elem_sec_free_reps.push(rep)
  }
}

///|
let core_ir_export_values : Array[@lib.Export?] = []

///|
let core_ir_export_free_reps : Array[Int] = []

///|
fn core_ir_export_store(value : @lib.Export) -> ExportIr {
  let rep = match core_ir_export_free_reps.pop() {
    Some(rep) => {
      core_ir_export_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_export_values.length()
      core_ir_export_values.push(Some(value))
      rep
    }
  }
  ExportIr::new(rep)
}

///|
fn core_ir_export_get(value : ExportIr) -> @lib.Export {
  let ExportIr(rep) = value
  if rep < 0 || rep >= core_ir_export_values.length() {
    abort("invalid core-ir export-ir handle")
  }
  match core_ir_export_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir export-ir handle")
  }
}

///|
fn core_ir_export_option(value : ExportIr?) -> @lib.Export? {
  match value {
    Some(value) => Some(core_ir_export_get(value))
    None => None
  }
}

///|
fn core_ir_export_array(values : Array[ExportIr]) -> Array[@lib.Export] {
  values.map(fn(value) { core_ir_export_get(value) })
}

///|
pub fn ExportIr::dtor(self : ExportIr) -> Unit {
  let ExportIr(rep) = self
  if rep >= 0 && rep < core_ir_export_values.length() {
    core_ir_export_values[rep] = None
    core_ir_export_free_reps.push(rep)
  }
}

///|
let core_ir_export_sec_values : Array[@lib.ExportSec?] = []

///|
let core_ir_export_sec_free_reps : Array[Int] = []

///|
fn core_ir_export_sec_store(value : @lib.ExportSec) -> ExportSec {
  let rep = match core_ir_export_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_export_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_export_sec_values.length()
      core_ir_export_sec_values.push(Some(value))
      rep
    }
  }
  ExportSec::new(rep)
}

///|
fn core_ir_export_sec_get(value : ExportSec) -> @lib.ExportSec {
  let ExportSec(rep) = value
  if rep < 0 || rep >= core_ir_export_sec_values.length() {
    abort("invalid core-ir export-sec handle")
  }
  match core_ir_export_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir export-sec handle")
  }
}

///|
fn core_ir_export_sec_option(value : ExportSec?) -> @lib.ExportSec? {
  match value {
    Some(value) => Some(core_ir_export_sec_get(value))
    None => None
  }
}

///|
fn core_ir_export_sec_array(values : Array[ExportSec]) -> Array[@lib.ExportSec] {
  values.map(fn(value) { core_ir_export_sec_get(value) })
}

///|
pub fn ExportSec::dtor(self : ExportSec) -> Unit {
  let ExportSec(rep) = self
  if rep >= 0 && rep < core_ir_export_sec_values.length() {
    core_ir_export_sec_values[rep] = None
    core_ir_export_sec_free_reps.push(rep)
  }
}

///|
let core_ir_expr_values : Array[@lib.Expr?] = []

///|
let core_ir_expr_free_reps : Array[Int] = []

///|
fn core_ir_expr_store(value : @lib.Expr) -> Expr {
  let rep = match core_ir_expr_free_reps.pop() {
    Some(rep) => {
      core_ir_expr_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_expr_values.length()
      core_ir_expr_values.push(Some(value))
      rep
    }
  }
  Expr::new(rep)
}

///|
fn core_ir_expr_get(value : Expr) -> @lib.Expr {
  let Expr(rep) = value
  if rep < 0 || rep >= core_ir_expr_values.length() {
    abort("invalid core-ir expr handle")
  }
  match core_ir_expr_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir expr handle")
  }
}

///|
fn core_ir_expr_option(value : Expr?) -> @lib.Expr? {
  match value {
    Some(value) => Some(core_ir_expr_get(value))
    None => None
  }
}

///|
fn core_ir_expr_array(values : Array[Expr]) -> Array[@lib.Expr] {
  values.map(fn(value) { core_ir_expr_get(value) })
}

///|
pub fn Expr::dtor(self : Expr) -> Unit {
  let Expr(rep) = self
  if rep >= 0 && rep < core_ir_expr_values.length() {
    core_ir_expr_values[rep] = None
    core_ir_expr_free_reps.push(rep)
  }
}

///|
let core_ir_extern_idx_values : Array[@lib.ExternIdx?] = []

///|
let core_ir_extern_idx_free_reps : Array[Int] = []

///|
fn core_ir_extern_idx_store(value : @lib.ExternIdx) -> ExternIdx {
  let rep = match core_ir_extern_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_extern_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_extern_idx_values.length()
      core_ir_extern_idx_values.push(Some(value))
      rep
    }
  }
  ExternIdx::new(rep)
}

///|
fn core_ir_extern_idx_get(value : ExternIdx) -> @lib.ExternIdx {
  let ExternIdx(rep) = value
  if rep < 0 || rep >= core_ir_extern_idx_values.length() {
    abort("invalid core-ir extern-idx handle")
  }
  match core_ir_extern_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir extern-idx handle")
  }
}

///|
fn core_ir_extern_idx_option(value : ExternIdx?) -> @lib.ExternIdx? {
  match value {
    Some(value) => Some(core_ir_extern_idx_get(value))
    None => None
  }
}

///|
fn core_ir_extern_idx_array(values : Array[ExternIdx]) -> Array[@lib.ExternIdx] {
  values.map(fn(value) { core_ir_extern_idx_get(value) })
}

///|
pub fn ExternIdx::dtor(self : ExternIdx) -> Unit {
  let ExternIdx(rep) = self
  if rep >= 0 && rep < core_ir_extern_idx_values.length() {
    core_ir_extern_idx_values[rep] = None
    core_ir_extern_idx_free_reps.push(rep)
  }
}

///|
let core_ir_extern_type_values : Array[@lib.ExternType?] = []

///|
let core_ir_extern_type_free_reps : Array[Int] = []

///|
fn core_ir_extern_type_store(value : @lib.ExternType) -> ExternType {
  let rep = match core_ir_extern_type_free_reps.pop() {
    Some(rep) => {
      core_ir_extern_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_extern_type_values.length()
      core_ir_extern_type_values.push(Some(value))
      rep
    }
  }
  ExternType::new(rep)
}

///|
fn core_ir_extern_type_get(value : ExternType) -> @lib.ExternType {
  let ExternType(rep) = value
  if rep < 0 || rep >= core_ir_extern_type_values.length() {
    abort("invalid core-ir extern-type handle")
  }
  match core_ir_extern_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir extern-type handle")
  }
}

///|
fn core_ir_extern_type_option(value : ExternType?) -> @lib.ExternType? {
  match value {
    Some(value) => Some(core_ir_extern_type_get(value))
    None => None
  }
}

///|
fn core_ir_extern_type_array(values : Array[ExternType]) -> Array[@lib.ExternType] {
  values.map(fn(value) { core_ir_extern_type_get(value) })
}

///|
pub fn ExternType::dtor(self : ExternType) -> Unit {
  let ExternType(rep) = self
  if rep >= 0 && rep < core_ir_extern_type_values.length() {
    core_ir_extern_type_values[rep] = None
    core_ir_extern_type_free_reps.push(rep)
  }
}

///|
let core_ir_f32_values : Array[@lib.F32?] = []

///|
let core_ir_f32_free_reps : Array[Int] = []

///|
fn core_ir_f32_store(value : @lib.F32) -> F32Ir {
  let rep = match core_ir_f32_free_reps.pop() {
    Some(rep) => {
      core_ir_f32_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_f32_values.length()
      core_ir_f32_values.push(Some(value))
      rep
    }
  }
  F32Ir::new(rep)
}

///|
fn core_ir_f32_get(value : F32Ir) -> @lib.F32 {
  let F32Ir(rep) = value
  if rep < 0 || rep >= core_ir_f32_values.length() {
    abort("invalid core-ir f32-ir handle")
  }
  match core_ir_f32_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir f32-ir handle")
  }
}

///|
fn core_ir_f32_option(value : F32Ir?) -> @lib.F32? {
  match value {
    Some(value) => Some(core_ir_f32_get(value))
    None => None
  }
}

///|
fn core_ir_f32_array(values : Array[F32Ir]) -> Array[@lib.F32] {
  values.map(fn(value) { core_ir_f32_get(value) })
}

///|
pub fn F32Ir::dtor(self : F32Ir) -> Unit {
  let F32Ir(rep) = self
  if rep >= 0 && rep < core_ir_f32_values.length() {
    core_ir_f32_values[rep] = None
    core_ir_f32_free_reps.push(rep)
  }
}

///|
let core_ir_f64_values : Array[@lib.F64?] = []

///|
let core_ir_f64_free_reps : Array[Int] = []

///|
fn core_ir_f64_store(value : @lib.F64) -> F64Ir {
  let rep = match core_ir_f64_free_reps.pop() {
    Some(rep) => {
      core_ir_f64_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_f64_values.length()
      core_ir_f64_values.push(Some(value))
      rep
    }
  }
  F64Ir::new(rep)
}

///|
fn core_ir_f64_get(value : F64Ir) -> @lib.F64 {
  let F64Ir(rep) = value
  if rep < 0 || rep >= core_ir_f64_values.length() {
    abort("invalid core-ir f64-ir handle")
  }
  match core_ir_f64_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir f64-ir handle")
  }
}

///|
fn core_ir_f64_option(value : F64Ir?) -> @lib.F64? {
  match value {
    Some(value) => Some(core_ir_f64_get(value))
    None => None
  }
}

///|
fn core_ir_f64_array(values : Array[F64Ir]) -> Array[@lib.F64] {
  values.map(fn(value) { core_ir_f64_get(value) })
}

///|
pub fn F64Ir::dtor(self : F64Ir) -> Unit {
  let F64Ir(rep) = self
  if rep >= 0 && rep < core_ir_f64_values.length() {
    core_ir_f64_values[rep] = None
    core_ir_f64_free_reps.push(rep)
  }
}

///|
let core_ir_field_type_values : Array[@lib.FieldType?] = []

///|
let core_ir_field_type_free_reps : Array[Int] = []

///|
fn core_ir_field_type_store(value : @lib.FieldType) -> FieldType {
  let rep = match core_ir_field_type_free_reps.pop() {
    Some(rep) => {
      core_ir_field_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_field_type_values.length()
      core_ir_field_type_values.push(Some(value))
      rep
    }
  }
  FieldType::new(rep)
}

///|
fn core_ir_field_type_get(value : FieldType) -> @lib.FieldType {
  let FieldType(rep) = value
  if rep < 0 || rep >= core_ir_field_type_values.length() {
    abort("invalid core-ir field-type handle")
  }
  match core_ir_field_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir field-type handle")
  }
}

///|
fn core_ir_field_type_option(value : FieldType?) -> @lib.FieldType? {
  match value {
    Some(value) => Some(core_ir_field_type_get(value))
    None => None
  }
}

///|
fn core_ir_field_type_array(values : Array[FieldType]) -> Array[@lib.FieldType] {
  values.map(fn(value) { core_ir_field_type_get(value) })
}

///|
pub fn FieldType::dtor(self : FieldType) -> Unit {
  let FieldType(rep) = self
  if rep >= 0 && rep < core_ir_field_type_values.length() {
    core_ir_field_type_values[rep] = None
    core_ir_field_type_free_reps.push(rep)
  }
}

///|
let core_ir_func_values : Array[@lib.Func?] = []

///|
let core_ir_func_free_reps : Array[Int] = []

///|
fn core_ir_func_store(value : @lib.Func) -> FuncIr {
  let rep = match core_ir_func_free_reps.pop() {
    Some(rep) => {
      core_ir_func_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_func_values.length()
      core_ir_func_values.push(Some(value))
      rep
    }
  }
  FuncIr::new(rep)
}

///|
fn core_ir_func_get(value : FuncIr) -> @lib.Func {
  let FuncIr(rep) = value
  if rep < 0 || rep >= core_ir_func_values.length() {
    abort("invalid core-ir func-ir handle")
  }
  match core_ir_func_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir func-ir handle")
  }
}

///|
fn core_ir_func_option(value : FuncIr?) -> @lib.Func? {
  match value {
    Some(value) => Some(core_ir_func_get(value))
    None => None
  }
}

///|
fn core_ir_func_array(values : Array[FuncIr]) -> Array[@lib.Func] {
  values.map(fn(value) { core_ir_func_get(value) })
}

///|
pub fn FuncIr::dtor(self : FuncIr) -> Unit {
  let FuncIr(rep) = self
  if rep >= 0 && rep < core_ir_func_values.length() {
    core_ir_func_values[rep] = None
    core_ir_func_free_reps.push(rep)
  }
}

///|
let core_ir_func_annotation_values : Array[@lib.FuncAnnotation?] = []

///|
let core_ir_func_annotation_free_reps : Array[Int] = []

///|
fn core_ir_func_annotation_store(value : @lib.FuncAnnotation) -> FuncAnnotation {
  let rep = match core_ir_func_annotation_free_reps.pop() {
    Some(rep) => {
      core_ir_func_annotation_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_func_annotation_values.length()
      core_ir_func_annotation_values.push(Some(value))
      rep
    }
  }
  FuncAnnotation::new(rep)
}

///|
fn core_ir_func_annotation_get(value : FuncAnnotation) -> @lib.FuncAnnotation {
  let FuncAnnotation(rep) = value
  if rep < 0 || rep >= core_ir_func_annotation_values.length() {
    abort("invalid core-ir func-annotation handle")
  }
  match core_ir_func_annotation_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir func-annotation handle")
  }
}

///|
fn core_ir_func_annotation_option(value : FuncAnnotation?) -> @lib.FuncAnnotation? {
  match value {
    Some(value) => Some(core_ir_func_annotation_get(value))
    None => None
  }
}

///|
fn core_ir_func_annotation_array(values : Array[FuncAnnotation]) -> Array[@lib.FuncAnnotation] {
  values.map(fn(value) { core_ir_func_annotation_get(value) })
}

///|
pub fn FuncAnnotation::dtor(self : FuncAnnotation) -> Unit {
  let FuncAnnotation(rep) = self
  if rep >= 0 && rep < core_ir_func_annotation_values.length() {
    core_ir_func_annotation_values[rep] = None
    core_ir_func_annotation_free_reps.push(rep)
  }
}

///|
let core_ir_func_annotation_assoc_values : Array[@lib.FuncAnnotationAssoc?] = []

///|
let core_ir_func_annotation_assoc_free_reps : Array[Int] = []

///|
fn core_ir_func_annotation_assoc_store(value : @lib.FuncAnnotationAssoc) -> FuncAnnotationAssoc {
  let rep = match core_ir_func_annotation_assoc_free_reps.pop() {
    Some(rep) => {
      core_ir_func_annotation_assoc_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_func_annotation_assoc_values.length()
      core_ir_func_annotation_assoc_values.push(Some(value))
      rep
    }
  }
  FuncAnnotationAssoc::new(rep)
}

///|
fn core_ir_func_annotation_assoc_get(value : FuncAnnotationAssoc) -> @lib.FuncAnnotationAssoc {
  let FuncAnnotationAssoc(rep) = value
  if rep < 0 || rep >= core_ir_func_annotation_assoc_values.length() {
    abort("invalid core-ir func-annotation-assoc handle")
  }
  match core_ir_func_annotation_assoc_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir func-annotation-assoc handle")
  }
}

///|
fn core_ir_func_annotation_assoc_option(value : FuncAnnotationAssoc?) -> @lib.FuncAnnotationAssoc? {
  match value {
    Some(value) => Some(core_ir_func_annotation_assoc_get(value))
    None => None
  }
}

///|
fn core_ir_func_annotation_assoc_array(values : Array[FuncAnnotationAssoc]) -> Array[@lib.FuncAnnotationAssoc] {
  values.map(fn(value) { core_ir_func_annotation_assoc_get(value) })
}

///|
pub fn FuncAnnotationAssoc::dtor(self : FuncAnnotationAssoc) -> Unit {
  let FuncAnnotationAssoc(rep) = self
  if rep >= 0 && rep < core_ir_func_annotation_assoc_values.length() {
    core_ir_func_annotation_assoc_values[rep] = None
    core_ir_func_annotation_assoc_free_reps.push(rep)
  }
}

///|
let core_ir_func_annotation_sec_values : Array[@lib.FuncAnnotationSec?] = []

///|
let core_ir_func_annotation_sec_free_reps : Array[Int] = []

///|
fn core_ir_func_annotation_sec_store(value : @lib.FuncAnnotationSec) -> FuncAnnotationSec {
  let rep = match core_ir_func_annotation_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_func_annotation_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_func_annotation_sec_values.length()
      core_ir_func_annotation_sec_values.push(Some(value))
      rep
    }
  }
  FuncAnnotationSec::new(rep)
}

///|
fn core_ir_func_annotation_sec_get(value : FuncAnnotationSec) -> @lib.FuncAnnotationSec {
  let FuncAnnotationSec(rep) = value
  if rep < 0 || rep >= core_ir_func_annotation_sec_values.length() {
    abort("invalid core-ir func-annotation-sec handle")
  }
  match core_ir_func_annotation_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir func-annotation-sec handle")
  }
}

///|
fn core_ir_func_annotation_sec_option(value : FuncAnnotationSec?) -> @lib.FuncAnnotationSec? {
  match value {
    Some(value) => Some(core_ir_func_annotation_sec_get(value))
    None => None
  }
}

///|
fn core_ir_func_annotation_sec_array(values : Array[FuncAnnotationSec]) -> Array[@lib.FuncAnnotationSec] {
  values.map(fn(value) { core_ir_func_annotation_sec_get(value) })
}

///|
pub fn FuncAnnotationSec::dtor(self : FuncAnnotationSec) -> Unit {
  let FuncAnnotationSec(rep) = self
  if rep >= 0 && rep < core_ir_func_annotation_sec_values.length() {
    core_ir_func_annotation_sec_values[rep] = None
    core_ir_func_annotation_sec_free_reps.push(rep)
  }
}

///|
let core_ir_func_idx_values : Array[@lib.FuncIdx?] = []

///|
let core_ir_func_idx_free_reps : Array[Int] = []

///|
fn core_ir_func_idx_store(value : @lib.FuncIdx) -> FuncIdx {
  let rep = match core_ir_func_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_func_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_func_idx_values.length()
      core_ir_func_idx_values.push(Some(value))
      rep
    }
  }
  FuncIdx::new(rep)
}

///|
fn core_ir_func_idx_get(value : FuncIdx) -> @lib.FuncIdx {
  let FuncIdx(rep) = value
  if rep < 0 || rep >= core_ir_func_idx_values.length() {
    abort("invalid core-ir func-idx handle")
  }
  match core_ir_func_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir func-idx handle")
  }
}

///|
fn core_ir_func_idx_option(value : FuncIdx?) -> @lib.FuncIdx? {
  match value {
    Some(value) => Some(core_ir_func_idx_get(value))
    None => None
  }
}

///|
fn core_ir_func_idx_array(values : Array[FuncIdx]) -> Array[@lib.FuncIdx] {
  values.map(fn(value) { core_ir_func_idx_get(value) })
}

///|
pub fn FuncIdx::dtor(self : FuncIdx) -> Unit {
  let FuncIdx(rep) = self
  if rep >= 0 && rep < core_ir_func_idx_values.length() {
    core_ir_func_idx_values[rep] = None
    core_ir_func_idx_free_reps.push(rep)
  }
}

///|
let core_ir_func_sec_values : Array[@lib.FuncSec?] = []

///|
let core_ir_func_sec_free_reps : Array[Int] = []

///|
fn core_ir_func_sec_store(value : @lib.FuncSec) -> FuncSec {
  let rep = match core_ir_func_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_func_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_func_sec_values.length()
      core_ir_func_sec_values.push(Some(value))
      rep
    }
  }
  FuncSec::new(rep)
}

///|
fn core_ir_func_sec_get(value : FuncSec) -> @lib.FuncSec {
  let FuncSec(rep) = value
  if rep < 0 || rep >= core_ir_func_sec_values.length() {
    abort("invalid core-ir func-sec handle")
  }
  match core_ir_func_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir func-sec handle")
  }
}

///|
fn core_ir_func_sec_option(value : FuncSec?) -> @lib.FuncSec? {
  match value {
    Some(value) => Some(core_ir_func_sec_get(value))
    None => None
  }
}

///|
fn core_ir_func_sec_array(values : Array[FuncSec]) -> Array[@lib.FuncSec] {
  values.map(fn(value) { core_ir_func_sec_get(value) })
}

///|
pub fn FuncSec::dtor(self : FuncSec) -> Unit {
  let FuncSec(rep) = self
  if rep >= 0 && rep < core_ir_func_sec_values.length() {
    core_ir_func_sec_values[rep] = None
    core_ir_func_sec_free_reps.push(rep)
  }
}

///|
let core_ir_global_values : Array[@lib.Global?] = []

///|
let core_ir_global_free_reps : Array[Int] = []

///|
fn core_ir_global_store(value : @lib.Global) -> Global {
  let rep = match core_ir_global_free_reps.pop() {
    Some(rep) => {
      core_ir_global_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_global_values.length()
      core_ir_global_values.push(Some(value))
      rep
    }
  }
  Global::new(rep)
}

///|
fn core_ir_global_get(value : Global) -> @lib.Global {
  let Global(rep) = value
  if rep < 0 || rep >= core_ir_global_values.length() {
    abort("invalid core-ir global handle")
  }
  match core_ir_global_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir global handle")
  }
}

///|
fn core_ir_global_option(value : Global?) -> @lib.Global? {
  match value {
    Some(value) => Some(core_ir_global_get(value))
    None => None
  }
}

///|
fn core_ir_global_array(values : Array[Global]) -> Array[@lib.Global] {
  values.map(fn(value) { core_ir_global_get(value) })
}

///|
pub fn Global::dtor(self : Global) -> Unit {
  let Global(rep) = self
  if rep >= 0 && rep < core_ir_global_values.length() {
    core_ir_global_values[rep] = None
    core_ir_global_free_reps.push(rep)
  }
}

///|
let core_ir_global_idx_values : Array[@lib.GlobalIdx?] = []

///|
let core_ir_global_idx_free_reps : Array[Int] = []

///|
fn core_ir_global_idx_store(value : @lib.GlobalIdx) -> GlobalIdx {
  let rep = match core_ir_global_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_global_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_global_idx_values.length()
      core_ir_global_idx_values.push(Some(value))
      rep
    }
  }
  GlobalIdx::new(rep)
}

///|
fn core_ir_global_idx_get(value : GlobalIdx) -> @lib.GlobalIdx {
  let GlobalIdx(rep) = value
  if rep < 0 || rep >= core_ir_global_idx_values.length() {
    abort("invalid core-ir global-idx handle")
  }
  match core_ir_global_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir global-idx handle")
  }
}

///|
fn core_ir_global_idx_option(value : GlobalIdx?) -> @lib.GlobalIdx? {
  match value {
    Some(value) => Some(core_ir_global_idx_get(value))
    None => None
  }
}

///|
fn core_ir_global_idx_array(values : Array[GlobalIdx]) -> Array[@lib.GlobalIdx] {
  values.map(fn(value) { core_ir_global_idx_get(value) })
}

///|
pub fn GlobalIdx::dtor(self : GlobalIdx) -> Unit {
  let GlobalIdx(rep) = self
  if rep >= 0 && rep < core_ir_global_idx_values.length() {
    core_ir_global_idx_values[rep] = None
    core_ir_global_idx_free_reps.push(rep)
  }
}

///|
let core_ir_global_sec_values : Array[@lib.GlobalSec?] = []

///|
let core_ir_global_sec_free_reps : Array[Int] = []

///|
fn core_ir_global_sec_store(value : @lib.GlobalSec) -> GlobalSec {
  let rep = match core_ir_global_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_global_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_global_sec_values.length()
      core_ir_global_sec_values.push(Some(value))
      rep
    }
  }
  GlobalSec::new(rep)
}

///|
fn core_ir_global_sec_get(value : GlobalSec) -> @lib.GlobalSec {
  let GlobalSec(rep) = value
  if rep < 0 || rep >= core_ir_global_sec_values.length() {
    abort("invalid core-ir global-sec handle")
  }
  match core_ir_global_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir global-sec handle")
  }
}

///|
fn core_ir_global_sec_option(value : GlobalSec?) -> @lib.GlobalSec? {
  match value {
    Some(value) => Some(core_ir_global_sec_get(value))
    None => None
  }
}

///|
fn core_ir_global_sec_array(values : Array[GlobalSec]) -> Array[@lib.GlobalSec] {
  values.map(fn(value) { core_ir_global_sec_get(value) })
}

///|
pub fn GlobalSec::dtor(self : GlobalSec) -> Unit {
  let GlobalSec(rep) = self
  if rep >= 0 && rep < core_ir_global_sec_values.length() {
    core_ir_global_sec_values[rep] = None
    core_ir_global_sec_free_reps.push(rep)
  }
}

///|
let core_ir_global_type_values : Array[@lib.GlobalType?] = []

///|
let core_ir_global_type_free_reps : Array[Int] = []

///|
fn core_ir_global_type_store(value : @lib.GlobalType) -> GlobalType {
  let rep = match core_ir_global_type_free_reps.pop() {
    Some(rep) => {
      core_ir_global_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_global_type_values.length()
      core_ir_global_type_values.push(Some(value))
      rep
    }
  }
  GlobalType::new(rep)
}

///|
fn core_ir_global_type_get(value : GlobalType) -> @lib.GlobalType {
  let GlobalType(rep) = value
  if rep < 0 || rep >= core_ir_global_type_values.length() {
    abort("invalid core-ir global-type handle")
  }
  match core_ir_global_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir global-type handle")
  }
}

///|
fn core_ir_global_type_option(value : GlobalType?) -> @lib.GlobalType? {
  match value {
    Some(value) => Some(core_ir_global_type_get(value))
    None => None
  }
}

///|
fn core_ir_global_type_array(values : Array[GlobalType]) -> Array[@lib.GlobalType] {
  values.map(fn(value) { core_ir_global_type_get(value) })
}

///|
pub fn GlobalType::dtor(self : GlobalType) -> Unit {
  let GlobalType(rep) = self
  if rep >= 0 && rep < core_ir_global_type_values.length() {
    core_ir_global_type_values[rep] = None
    core_ir_global_type_free_reps.push(rep)
  }
}

///|
let core_ir_heap_type_values : Array[@lib.HeapType?] = []

///|
let core_ir_heap_type_free_reps : Array[Int] = []

///|
fn core_ir_heap_type_store(value : @lib.HeapType) -> HeapType {
  let rep = match core_ir_heap_type_free_reps.pop() {
    Some(rep) => {
      core_ir_heap_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_heap_type_values.length()
      core_ir_heap_type_values.push(Some(value))
      rep
    }
  }
  HeapType::new(rep)
}

///|
fn core_ir_heap_type_get(value : HeapType) -> @lib.HeapType {
  let HeapType(rep) = value
  if rep < 0 || rep >= core_ir_heap_type_values.length() {
    abort("invalid core-ir heap-type handle")
  }
  match core_ir_heap_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir heap-type handle")
  }
}

///|
fn core_ir_heap_type_option(value : HeapType?) -> @lib.HeapType? {
  match value {
    Some(value) => Some(core_ir_heap_type_get(value))
    None => None
  }
}

///|
fn core_ir_heap_type_array(values : Array[HeapType]) -> Array[@lib.HeapType] {
  values.map(fn(value) { core_ir_heap_type_get(value) })
}

///|
pub fn HeapType::dtor(self : HeapType) -> Unit {
  let HeapType(rep) = self
  if rep >= 0 && rep < core_ir_heap_type_values.length() {
    core_ir_heap_type_values[rep] = None
    core_ir_heap_type_free_reps.push(rep)
  }
}

///|
let core_ir_i32_values : Array[@lib.I32?] = []

///|
let core_ir_i32_free_reps : Array[Int] = []

///|
fn core_ir_i32_store(value : @lib.I32) -> I32 {
  let rep = match core_ir_i32_free_reps.pop() {
    Some(rep) => {
      core_ir_i32_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_i32_values.length()
      core_ir_i32_values.push(Some(value))
      rep
    }
  }
  I32::new(rep)
}

///|
fn core_ir_i32_get(value : I32) -> @lib.I32 {
  let I32(rep) = value
  if rep < 0 || rep >= core_ir_i32_values.length() {
    abort("invalid core-ir i32 handle")
  }
  match core_ir_i32_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir i32 handle")
  }
}

///|
fn core_ir_i32_option(value : I32?) -> @lib.I32? {
  match value {
    Some(value) => Some(core_ir_i32_get(value))
    None => None
  }
}

///|
fn core_ir_i32_array(values : Array[I32]) -> Array[@lib.I32] {
  values.map(fn(value) { core_ir_i32_get(value) })
}

///|
pub fn I32::dtor(self : I32) -> Unit {
  let I32(rep) = self
  if rep >= 0 && rep < core_ir_i32_values.length() {
    core_ir_i32_values[rep] = None
    core_ir_i32_free_reps.push(rep)
  }
}

///|
let core_ir_i64_values : Array[@lib.I64?] = []

///|
let core_ir_i64_free_reps : Array[Int] = []

///|
fn core_ir_i64_store(value : @lib.I64) -> I64 {
  let rep = match core_ir_i64_free_reps.pop() {
    Some(rep) => {
      core_ir_i64_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_i64_values.length()
      core_ir_i64_values.push(Some(value))
      rep
    }
  }
  I64::new(rep)
}

///|
fn core_ir_i64_get(value : I64) -> @lib.I64 {
  let I64(rep) = value
  if rep < 0 || rep >= core_ir_i64_values.length() {
    abort("invalid core-ir i64 handle")
  }
  match core_ir_i64_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir i64 handle")
  }
}

///|
fn core_ir_i64_option(value : I64?) -> @lib.I64? {
  match value {
    Some(value) => Some(core_ir_i64_get(value))
    None => None
  }
}

///|
fn core_ir_i64_array(values : Array[I64]) -> Array[@lib.I64] {
  values.map(fn(value) { core_ir_i64_get(value) })
}

///|
pub fn I64::dtor(self : I64) -> Unit {
  let I64(rep) = self
  if rep >= 0 && rep < core_ir_i64_values.length() {
    core_ir_i64_values[rep] = None
    core_ir_i64_free_reps.push(rep)
  }
}

///|
let core_ir_import_values : Array[@lib.Import?] = []

///|
let core_ir_import_free_reps : Array[Int] = []

///|
fn core_ir_import_store(value : @lib.Import) -> ImportIr {
  let rep = match core_ir_import_free_reps.pop() {
    Some(rep) => {
      core_ir_import_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_import_values.length()
      core_ir_import_values.push(Some(value))
      rep
    }
  }
  ImportIr::new(rep)
}

///|
fn core_ir_import_get(value : ImportIr) -> @lib.Import {
  let ImportIr(rep) = value
  if rep < 0 || rep >= core_ir_import_values.length() {
    abort("invalid core-ir import-ir handle")
  }
  match core_ir_import_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir import-ir handle")
  }
}

///|
fn core_ir_import_option(value : ImportIr?) -> @lib.Import? {
  match value {
    Some(value) => Some(core_ir_import_get(value))
    None => None
  }
}

///|
fn core_ir_import_array(values : Array[ImportIr]) -> Array[@lib.Import] {
  values.map(fn(value) { core_ir_import_get(value) })
}

///|
pub fn ImportIr::dtor(self : ImportIr) -> Unit {
  let ImportIr(rep) = self
  if rep >= 0 && rep < core_ir_import_values.length() {
    core_ir_import_values[rep] = None
    core_ir_import_free_reps.push(rep)
  }
}

///|
let core_ir_import_sec_values : Array[@lib.ImportSec?] = []

///|
let core_ir_import_sec_free_reps : Array[Int] = []

///|
fn core_ir_import_sec_store(value : @lib.ImportSec) -> ImportSec {
  let rep = match core_ir_import_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_import_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_import_sec_values.length()
      core_ir_import_sec_values.push(Some(value))
      rep
    }
  }
  ImportSec::new(rep)
}

///|
fn core_ir_import_sec_get(value : ImportSec) -> @lib.ImportSec {
  let ImportSec(rep) = value
  if rep < 0 || rep >= core_ir_import_sec_values.length() {
    abort("invalid core-ir import-sec handle")
  }
  match core_ir_import_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir import-sec handle")
  }
}

///|
fn core_ir_import_sec_option(value : ImportSec?) -> @lib.ImportSec? {
  match value {
    Some(value) => Some(core_ir_import_sec_get(value))
    None => None
  }
}

///|
fn core_ir_import_sec_array(values : Array[ImportSec]) -> Array[@lib.ImportSec] {
  values.map(fn(value) { core_ir_import_sec_get(value) })
}

///|
pub fn ImportSec::dtor(self : ImportSec) -> Unit {
  let ImportSec(rep) = self
  if rep >= 0 && rep < core_ir_import_sec_values.length() {
    core_ir_import_sec_values[rep] = None
    core_ir_import_sec_free_reps.push(rep)
  }
}

///|
let core_ir_indirect_name_assoc_values : Array[@lib.IndirectNameAssoc?] = []

///|
let core_ir_indirect_name_assoc_free_reps : Array[Int] = []

///|
fn core_ir_indirect_name_assoc_store(value : @lib.IndirectNameAssoc) -> IndirectNameAssoc {
  let rep = match core_ir_indirect_name_assoc_free_reps.pop() {
    Some(rep) => {
      core_ir_indirect_name_assoc_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_indirect_name_assoc_values.length()
      core_ir_indirect_name_assoc_values.push(Some(value))
      rep
    }
  }
  IndirectNameAssoc::new(rep)
}

///|
fn core_ir_indirect_name_assoc_get(value : IndirectNameAssoc) -> @lib.IndirectNameAssoc {
  let IndirectNameAssoc(rep) = value
  if rep < 0 || rep >= core_ir_indirect_name_assoc_values.length() {
    abort("invalid core-ir indirect-name-assoc handle")
  }
  match core_ir_indirect_name_assoc_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir indirect-name-assoc handle")
  }
}

///|
fn core_ir_indirect_name_assoc_option(value : IndirectNameAssoc?) -> @lib.IndirectNameAssoc? {
  match value {
    Some(value) => Some(core_ir_indirect_name_assoc_get(value))
    None => None
  }
}

///|
fn core_ir_indirect_name_assoc_array(values : Array[IndirectNameAssoc]) -> Array[@lib.IndirectNameAssoc] {
  values.map(fn(value) { core_ir_indirect_name_assoc_get(value) })
}

///|
pub fn IndirectNameAssoc::dtor(self : IndirectNameAssoc) -> Unit {
  let IndirectNameAssoc(rep) = self
  if rep >= 0 && rep < core_ir_indirect_name_assoc_values.length() {
    core_ir_indirect_name_assoc_values[rep] = None
    core_ir_indirect_name_assoc_free_reps.push(rep)
  }
}

///|
let core_ir_indirect_name_map_values : Array[@lib.IndirectNameMap?] = []

///|
let core_ir_indirect_name_map_free_reps : Array[Int] = []

///|
fn core_ir_indirect_name_map_store(value : @lib.IndirectNameMap) -> IndirectNameMap {
  let rep = match core_ir_indirect_name_map_free_reps.pop() {
    Some(rep) => {
      core_ir_indirect_name_map_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_indirect_name_map_values.length()
      core_ir_indirect_name_map_values.push(Some(value))
      rep
    }
  }
  IndirectNameMap::new(rep)
}

///|
fn core_ir_indirect_name_map_get(value : IndirectNameMap) -> @lib.IndirectNameMap {
  let IndirectNameMap(rep) = value
  if rep < 0 || rep >= core_ir_indirect_name_map_values.length() {
    abort("invalid core-ir indirect-name-map handle")
  }
  match core_ir_indirect_name_map_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir indirect-name-map handle")
  }
}

///|
fn core_ir_indirect_name_map_option(value : IndirectNameMap?) -> @lib.IndirectNameMap? {
  match value {
    Some(value) => Some(core_ir_indirect_name_map_get(value))
    None => None
  }
}

///|
fn core_ir_indirect_name_map_array(values : Array[IndirectNameMap]) -> Array[@lib.IndirectNameMap] {
  values.map(fn(value) { core_ir_indirect_name_map_get(value) })
}

///|
pub fn IndirectNameMap::dtor(self : IndirectNameMap) -> Unit {
  let IndirectNameMap(rep) = self
  if rep >= 0 && rep < core_ir_indirect_name_map_values.length() {
    core_ir_indirect_name_map_values[rep] = None
    core_ir_indirect_name_map_free_reps.push(rep)
  }
}

///|
let core_ir_instruction_values : Array[@lib.Instruction?] = []

///|
let core_ir_instruction_free_reps : Array[Int] = []

///|
fn core_ir_instruction_store(value : @lib.Instruction) -> Instruction {
  let rep = match core_ir_instruction_free_reps.pop() {
    Some(rep) => {
      core_ir_instruction_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_instruction_values.length()
      core_ir_instruction_values.push(Some(value))
      rep
    }
  }
  Instruction::new(rep)
}

///|
fn core_ir_instruction_get(value : Instruction) -> @lib.Instruction {
  let Instruction(rep) = value
  if rep < 0 || rep >= core_ir_instruction_values.length() {
    abort("invalid core-ir instruction handle")
  }
  match core_ir_instruction_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir instruction handle")
  }
}

///|
fn core_ir_instruction_option(value : Instruction?) -> @lib.Instruction? {
  match value {
    Some(value) => Some(core_ir_instruction_get(value))
    None => None
  }
}

///|
fn core_ir_instruction_array(values : Array[Instruction]) -> Array[@lib.Instruction] {
  values.map(fn(value) { core_ir_instruction_get(value) })
}

///|
pub fn Instruction::dtor(self : Instruction) -> Unit {
  let Instruction(rep) = self
  if rep >= 0 && rep < core_ir_instruction_values.length() {
    core_ir_instruction_values[rep] = None
    core_ir_instruction_free_reps.push(rep)
  }
}

///|
let core_ir_label_idx_values : Array[@lib.LabelIdx?] = []

///|
let core_ir_label_idx_free_reps : Array[Int] = []

///|
fn core_ir_label_idx_store(value : @lib.LabelIdx) -> LabelIdx {
  let rep = match core_ir_label_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_label_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_label_idx_values.length()
      core_ir_label_idx_values.push(Some(value))
      rep
    }
  }
  LabelIdx::new(rep)
}

///|
fn core_ir_label_idx_get(value : LabelIdx) -> @lib.LabelIdx {
  let LabelIdx(rep) = value
  if rep < 0 || rep >= core_ir_label_idx_values.length() {
    abort("invalid core-ir label-idx handle")
  }
  match core_ir_label_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir label-idx handle")
  }
}

///|
fn core_ir_label_idx_option(value : LabelIdx?) -> @lib.LabelIdx? {
  match value {
    Some(value) => Some(core_ir_label_idx_get(value))
    None => None
  }
}

///|
fn core_ir_label_idx_array(values : Array[LabelIdx]) -> Array[@lib.LabelIdx] {
  values.map(fn(value) { core_ir_label_idx_get(value) })
}

///|
pub fn LabelIdx::dtor(self : LabelIdx) -> Unit {
  let LabelIdx(rep) = self
  if rep >= 0 && rep < core_ir_label_idx_values.length() {
    core_ir_label_idx_values[rep] = None
    core_ir_label_idx_free_reps.push(rep)
  }
}

///|
let core_ir_lane_idx_values : Array[@lib.LaneIdx?] = []

///|
let core_ir_lane_idx_free_reps : Array[Int] = []

///|
fn core_ir_lane_idx_store(value : @lib.LaneIdx) -> LaneIdx {
  let rep = match core_ir_lane_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_lane_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_lane_idx_values.length()
      core_ir_lane_idx_values.push(Some(value))
      rep
    }
  }
  LaneIdx::new(rep)
}

///|
fn core_ir_lane_idx_get(value : LaneIdx) -> @lib.LaneIdx {
  let LaneIdx(rep) = value
  if rep < 0 || rep >= core_ir_lane_idx_values.length() {
    abort("invalid core-ir lane-idx handle")
  }
  match core_ir_lane_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir lane-idx handle")
  }
}

///|
fn core_ir_lane_idx_option(value : LaneIdx?) -> @lib.LaneIdx? {
  match value {
    Some(value) => Some(core_ir_lane_idx_get(value))
    None => None
  }
}

///|
fn core_ir_lane_idx_array(values : Array[LaneIdx]) -> Array[@lib.LaneIdx] {
  values.map(fn(value) { core_ir_lane_idx_get(value) })
}

///|
pub fn LaneIdx::dtor(self : LaneIdx) -> Unit {
  let LaneIdx(rep) = self
  if rep >= 0 && rep < core_ir_lane_idx_values.length() {
    core_ir_lane_idx_values[rep] = None
    core_ir_lane_idx_free_reps.push(rep)
  }
}

///|
let core_ir_legacy_catch_values : Array[@lib.LegacyCatch?] = []

///|
let core_ir_legacy_catch_free_reps : Array[Int] = []

///|
fn core_ir_legacy_catch_store(value : @lib.LegacyCatch) -> LegacyCatch {
  let rep = match core_ir_legacy_catch_free_reps.pop() {
    Some(rep) => {
      core_ir_legacy_catch_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_legacy_catch_values.length()
      core_ir_legacy_catch_values.push(Some(value))
      rep
    }
  }
  LegacyCatch::new(rep)
}

///|
fn core_ir_legacy_catch_get(value : LegacyCatch) -> @lib.LegacyCatch {
  let LegacyCatch(rep) = value
  if rep < 0 || rep >= core_ir_legacy_catch_values.length() {
    abort("invalid core-ir legacy-catch handle")
  }
  match core_ir_legacy_catch_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir legacy-catch handle")
  }
}

///|
fn core_ir_legacy_catch_option(value : LegacyCatch?) -> @lib.LegacyCatch? {
  match value {
    Some(value) => Some(core_ir_legacy_catch_get(value))
    None => None
  }
}

///|
fn core_ir_legacy_catch_array(values : Array[LegacyCatch]) -> Array[@lib.LegacyCatch] {
  values.map(fn(value) { core_ir_legacy_catch_get(value) })
}

///|
pub fn LegacyCatch::dtor(self : LegacyCatch) -> Unit {
  let LegacyCatch(rep) = self
  if rep >= 0 && rep < core_ir_legacy_catch_values.length() {
    core_ir_legacy_catch_values[rep] = None
    core_ir_legacy_catch_free_reps.push(rep)
  }
}

///|
let core_ir_limits_values : Array[@lib.Limits?] = []

///|
let core_ir_limits_free_reps : Array[Int] = []

///|
fn core_ir_limits_store(value : @lib.Limits) -> Limits {
  let rep = match core_ir_limits_free_reps.pop() {
    Some(rep) => {
      core_ir_limits_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_limits_values.length()
      core_ir_limits_values.push(Some(value))
      rep
    }
  }
  Limits::new(rep)
}

///|
fn core_ir_limits_get(value : Limits) -> @lib.Limits {
  let Limits(rep) = value
  if rep < 0 || rep >= core_ir_limits_values.length() {
    abort("invalid core-ir limits handle")
  }
  match core_ir_limits_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir limits handle")
  }
}

///|
fn core_ir_limits_option(value : Limits?) -> @lib.Limits? {
  match value {
    Some(value) => Some(core_ir_limits_get(value))
    None => None
  }
}

///|
fn core_ir_limits_array(values : Array[Limits]) -> Array[@lib.Limits] {
  values.map(fn(value) { core_ir_limits_get(value) })
}

///|
pub fn Limits::dtor(self : Limits) -> Unit {
  let Limits(rep) = self
  if rep >= 0 && rep < core_ir_limits_values.length() {
    core_ir_limits_values[rep] = None
    core_ir_limits_free_reps.push(rep)
  }
}

///|
let core_ir_load_op_values : Array[@lib.LoadOp?] = []

///|
let core_ir_load_op_free_reps : Array[Int] = []

///|
fn core_ir_load_op_store(value : @lib.LoadOp) -> LoadOp {
  let rep = match core_ir_load_op_free_reps.pop() {
    Some(rep) => {
      core_ir_load_op_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_load_op_values.length()
      core_ir_load_op_values.push(Some(value))
      rep
    }
  }
  LoadOp::new(rep)
}

///|
fn core_ir_load_op_get(value : LoadOp) -> @lib.LoadOp {
  let LoadOp(rep) = value
  if rep < 0 || rep >= core_ir_load_op_values.length() {
    abort("invalid core-ir load-op handle")
  }
  match core_ir_load_op_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir load-op handle")
  }
}

///|
fn core_ir_load_op_option(value : LoadOp?) -> @lib.LoadOp? {
  match value {
    Some(value) => Some(core_ir_load_op_get(value))
    None => None
  }
}

///|
fn core_ir_load_op_array(values : Array[LoadOp]) -> Array[@lib.LoadOp] {
  values.map(fn(value) { core_ir_load_op_get(value) })
}

///|
pub fn LoadOp::dtor(self : LoadOp) -> Unit {
  let LoadOp(rep) = self
  if rep >= 0 && rep < core_ir_load_op_values.length() {
    core_ir_load_op_values[rep] = None
    core_ir_load_op_free_reps.push(rep)
  }
}

///|
let core_ir_local_idx_values : Array[@lib.LocalIdx?] = []

///|
let core_ir_local_idx_free_reps : Array[Int] = []

///|
fn core_ir_local_idx_store(value : @lib.LocalIdx) -> LocalIdx {
  let rep = match core_ir_local_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_local_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_local_idx_values.length()
      core_ir_local_idx_values.push(Some(value))
      rep
    }
  }
  LocalIdx::new(rep)
}

///|
fn core_ir_local_idx_get(value : LocalIdx) -> @lib.LocalIdx {
  let LocalIdx(rep) = value
  if rep < 0 || rep >= core_ir_local_idx_values.length() {
    abort("invalid core-ir local-idx handle")
  }
  match core_ir_local_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir local-idx handle")
  }
}

///|
fn core_ir_local_idx_option(value : LocalIdx?) -> @lib.LocalIdx? {
  match value {
    Some(value) => Some(core_ir_local_idx_get(value))
    None => None
  }
}

///|
fn core_ir_local_idx_array(values : Array[LocalIdx]) -> Array[@lib.LocalIdx] {
  values.map(fn(value) { core_ir_local_idx_get(value) })
}

///|
pub fn LocalIdx::dtor(self : LocalIdx) -> Unit {
  let LocalIdx(rep) = self
  if rep >= 0 && rep < core_ir_local_idx_values.length() {
    core_ir_local_idx_values[rep] = None
    core_ir_local_idx_free_reps.push(rep)
  }
}

///|
let core_ir_local_run_values : Array[@lib.LocalRun?] = []

///|
let core_ir_local_run_free_reps : Array[Int] = []

///|
fn core_ir_local_run_store(value : @lib.LocalRun) -> LocalRun {
  let rep = match core_ir_local_run_free_reps.pop() {
    Some(rep) => {
      core_ir_local_run_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_local_run_values.length()
      core_ir_local_run_values.push(Some(value))
      rep
    }
  }
  LocalRun::new(rep)
}

///|
fn core_ir_local_run_get(value : LocalRun) -> @lib.LocalRun {
  let LocalRun(rep) = value
  if rep < 0 || rep >= core_ir_local_run_values.length() {
    abort("invalid core-ir local-run handle")
  }
  match core_ir_local_run_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir local-run handle")
  }
}

///|
fn core_ir_local_run_option(value : LocalRun?) -> @lib.LocalRun? {
  match value {
    Some(value) => Some(core_ir_local_run_get(value))
    None => None
  }
}

///|
fn core_ir_local_run_array(values : Array[LocalRun]) -> Array[@lib.LocalRun] {
  values.map(fn(value) { core_ir_local_run_get(value) })
}

///|
pub fn LocalRun::dtor(self : LocalRun) -> Unit {
  let LocalRun(rep) = self
  if rep >= 0 && rep < core_ir_local_run_values.length() {
    core_ir_local_run_values[rep] = None
    core_ir_local_run_free_reps.push(rep)
  }
}

///|
let core_ir_locals_values : Array[@lib.Locals?] = []

///|
let core_ir_locals_free_reps : Array[Int] = []

///|
fn core_ir_locals_store(value : @lib.Locals) -> Locals {
  let rep = match core_ir_locals_free_reps.pop() {
    Some(rep) => {
      core_ir_locals_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_locals_values.length()
      core_ir_locals_values.push(Some(value))
      rep
    }
  }
  Locals::new(rep)
}

///|
fn core_ir_locals_get(value : Locals) -> @lib.Locals {
  let Locals(rep) = value
  if rep < 0 || rep >= core_ir_locals_values.length() {
    abort("invalid core-ir locals handle")
  }
  match core_ir_locals_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir locals handle")
  }
}

///|
fn core_ir_locals_option(value : Locals?) -> @lib.Locals? {
  match value {
    Some(value) => Some(core_ir_locals_get(value))
    None => None
  }
}

///|
fn core_ir_locals_array(values : Array[Locals]) -> Array[@lib.Locals] {
  values.map(fn(value) { core_ir_locals_get(value) })
}

///|
pub fn Locals::dtor(self : Locals) -> Unit {
  let Locals(rep) = self
  if rep >= 0 && rep < core_ir_locals_values.length() {
    core_ir_locals_values[rep] = None
    core_ir_locals_free_reps.push(rep)
  }
}

///|
let core_ir_mem_arg_values : Array[@lib.MemArg?] = []

///|
let core_ir_mem_arg_free_reps : Array[Int] = []

///|
fn core_ir_mem_arg_store(value : @lib.MemArg) -> MemArg {
  let rep = match core_ir_mem_arg_free_reps.pop() {
    Some(rep) => {
      core_ir_mem_arg_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_mem_arg_values.length()
      core_ir_mem_arg_values.push(Some(value))
      rep
    }
  }
  MemArg::new(rep)
}

///|
fn core_ir_mem_arg_get(value : MemArg) -> @lib.MemArg {
  let MemArg(rep) = value
  if rep < 0 || rep >= core_ir_mem_arg_values.length() {
    abort("invalid core-ir mem-arg handle")
  }
  match core_ir_mem_arg_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir mem-arg handle")
  }
}

///|
fn core_ir_mem_arg_option(value : MemArg?) -> @lib.MemArg? {
  match value {
    Some(value) => Some(core_ir_mem_arg_get(value))
    None => None
  }
}

///|
fn core_ir_mem_arg_array(values : Array[MemArg]) -> Array[@lib.MemArg] {
  values.map(fn(value) { core_ir_mem_arg_get(value) })
}

///|
pub fn MemArg::dtor(self : MemArg) -> Unit {
  let MemArg(rep) = self
  if rep >= 0 && rep < core_ir_mem_arg_values.length() {
    core_ir_mem_arg_values[rep] = None
    core_ir_mem_arg_free_reps.push(rep)
  }
}

///|
let core_ir_mem_idx_values : Array[@lib.MemIdx?] = []

///|
let core_ir_mem_idx_free_reps : Array[Int] = []

///|
fn core_ir_mem_idx_store(value : @lib.MemIdx) -> MemIdx {
  let rep = match core_ir_mem_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_mem_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_mem_idx_values.length()
      core_ir_mem_idx_values.push(Some(value))
      rep
    }
  }
  MemIdx::new(rep)
}

///|
fn core_ir_mem_idx_get(value : MemIdx) -> @lib.MemIdx {
  let MemIdx(rep) = value
  if rep < 0 || rep >= core_ir_mem_idx_values.length() {
    abort("invalid core-ir mem-idx handle")
  }
  match core_ir_mem_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir mem-idx handle")
  }
}

///|
fn core_ir_mem_idx_option(value : MemIdx?) -> @lib.MemIdx? {
  match value {
    Some(value) => Some(core_ir_mem_idx_get(value))
    None => None
  }
}

///|
fn core_ir_mem_idx_array(values : Array[MemIdx]) -> Array[@lib.MemIdx] {
  values.map(fn(value) { core_ir_mem_idx_get(value) })
}

///|
pub fn MemIdx::dtor(self : MemIdx) -> Unit {
  let MemIdx(rep) = self
  if rep >= 0 && rep < core_ir_mem_idx_values.length() {
    core_ir_mem_idx_values[rep] = None
    core_ir_mem_idx_free_reps.push(rep)
  }
}

///|
let core_ir_mem_sec_values : Array[@lib.MemSec?] = []

///|
let core_ir_mem_sec_free_reps : Array[Int] = []

///|
fn core_ir_mem_sec_store(value : @lib.MemSec) -> MemSec {
  let rep = match core_ir_mem_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_mem_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_mem_sec_values.length()
      core_ir_mem_sec_values.push(Some(value))
      rep
    }
  }
  MemSec::new(rep)
}

///|
fn core_ir_mem_sec_get(value : MemSec) -> @lib.MemSec {
  let MemSec(rep) = value
  if rep < 0 || rep >= core_ir_mem_sec_values.length() {
    abort("invalid core-ir mem-sec handle")
  }
  match core_ir_mem_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir mem-sec handle")
  }
}

///|
fn core_ir_mem_sec_option(value : MemSec?) -> @lib.MemSec? {
  match value {
    Some(value) => Some(core_ir_mem_sec_get(value))
    None => None
  }
}

///|
fn core_ir_mem_sec_array(values : Array[MemSec]) -> Array[@lib.MemSec] {
  values.map(fn(value) { core_ir_mem_sec_get(value) })
}

///|
pub fn MemSec::dtor(self : MemSec) -> Unit {
  let MemSec(rep) = self
  if rep >= 0 && rep < core_ir_mem_sec_values.length() {
    core_ir_mem_sec_values[rep] = None
    core_ir_mem_sec_free_reps.push(rep)
  }
}

///|
let core_ir_mem_type_values : Array[@lib.MemType?] = []

///|
let core_ir_mem_type_free_reps : Array[Int] = []

///|
fn core_ir_mem_type_store(value : @lib.MemType) -> MemType {
  let rep = match core_ir_mem_type_free_reps.pop() {
    Some(rep) => {
      core_ir_mem_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_mem_type_values.length()
      core_ir_mem_type_values.push(Some(value))
      rep
    }
  }
  MemType::new(rep)
}

///|
fn core_ir_mem_type_get(value : MemType) -> @lib.MemType {
  let MemType(rep) = value
  if rep < 0 || rep >= core_ir_mem_type_values.length() {
    abort("invalid core-ir mem-type handle")
  }
  match core_ir_mem_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir mem-type handle")
  }
}

///|
fn core_ir_mem_type_option(value : MemType?) -> @lib.MemType? {
  match value {
    Some(value) => Some(core_ir_mem_type_get(value))
    None => None
  }
}

///|
fn core_ir_mem_type_array(values : Array[MemType]) -> Array[@lib.MemType] {
  values.map(fn(value) { core_ir_mem_type_get(value) })
}

///|
pub fn MemType::dtor(self : MemType) -> Unit {
  let MemType(rep) = self
  if rep >= 0 && rep < core_ir_mem_type_values.length() {
    core_ir_mem_type_values[rep] = None
    core_ir_mem_type_free_reps.push(rep)
  }
}

///|
let core_ir_module_values : Array[@lib.Module?] = []

///|
let core_ir_module_free_reps : Array[Int] = []

///|
fn core_ir_module_store(value : @lib.Module) -> Module {
  let rep = match core_ir_module_free_reps.pop() {
    Some(rep) => {
      core_ir_module_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_module_values.length()
      core_ir_module_values.push(Some(value))
      rep
    }
  }
  Module::new(rep)
}

///|
fn core_ir_module_get(value : Module) -> @lib.Module {
  let Module(rep) = value
  if rep < 0 || rep >= core_ir_module_values.length() {
    abort("invalid core-ir module handle")
  }
  match core_ir_module_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir module handle")
  }
}

///|
fn core_ir_module_option(value : Module?) -> @lib.Module? {
  match value {
    Some(value) => Some(core_ir_module_get(value))
    None => None
  }
}

///|
fn core_ir_module_array(values : Array[Module]) -> Array[@lib.Module] {
  values.map(fn(value) { core_ir_module_get(value) })
}

///|
pub fn Module::dtor(self : Module) -> Unit {
  let Module(rep) = self
  if rep >= 0 && rep < core_ir_module_values.length() {
    core_ir_module_values[rep] = None
    core_ir_module_free_reps.push(rep)
  }
}

///|
let core_ir_mut_values : Array[@lib.Mut?] = []

///|
let core_ir_mut_free_reps : Array[Int] = []

///|
fn core_ir_mut_store(value : @lib.Mut) -> Mut {
  let rep = match core_ir_mut_free_reps.pop() {
    Some(rep) => {
      core_ir_mut_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_mut_values.length()
      core_ir_mut_values.push(Some(value))
      rep
    }
  }
  Mut::new(rep)
}

///|
fn core_ir_mut_get(value : Mut) -> @lib.Mut {
  let Mut(rep) = value
  if rep < 0 || rep >= core_ir_mut_values.length() {
    abort("invalid core-ir mut handle")
  }
  match core_ir_mut_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir mut handle")
  }
}

///|
fn core_ir_mut_option(value : Mut?) -> @lib.Mut? {
  match value {
    Some(value) => Some(core_ir_mut_get(value))
    None => None
  }
}

///|
fn core_ir_mut_array(values : Array[Mut]) -> Array[@lib.Mut] {
  values.map(fn(value) { core_ir_mut_get(value) })
}

///|
pub fn Mut::dtor(self : Mut) -> Unit {
  let Mut(rep) = self
  if rep >= 0 && rep < core_ir_mut_values.length() {
    core_ir_mut_values[rep] = None
    core_ir_mut_free_reps.push(rep)
  }
}

///|
let core_ir_name_values : Array[@lib.Name?] = []

///|
let core_ir_name_free_reps : Array[Int] = []

///|
fn core_ir_name_store(value : @lib.Name) -> Name {
  let rep = match core_ir_name_free_reps.pop() {
    Some(rep) => {
      core_ir_name_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_name_values.length()
      core_ir_name_values.push(Some(value))
      rep
    }
  }
  Name::new(rep)
}

///|
fn core_ir_name_get(value : Name) -> @lib.Name {
  let Name(rep) = value
  if rep < 0 || rep >= core_ir_name_values.length() {
    abort("invalid core-ir name handle")
  }
  match core_ir_name_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir name handle")
  }
}

///|
fn core_ir_name_option(value : Name?) -> @lib.Name? {
  match value {
    Some(value) => Some(core_ir_name_get(value))
    None => None
  }
}

///|
fn core_ir_name_array(values : Array[Name]) -> Array[@lib.Name] {
  values.map(fn(value) { core_ir_name_get(value) })
}

///|
pub fn Name::dtor(self : Name) -> Unit {
  let Name(rep) = self
  if rep >= 0 && rep < core_ir_name_values.length() {
    core_ir_name_values[rep] = None
    core_ir_name_free_reps.push(rep)
  }
}

///|
let core_ir_name_assoc_values : Array[@lib.NameAssoc?] = []

///|
let core_ir_name_assoc_free_reps : Array[Int] = []

///|
fn core_ir_name_assoc_store(value : @lib.NameAssoc) -> NameAssoc {
  let rep = match core_ir_name_assoc_free_reps.pop() {
    Some(rep) => {
      core_ir_name_assoc_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_name_assoc_values.length()
      core_ir_name_assoc_values.push(Some(value))
      rep
    }
  }
  NameAssoc::new(rep)
}

///|
fn core_ir_name_assoc_get(value : NameAssoc) -> @lib.NameAssoc {
  let NameAssoc(rep) = value
  if rep < 0 || rep >= core_ir_name_assoc_values.length() {
    abort("invalid core-ir name-assoc handle")
  }
  match core_ir_name_assoc_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir name-assoc handle")
  }
}

///|
fn core_ir_name_assoc_option(value : NameAssoc?) -> @lib.NameAssoc? {
  match value {
    Some(value) => Some(core_ir_name_assoc_get(value))
    None => None
  }
}

///|
fn core_ir_name_assoc_array(values : Array[NameAssoc]) -> Array[@lib.NameAssoc] {
  values.map(fn(value) { core_ir_name_assoc_get(value) })
}

///|
pub fn NameAssoc::dtor(self : NameAssoc) -> Unit {
  let NameAssoc(rep) = self
  if rep >= 0 && rep < core_ir_name_assoc_values.length() {
    core_ir_name_assoc_values[rep] = None
    core_ir_name_assoc_free_reps.push(rep)
  }
}

///|
let core_ir_name_map_values : Array[@lib.NameMap?] = []

///|
let core_ir_name_map_free_reps : Array[Int] = []

///|
fn core_ir_name_map_store(value : @lib.NameMap) -> NameMap {
  let rep = match core_ir_name_map_free_reps.pop() {
    Some(rep) => {
      core_ir_name_map_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_name_map_values.length()
      core_ir_name_map_values.push(Some(value))
      rep
    }
  }
  NameMap::new(rep)
}

///|
fn core_ir_name_map_get(value : NameMap) -> @lib.NameMap {
  let NameMap(rep) = value
  if rep < 0 || rep >= core_ir_name_map_values.length() {
    abort("invalid core-ir name-map handle")
  }
  match core_ir_name_map_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir name-map handle")
  }
}

///|
fn core_ir_name_map_option(value : NameMap?) -> @lib.NameMap? {
  match value {
    Some(value) => Some(core_ir_name_map_get(value))
    None => None
  }
}

///|
fn core_ir_name_map_array(values : Array[NameMap]) -> Array[@lib.NameMap] {
  values.map(fn(value) { core_ir_name_map_get(value) })
}

///|
pub fn NameMap::dtor(self : NameMap) -> Unit {
  let NameMap(rep) = self
  if rep >= 0 && rep < core_ir_name_map_values.length() {
    core_ir_name_map_values[rep] = None
    core_ir_name_map_free_reps.push(rep)
  }
}

///|
let core_ir_name_sec_values : Array[@lib.NameSec?] = []

///|
let core_ir_name_sec_free_reps : Array[Int] = []

///|
fn core_ir_name_sec_store(value : @lib.NameSec) -> NameSec {
  let rep = match core_ir_name_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_name_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_name_sec_values.length()
      core_ir_name_sec_values.push(Some(value))
      rep
    }
  }
  NameSec::new(rep)
}

///|
fn core_ir_name_sec_get(value : NameSec) -> @lib.NameSec {
  let NameSec(rep) = value
  if rep < 0 || rep >= core_ir_name_sec_values.length() {
    abort("invalid core-ir name-sec handle")
  }
  match core_ir_name_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir name-sec handle")
  }
}

///|
fn core_ir_name_sec_option(value : NameSec?) -> @lib.NameSec? {
  match value {
    Some(value) => Some(core_ir_name_sec_get(value))
    None => None
  }
}

///|
fn core_ir_name_sec_array(values : Array[NameSec]) -> Array[@lib.NameSec] {
  values.map(fn(value) { core_ir_name_sec_get(value) })
}

///|
pub fn NameSec::dtor(self : NameSec) -> Unit {
  let NameSec(rep) = self
  if rep >= 0 && rep < core_ir_name_sec_values.length() {
    core_ir_name_sec_values[rep] = None
    core_ir_name_sec_free_reps.push(rep)
  }
}

///|
let core_ir_num_type_values : Array[@lib.NumType?] = []

///|
let core_ir_num_type_free_reps : Array[Int] = []

///|
fn core_ir_num_type_store(value : @lib.NumType) -> NumType {
  let rep = match core_ir_num_type_free_reps.pop() {
    Some(rep) => {
      core_ir_num_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_num_type_values.length()
      core_ir_num_type_values.push(Some(value))
      rep
    }
  }
  NumType::new(rep)
}

///|
fn core_ir_num_type_get(value : NumType) -> @lib.NumType {
  let NumType(rep) = value
  if rep < 0 || rep >= core_ir_num_type_values.length() {
    abort("invalid core-ir num-type handle")
  }
  match core_ir_num_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir num-type handle")
  }
}

///|
fn core_ir_num_type_option(value : NumType?) -> @lib.NumType? {
  match value {
    Some(value) => Some(core_ir_num_type_get(value))
    None => None
  }
}

///|
fn core_ir_num_type_array(values : Array[NumType]) -> Array[@lib.NumType] {
  values.map(fn(value) { core_ir_num_type_get(value) })
}

///|
pub fn NumType::dtor(self : NumType) -> Unit {
  let NumType(rep) = self
  if rep >= 0 && rep < core_ir_num_type_values.length() {
    core_ir_num_type_values[rep] = None
    core_ir_num_type_free_reps.push(rep)
  }
}

///|
let core_ir_pack_type_values : Array[@lib.PackType?] = []

///|
let core_ir_pack_type_free_reps : Array[Int] = []

///|
fn core_ir_pack_type_store(value : @lib.PackType) -> PackType {
  let rep = match core_ir_pack_type_free_reps.pop() {
    Some(rep) => {
      core_ir_pack_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_pack_type_values.length()
      core_ir_pack_type_values.push(Some(value))
      rep
    }
  }
  PackType::new(rep)
}

///|
fn core_ir_pack_type_get(value : PackType) -> @lib.PackType {
  let PackType(rep) = value
  if rep < 0 || rep >= core_ir_pack_type_values.length() {
    abort("invalid core-ir pack-type handle")
  }
  match core_ir_pack_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir pack-type handle")
  }
}

///|
fn core_ir_pack_type_option(value : PackType?) -> @lib.PackType? {
  match value {
    Some(value) => Some(core_ir_pack_type_get(value))
    None => None
  }
}

///|
fn core_ir_pack_type_array(values : Array[PackType]) -> Array[@lib.PackType] {
  values.map(fn(value) { core_ir_pack_type_get(value) })
}

///|
pub fn PackType::dtor(self : PackType) -> Unit {
  let PackType(rep) = self
  if rep >= 0 && rep < core_ir_pack_type_values.length() {
    core_ir_pack_type_values[rep] = None
    core_ir_pack_type_free_reps.push(rep)
  }
}

///|
let core_ir_rec_type_values : Array[@lib.RecType?] = []

///|
let core_ir_rec_type_free_reps : Array[Int] = []

///|
fn core_ir_rec_type_store(value : @lib.RecType) -> RecType {
  let rep = match core_ir_rec_type_free_reps.pop() {
    Some(rep) => {
      core_ir_rec_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_rec_type_values.length()
      core_ir_rec_type_values.push(Some(value))
      rep
    }
  }
  RecType::new(rep)
}

///|
fn core_ir_rec_type_get(value : RecType) -> @lib.RecType {
  let RecType(rep) = value
  if rep < 0 || rep >= core_ir_rec_type_values.length() {
    abort("invalid core-ir rec-type handle")
  }
  match core_ir_rec_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir rec-type handle")
  }
}

///|
fn core_ir_rec_type_option(value : RecType?) -> @lib.RecType? {
  match value {
    Some(value) => Some(core_ir_rec_type_get(value))
    None => None
  }
}

///|
fn core_ir_rec_type_array(values : Array[RecType]) -> Array[@lib.RecType] {
  values.map(fn(value) { core_ir_rec_type_get(value) })
}

///|
pub fn RecType::dtor(self : RecType) -> Unit {
  let RecType(rep) = self
  if rep >= 0 && rep < core_ir_rec_type_values.length() {
    core_ir_rec_type_values[rep] = None
    core_ir_rec_type_free_reps.push(rep)
  }
}

///|
let core_ir_ref_type_values : Array[@lib.RefType?] = []

///|
let core_ir_ref_type_free_reps : Array[Int] = []

///|
fn core_ir_ref_type_store(value : @lib.RefType) -> RefType {
  let rep = match core_ir_ref_type_free_reps.pop() {
    Some(rep) => {
      core_ir_ref_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_ref_type_values.length()
      core_ir_ref_type_values.push(Some(value))
      rep
    }
  }
  RefType::new(rep)
}

///|
fn core_ir_ref_type_get(value : RefType) -> @lib.RefType {
  let RefType(rep) = value
  if rep < 0 || rep >= core_ir_ref_type_values.length() {
    abort("invalid core-ir ref-type handle")
  }
  match core_ir_ref_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir ref-type handle")
  }
}

///|
fn core_ir_ref_type_option(value : RefType?) -> @lib.RefType? {
  match value {
    Some(value) => Some(core_ir_ref_type_get(value))
    None => None
  }
}

///|
fn core_ir_ref_type_array(values : Array[RefType]) -> Array[@lib.RefType] {
  values.map(fn(value) { core_ir_ref_type_get(value) })
}

///|
pub fn RefType::dtor(self : RefType) -> Unit {
  let RefType(rep) = self
  if rep >= 0 && rep < core_ir_ref_type_values.length() {
    core_ir_ref_type_values[rep] = None
    core_ir_ref_type_free_reps.push(rep)
  }
}

///|
let core_ir_resume_handler_values : Array[@lib.ResumeHandler?] = []

///|
let core_ir_resume_handler_free_reps : Array[Int] = []

///|
fn core_ir_resume_handler_store(value : @lib.ResumeHandler) -> ResumeHandler {
  let rep = match core_ir_resume_handler_free_reps.pop() {
    Some(rep) => {
      core_ir_resume_handler_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_resume_handler_values.length()
      core_ir_resume_handler_values.push(Some(value))
      rep
    }
  }
  ResumeHandler::new(rep)
}

///|
fn core_ir_resume_handler_get(value : ResumeHandler) -> @lib.ResumeHandler {
  let ResumeHandler(rep) = value
  if rep < 0 || rep >= core_ir_resume_handler_values.length() {
    abort("invalid core-ir resume-handler handle")
  }
  match core_ir_resume_handler_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir resume-handler handle")
  }
}

///|
fn core_ir_resume_handler_option(value : ResumeHandler?) -> @lib.ResumeHandler? {
  match value {
    Some(value) => Some(core_ir_resume_handler_get(value))
    None => None
  }
}

///|
fn core_ir_resume_handler_array(values : Array[ResumeHandler]) -> Array[@lib.ResumeHandler] {
  values.map(fn(value) { core_ir_resume_handler_get(value) })
}

///|
pub fn ResumeHandler::dtor(self : ResumeHandler) -> Unit {
  let ResumeHandler(rep) = self
  if rep >= 0 && rep < core_ir_resume_handler_values.length() {
    core_ir_resume_handler_values[rep] = None
    core_ir_resume_handler_free_reps.push(rep)
  }
}

///|
let core_ir_start_sec_values : Array[@lib.StartSec?] = []

///|
let core_ir_start_sec_free_reps : Array[Int] = []

///|
fn core_ir_start_sec_store(value : @lib.StartSec) -> StartSec {
  let rep = match core_ir_start_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_start_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_start_sec_values.length()
      core_ir_start_sec_values.push(Some(value))
      rep
    }
  }
  StartSec::new(rep)
}

///|
fn core_ir_start_sec_get(value : StartSec) -> @lib.StartSec {
  let StartSec(rep) = value
  if rep < 0 || rep >= core_ir_start_sec_values.length() {
    abort("invalid core-ir start-sec handle")
  }
  match core_ir_start_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir start-sec handle")
  }
}

///|
fn core_ir_start_sec_option(value : StartSec?) -> @lib.StartSec? {
  match value {
    Some(value) => Some(core_ir_start_sec_get(value))
    None => None
  }
}

///|
fn core_ir_start_sec_array(values : Array[StartSec]) -> Array[@lib.StartSec] {
  values.map(fn(value) { core_ir_start_sec_get(value) })
}

///|
pub fn StartSec::dtor(self : StartSec) -> Unit {
  let StartSec(rep) = self
  if rep >= 0 && rep < core_ir_start_sec_values.length() {
    core_ir_start_sec_values[rep] = None
    core_ir_start_sec_free_reps.push(rep)
  }
}

///|
let core_ir_storage_type_values : Array[@lib.StorageType?] = []

///|
let core_ir_storage_type_free_reps : Array[Int] = []

///|
fn core_ir_storage_type_store(value : @lib.StorageType) -> StorageType {
  let rep = match core_ir_storage_type_free_reps.pop() {
    Some(rep) => {
      core_ir_storage_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_storage_type_values.length()
      core_ir_storage_type_values.push(Some(value))
      rep
    }
  }
  StorageType::new(rep)
}

///|
fn core_ir_storage_type_get(value : StorageType) -> @lib.StorageType {
  let StorageType(rep) = value
  if rep < 0 || rep >= core_ir_storage_type_values.length() {
    abort("invalid core-ir storage-type handle")
  }
  match core_ir_storage_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir storage-type handle")
  }
}

///|
fn core_ir_storage_type_option(value : StorageType?) -> @lib.StorageType? {
  match value {
    Some(value) => Some(core_ir_storage_type_get(value))
    None => None
  }
}

///|
fn core_ir_storage_type_array(values : Array[StorageType]) -> Array[@lib.StorageType] {
  values.map(fn(value) { core_ir_storage_type_get(value) })
}

///|
pub fn StorageType::dtor(self : StorageType) -> Unit {
  let StorageType(rep) = self
  if rep >= 0 && rep < core_ir_storage_type_values.length() {
    core_ir_storage_type_values[rep] = None
    core_ir_storage_type_free_reps.push(rep)
  }
}

///|
let core_ir_store_op_values : Array[@lib.StoreOp?] = []

///|
let core_ir_store_op_free_reps : Array[Int] = []

///|
fn core_ir_store_op_store(value : @lib.StoreOp) -> StoreOp {
  let rep = match core_ir_store_op_free_reps.pop() {
    Some(rep) => {
      core_ir_store_op_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_store_op_values.length()
      core_ir_store_op_values.push(Some(value))
      rep
    }
  }
  StoreOp::new(rep)
}

///|
fn core_ir_store_op_get(value : StoreOp) -> @lib.StoreOp {
  let StoreOp(rep) = value
  if rep < 0 || rep >= core_ir_store_op_values.length() {
    abort("invalid core-ir store-op handle")
  }
  match core_ir_store_op_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir store-op handle")
  }
}

///|
fn core_ir_store_op_option(value : StoreOp?) -> @lib.StoreOp? {
  match value {
    Some(value) => Some(core_ir_store_op_get(value))
    None => None
  }
}

///|
fn core_ir_store_op_array(values : Array[StoreOp]) -> Array[@lib.StoreOp] {
  values.map(fn(value) { core_ir_store_op_get(value) })
}

///|
pub fn StoreOp::dtor(self : StoreOp) -> Unit {
  let StoreOp(rep) = self
  if rep >= 0 && rep < core_ir_store_op_values.length() {
    core_ir_store_op_values[rep] = None
    core_ir_store_op_free_reps.push(rep)
  }
}

///|
let core_ir_string_refs_sec_values : Array[@lib.StringRefsSec?] = []

///|
let core_ir_string_refs_sec_free_reps : Array[Int] = []

///|
fn core_ir_string_refs_sec_store(value : @lib.StringRefsSec) -> StringRefsSec {
  let rep = match core_ir_string_refs_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_string_refs_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_string_refs_sec_values.length()
      core_ir_string_refs_sec_values.push(Some(value))
      rep
    }
  }
  StringRefsSec::new(rep)
}

///|
fn core_ir_string_refs_sec_get(value : StringRefsSec) -> @lib.StringRefsSec {
  let StringRefsSec(rep) = value
  if rep < 0 || rep >= core_ir_string_refs_sec_values.length() {
    abort("invalid core-ir string-refs-sec handle")
  }
  match core_ir_string_refs_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir string-refs-sec handle")
  }
}

///|
fn core_ir_string_refs_sec_option(value : StringRefsSec?) -> @lib.StringRefsSec? {
  match value {
    Some(value) => Some(core_ir_string_refs_sec_get(value))
    None => None
  }
}

///|
fn core_ir_string_refs_sec_array(values : Array[StringRefsSec]) -> Array[@lib.StringRefsSec] {
  values.map(fn(value) { core_ir_string_refs_sec_get(value) })
}

///|
pub fn StringRefsSec::dtor(self : StringRefsSec) -> Unit {
  let StringRefsSec(rep) = self
  if rep >= 0 && rep < core_ir_string_refs_sec_values.length() {
    core_ir_string_refs_sec_values[rep] = None
    core_ir_string_refs_sec_free_reps.push(rep)
  }
}

///|
let core_ir_sub_type_values : Array[@lib.SubType?] = []

///|
let core_ir_sub_type_free_reps : Array[Int] = []

///|
fn core_ir_sub_type_store(value : @lib.SubType) -> SubType {
  let rep = match core_ir_sub_type_free_reps.pop() {
    Some(rep) => {
      core_ir_sub_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_sub_type_values.length()
      core_ir_sub_type_values.push(Some(value))
      rep
    }
  }
  SubType::new(rep)
}

///|
fn core_ir_sub_type_get(value : SubType) -> @lib.SubType {
  let SubType(rep) = value
  if rep < 0 || rep >= core_ir_sub_type_values.length() {
    abort("invalid core-ir sub-type handle")
  }
  match core_ir_sub_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir sub-type handle")
  }
}

///|
fn core_ir_sub_type_option(value : SubType?) -> @lib.SubType? {
  match value {
    Some(value) => Some(core_ir_sub_type_get(value))
    None => None
  }
}

///|
fn core_ir_sub_type_array(values : Array[SubType]) -> Array[@lib.SubType] {
  values.map(fn(value) { core_ir_sub_type_get(value) })
}

///|
pub fn SubType::dtor(self : SubType) -> Unit {
  let SubType(rep) = self
  if rep >= 0 && rep < core_ir_sub_type_values.length() {
    core_ir_sub_type_values[rep] = None
    core_ir_sub_type_free_reps.push(rep)
  }
}

///|
let core_ir_table_values : Array[@lib.Table?] = []

///|
let core_ir_table_free_reps : Array[Int] = []

///|
fn core_ir_table_store(value : @lib.Table) -> Table {
  let rep = match core_ir_table_free_reps.pop() {
    Some(rep) => {
      core_ir_table_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_table_values.length()
      core_ir_table_values.push(Some(value))
      rep
    }
  }
  Table::new(rep)
}

///|
fn core_ir_table_get(value : Table) -> @lib.Table {
  let Table(rep) = value
  if rep < 0 || rep >= core_ir_table_values.length() {
    abort("invalid core-ir table handle")
  }
  match core_ir_table_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir table handle")
  }
}

///|
fn core_ir_table_option(value : Table?) -> @lib.Table? {
  match value {
    Some(value) => Some(core_ir_table_get(value))
    None => None
  }
}

///|
fn core_ir_table_array(values : Array[Table]) -> Array[@lib.Table] {
  values.map(fn(value) { core_ir_table_get(value) })
}

///|
pub fn Table::dtor(self : Table) -> Unit {
  let Table(rep) = self
  if rep >= 0 && rep < core_ir_table_values.length() {
    core_ir_table_values[rep] = None
    core_ir_table_free_reps.push(rep)
  }
}

///|
let core_ir_table_idx_values : Array[@lib.TableIdx?] = []

///|
let core_ir_table_idx_free_reps : Array[Int] = []

///|
fn core_ir_table_idx_store(value : @lib.TableIdx) -> TableIdx {
  let rep = match core_ir_table_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_table_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_table_idx_values.length()
      core_ir_table_idx_values.push(Some(value))
      rep
    }
  }
  TableIdx::new(rep)
}

///|
fn core_ir_table_idx_get(value : TableIdx) -> @lib.TableIdx {
  let TableIdx(rep) = value
  if rep < 0 || rep >= core_ir_table_idx_values.length() {
    abort("invalid core-ir table-idx handle")
  }
  match core_ir_table_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir table-idx handle")
  }
}

///|
fn core_ir_table_idx_option(value : TableIdx?) -> @lib.TableIdx? {
  match value {
    Some(value) => Some(core_ir_table_idx_get(value))
    None => None
  }
}

///|
fn core_ir_table_idx_array(values : Array[TableIdx]) -> Array[@lib.TableIdx] {
  values.map(fn(value) { core_ir_table_idx_get(value) })
}

///|
pub fn TableIdx::dtor(self : TableIdx) -> Unit {
  let TableIdx(rep) = self
  if rep >= 0 && rep < core_ir_table_idx_values.length() {
    core_ir_table_idx_values[rep] = None
    core_ir_table_idx_free_reps.push(rep)
  }
}

///|
let core_ir_table_sec_values : Array[@lib.TableSec?] = []

///|
let core_ir_table_sec_free_reps : Array[Int] = []

///|
fn core_ir_table_sec_store(value : @lib.TableSec) -> TableSec {
  let rep = match core_ir_table_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_table_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_table_sec_values.length()
      core_ir_table_sec_values.push(Some(value))
      rep
    }
  }
  TableSec::new(rep)
}

///|
fn core_ir_table_sec_get(value : TableSec) -> @lib.TableSec {
  let TableSec(rep) = value
  if rep < 0 || rep >= core_ir_table_sec_values.length() {
    abort("invalid core-ir table-sec handle")
  }
  match core_ir_table_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir table-sec handle")
  }
}

///|
fn core_ir_table_sec_option(value : TableSec?) -> @lib.TableSec? {
  match value {
    Some(value) => Some(core_ir_table_sec_get(value))
    None => None
  }
}

///|
fn core_ir_table_sec_array(values : Array[TableSec]) -> Array[@lib.TableSec] {
  values.map(fn(value) { core_ir_table_sec_get(value) })
}

///|
pub fn TableSec::dtor(self : TableSec) -> Unit {
  let TableSec(rep) = self
  if rep >= 0 && rep < core_ir_table_sec_values.length() {
    core_ir_table_sec_values[rep] = None
    core_ir_table_sec_free_reps.push(rep)
  }
}

///|
let core_ir_table_type_values : Array[@lib.TableType?] = []

///|
let core_ir_table_type_free_reps : Array[Int] = []

///|
fn core_ir_table_type_store(value : @lib.TableType) -> TableType {
  let rep = match core_ir_table_type_free_reps.pop() {
    Some(rep) => {
      core_ir_table_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_table_type_values.length()
      core_ir_table_type_values.push(Some(value))
      rep
    }
  }
  TableType::new(rep)
}

///|
fn core_ir_table_type_get(value : TableType) -> @lib.TableType {
  let TableType(rep) = value
  if rep < 0 || rep >= core_ir_table_type_values.length() {
    abort("invalid core-ir table-type handle")
  }
  match core_ir_table_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir table-type handle")
  }
}

///|
fn core_ir_table_type_option(value : TableType?) -> @lib.TableType? {
  match value {
    Some(value) => Some(core_ir_table_type_get(value))
    None => None
  }
}

///|
fn core_ir_table_type_array(values : Array[TableType]) -> Array[@lib.TableType] {
  values.map(fn(value) { core_ir_table_type_get(value) })
}

///|
pub fn TableType::dtor(self : TableType) -> Unit {
  let TableType(rep) = self
  if rep >= 0 && rep < core_ir_table_type_values.length() {
    core_ir_table_type_values[rep] = None
    core_ir_table_type_free_reps.push(rep)
  }
}

///|
let core_ir_tag_idx_values : Array[@lib.TagIdx?] = []

///|
let core_ir_tag_idx_free_reps : Array[Int] = []

///|
fn core_ir_tag_idx_store(value : @lib.TagIdx) -> TagIdx {
  let rep = match core_ir_tag_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_tag_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_tag_idx_values.length()
      core_ir_tag_idx_values.push(Some(value))
      rep
    }
  }
  TagIdx::new(rep)
}

///|
fn core_ir_tag_idx_get(value : TagIdx) -> @lib.TagIdx {
  let TagIdx(rep) = value
  if rep < 0 || rep >= core_ir_tag_idx_values.length() {
    abort("invalid core-ir tag-idx handle")
  }
  match core_ir_tag_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir tag-idx handle")
  }
}

///|
fn core_ir_tag_idx_option(value : TagIdx?) -> @lib.TagIdx? {
  match value {
    Some(value) => Some(core_ir_tag_idx_get(value))
    None => None
  }
}

///|
fn core_ir_tag_idx_array(values : Array[TagIdx]) -> Array[@lib.TagIdx] {
  values.map(fn(value) { core_ir_tag_idx_get(value) })
}

///|
pub fn TagIdx::dtor(self : TagIdx) -> Unit {
  let TagIdx(rep) = self
  if rep >= 0 && rep < core_ir_tag_idx_values.length() {
    core_ir_tag_idx_values[rep] = None
    core_ir_tag_idx_free_reps.push(rep)
  }
}

///|
let core_ir_tag_sec_values : Array[@lib.TagSec?] = []

///|
let core_ir_tag_sec_free_reps : Array[Int] = []

///|
fn core_ir_tag_sec_store(value : @lib.TagSec) -> TagSec {
  let rep = match core_ir_tag_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_tag_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_tag_sec_values.length()
      core_ir_tag_sec_values.push(Some(value))
      rep
    }
  }
  TagSec::new(rep)
}

///|
fn core_ir_tag_sec_get(value : TagSec) -> @lib.TagSec {
  let TagSec(rep) = value
  if rep < 0 || rep >= core_ir_tag_sec_values.length() {
    abort("invalid core-ir tag-sec handle")
  }
  match core_ir_tag_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir tag-sec handle")
  }
}

///|
fn core_ir_tag_sec_option(value : TagSec?) -> @lib.TagSec? {
  match value {
    Some(value) => Some(core_ir_tag_sec_get(value))
    None => None
  }
}

///|
fn core_ir_tag_sec_array(values : Array[TagSec]) -> Array[@lib.TagSec] {
  values.map(fn(value) { core_ir_tag_sec_get(value) })
}

///|
pub fn TagSec::dtor(self : TagSec) -> Unit {
  let TagSec(rep) = self
  if rep >= 0 && rep < core_ir_tag_sec_values.length() {
    core_ir_tag_sec_values[rep] = None
    core_ir_tag_sec_free_reps.push(rep)
  }
}

///|
let core_ir_tag_type_values : Array[@lib.TagType?] = []

///|
let core_ir_tag_type_free_reps : Array[Int] = []

///|
fn core_ir_tag_type_store(value : @lib.TagType) -> TagType {
  let rep = match core_ir_tag_type_free_reps.pop() {
    Some(rep) => {
      core_ir_tag_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_tag_type_values.length()
      core_ir_tag_type_values.push(Some(value))
      rep
    }
  }
  TagType::new(rep)
}

///|
fn core_ir_tag_type_get(value : TagType) -> @lib.TagType {
  let TagType(rep) = value
  if rep < 0 || rep >= core_ir_tag_type_values.length() {
    abort("invalid core-ir tag-type handle")
  }
  match core_ir_tag_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir tag-type handle")
  }
}

///|
fn core_ir_tag_type_option(value : TagType?) -> @lib.TagType? {
  match value {
    Some(value) => Some(core_ir_tag_type_get(value))
    None => None
  }
}

///|
fn core_ir_tag_type_array(values : Array[TagType]) -> Array[@lib.TagType] {
  values.map(fn(value) { core_ir_tag_type_get(value) })
}

///|
pub fn TagType::dtor(self : TagType) -> Unit {
  let TagType(rep) = self
  if rep >= 0 && rep < core_ir_tag_type_values.length() {
    core_ir_tag_type_values[rep] = None
    core_ir_tag_type_free_reps.push(rep)
  }
}

///|
let core_ir_type_idx_values : Array[@lib.TypeIdx?] = []

///|
let core_ir_type_idx_free_reps : Array[Int] = []

///|
fn core_ir_type_idx_store(value : @lib.TypeIdx) -> TypeIdx {
  let rep = match core_ir_type_idx_free_reps.pop() {
    Some(rep) => {
      core_ir_type_idx_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_type_idx_values.length()
      core_ir_type_idx_values.push(Some(value))
      rep
    }
  }
  TypeIdx::new(rep)
}

///|
fn core_ir_type_idx_get(value : TypeIdx) -> @lib.TypeIdx {
  let TypeIdx(rep) = value
  if rep < 0 || rep >= core_ir_type_idx_values.length() {
    abort("invalid core-ir type-idx handle")
  }
  match core_ir_type_idx_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir type-idx handle")
  }
}

///|
fn core_ir_type_idx_option(value : TypeIdx?) -> @lib.TypeIdx? {
  match value {
    Some(value) => Some(core_ir_type_idx_get(value))
    None => None
  }
}

///|
fn core_ir_type_idx_array(values : Array[TypeIdx]) -> Array[@lib.TypeIdx] {
  values.map(fn(value) { core_ir_type_idx_get(value) })
}

///|
pub fn TypeIdx::dtor(self : TypeIdx) -> Unit {
  let TypeIdx(rep) = self
  if rep >= 0 && rep < core_ir_type_idx_values.length() {
    core_ir_type_idx_values[rep] = None
    core_ir_type_idx_free_reps.push(rep)
  }
}

///|
let core_ir_type_metadata_values : Array[@lib.TypeMetadata?] = []

///|
let core_ir_type_metadata_free_reps : Array[Int] = []

///|
fn core_ir_type_metadata_store(value : @lib.TypeMetadata) -> TypeMetadata {
  let rep = match core_ir_type_metadata_free_reps.pop() {
    Some(rep) => {
      core_ir_type_metadata_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_type_metadata_values.length()
      core_ir_type_metadata_values.push(Some(value))
      rep
    }
  }
  TypeMetadata::new(rep)
}

///|
fn core_ir_type_metadata_get(value : TypeMetadata) -> @lib.TypeMetadata {
  let TypeMetadata(rep) = value
  if rep < 0 || rep >= core_ir_type_metadata_values.length() {
    abort("invalid core-ir type-metadata handle")
  }
  match core_ir_type_metadata_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir type-metadata handle")
  }
}

///|
fn core_ir_type_metadata_option(value : TypeMetadata?) -> @lib.TypeMetadata? {
  match value {
    Some(value) => Some(core_ir_type_metadata_get(value))
    None => None
  }
}

///|
fn core_ir_type_metadata_array(values : Array[TypeMetadata]) -> Array[@lib.TypeMetadata] {
  values.map(fn(value) { core_ir_type_metadata_get(value) })
}

///|
pub fn TypeMetadata::dtor(self : TypeMetadata) -> Unit {
  let TypeMetadata(rep) = self
  if rep >= 0 && rep < core_ir_type_metadata_values.length() {
    core_ir_type_metadata_values[rep] = None
    core_ir_type_metadata_free_reps.push(rep)
  }
}

///|
let core_ir_type_sec_values : Array[@lib.TypeSec?] = []

///|
let core_ir_type_sec_free_reps : Array[Int] = []

///|
fn core_ir_type_sec_store(value : @lib.TypeSec) -> TypeSec {
  let rep = match core_ir_type_sec_free_reps.pop() {
    Some(rep) => {
      core_ir_type_sec_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_type_sec_values.length()
      core_ir_type_sec_values.push(Some(value))
      rep
    }
  }
  TypeSec::new(rep)
}

///|
fn core_ir_type_sec_get(value : TypeSec) -> @lib.TypeSec {
  let TypeSec(rep) = value
  if rep < 0 || rep >= core_ir_type_sec_values.length() {
    abort("invalid core-ir type-sec handle")
  }
  match core_ir_type_sec_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir type-sec handle")
  }
}

///|
fn core_ir_type_sec_option(value : TypeSec?) -> @lib.TypeSec? {
  match value {
    Some(value) => Some(core_ir_type_sec_get(value))
    None => None
  }
}

///|
fn core_ir_type_sec_array(values : Array[TypeSec]) -> Array[@lib.TypeSec] {
  values.map(fn(value) { core_ir_type_sec_get(value) })
}

///|
pub fn TypeSec::dtor(self : TypeSec) -> Unit {
  let TypeSec(rep) = self
  if rep >= 0 && rep < core_ir_type_sec_values.length() {
    core_ir_type_sec_values[rep] = None
    core_ir_type_sec_free_reps.push(rep)
  }
}

///|
let core_ir_u32_values : Array[@lib.U32?] = []

///|
let core_ir_u32_free_reps : Array[Int] = []

///|
fn core_ir_u32_store(value : @lib.U32) -> U32Ir {
  let rep = match core_ir_u32_free_reps.pop() {
    Some(rep) => {
      core_ir_u32_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_u32_values.length()
      core_ir_u32_values.push(Some(value))
      rep
    }
  }
  U32Ir::new(rep)
}

///|
fn core_ir_u32_get(value : U32Ir) -> @lib.U32 {
  let U32Ir(rep) = value
  if rep < 0 || rep >= core_ir_u32_values.length() {
    abort("invalid core-ir u32-ir handle")
  }
  match core_ir_u32_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir u32-ir handle")
  }
}

///|
fn core_ir_u32_option(value : U32Ir?) -> @lib.U32? {
  match value {
    Some(value) => Some(core_ir_u32_get(value))
    None => None
  }
}

///|
fn core_ir_u32_array(values : Array[U32Ir]) -> Array[@lib.U32] {
  values.map(fn(value) { core_ir_u32_get(value) })
}

///|
pub fn U32Ir::dtor(self : U32Ir) -> Unit {
  let U32Ir(rep) = self
  if rep >= 0 && rep < core_ir_u32_values.length() {
    core_ir_u32_values[rep] = None
    core_ir_u32_free_reps.push(rep)
  }
}

///|
let core_ir_u64_values : Array[@lib.U64?] = []

///|
let core_ir_u64_free_reps : Array[Int] = []

///|
fn core_ir_u64_store(value : @lib.U64) -> U64Ir {
  let rep = match core_ir_u64_free_reps.pop() {
    Some(rep) => {
      core_ir_u64_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_u64_values.length()
      core_ir_u64_values.push(Some(value))
      rep
    }
  }
  U64Ir::new(rep)
}

///|
fn core_ir_u64_get(value : U64Ir) -> @lib.U64 {
  let U64Ir(rep) = value
  if rep < 0 || rep >= core_ir_u64_values.length() {
    abort("invalid core-ir u64-ir handle")
  }
  match core_ir_u64_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir u64-ir handle")
  }
}

///|
fn core_ir_u64_option(value : U64Ir?) -> @lib.U64? {
  match value {
    Some(value) => Some(core_ir_u64_get(value))
    None => None
  }
}

///|
fn core_ir_u64_array(values : Array[U64Ir]) -> Array[@lib.U64] {
  values.map(fn(value) { core_ir_u64_get(value) })
}

///|
pub fn U64Ir::dtor(self : U64Ir) -> Unit {
  let U64Ir(rep) = self
  if rep >= 0 && rep < core_ir_u64_values.length() {
    core_ir_u64_values[rep] = None
    core_ir_u64_free_reps.push(rep)
  }
}

///|
let core_ir_val_type_values : Array[@lib.ValType?] = []

///|
let core_ir_val_type_free_reps : Array[Int] = []

///|
fn core_ir_val_type_store(value : @lib.ValType) -> ValType {
  let rep = match core_ir_val_type_free_reps.pop() {
    Some(rep) => {
      core_ir_val_type_values[rep] = Some(value)
      rep
    }
    None => {
      let rep = core_ir_val_type_values.length()
      core_ir_val_type_values.push(Some(value))
      rep
    }
  }
  ValType::new(rep)
}

///|
fn core_ir_val_type_get(value : ValType) -> @lib.ValType {
  let ValType(rep) = value
  if rep < 0 || rep >= core_ir_val_type_values.length() {
    abort("invalid core-ir val-type handle")
  }
  match core_ir_val_type_values[rep] {
    Some(value) => value
    None => abort("dropped core-ir val-type handle")
  }
}

///|
fn core_ir_val_type_option(value : ValType?) -> @lib.ValType? {
  match value {
    Some(value) => Some(core_ir_val_type_get(value))
    None => None
  }
}

///|
fn core_ir_val_type_array(values : Array[ValType]) -> Array[@lib.ValType] {
  values.map(fn(value) { core_ir_val_type_get(value) })
}

///|
pub fn ValType::dtor(self : ValType) -> Unit {
  let ValType(rep) = self
  if rep >= 0 && rep < core_ir_val_type_values.length() {
    core_ir_val_type_values[rep] = None
    core_ir_val_type_free_reps.push(rep)
  }
}

///|
pub fn AbsHeapType::any() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::any())
}

///|
pub fn AbsHeapType::array() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::array())
}

///|
pub fn AbsHeapType::cont() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::cont())
}

///|
pub fn AbsHeapType::eq() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::eq())
}

///|
pub fn AbsHeapType::exn() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::exn())
}

///|
pub fn AbsHeapType::extern_() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::extern_())
}

///|
pub fn AbsHeapType::func_value() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::func())
}

///|
pub fn AbsHeapType::i31() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::i31())
}

///|
pub fn AbsHeapType::no_cont() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::no_cont())
}

///|
pub fn AbsHeapType::no_exn() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::no_exn())
}

///|
pub fn AbsHeapType::no_extern() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::no_extern())
}

///|
pub fn AbsHeapType::no_func() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::no_func())
}

///|
pub fn AbsHeapType::none() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::none())
}

///|
pub fn AbsHeapType::string_value() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::string_())
}

///|
pub fn AbsHeapType::struct_() -> AbsHeapType {
  core_ir_abs_heap_type_store(@lib.AbsHeapType::struct_())
}

///|
pub fn AggregateAtomicRmwOp::add() -> AggregateAtomicRmwOp {
  core_ir_aggregate_atomic_rmw_op_store(@lib.AggregateAtomicRmwOp::add())
}

///|
pub fn AggregateAtomicRmwOp::and_() -> AggregateAtomicRmwOp {
  core_ir_aggregate_atomic_rmw_op_store(@lib.AggregateAtomicRmwOp::and_())
}

///|
pub fn AggregateAtomicRmwOp::or() -> AggregateAtomicRmwOp {
  core_ir_aggregate_atomic_rmw_op_store(@lib.AggregateAtomicRmwOp::or_())
}

///|
pub fn AggregateAtomicRmwOp::sub() -> AggregateAtomicRmwOp {
  core_ir_aggregate_atomic_rmw_op_store(@lib.AggregateAtomicRmwOp::sub())
}

///|
pub fn AggregateAtomicRmwOp::xchg() -> AggregateAtomicRmwOp {
  core_ir_aggregate_atomic_rmw_op_store(@lib.AggregateAtomicRmwOp::xchg())
}

///|
pub fn AggregateAtomicRmwOp::xor() -> AggregateAtomicRmwOp {
  core_ir_aggregate_atomic_rmw_op_store(@lib.AggregateAtomicRmwOp::xor())
}

///|
pub fn AtomicCmpxchgOp::i32() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i32())
}

///|
pub fn AtomicCmpxchgOp::i32_16_u() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i32_16_u())
}

///|
pub fn AtomicCmpxchgOp::i32_8_u() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i32_8_u())
}

///|
pub fn AtomicCmpxchgOp::i64() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i64())
}

///|
pub fn AtomicCmpxchgOp::i64_16_u() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i64_16_u())
}

///|
pub fn AtomicCmpxchgOp::i64_32_u() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i64_32_u())
}

///|
pub fn AtomicCmpxchgOp::i64_8_u() -> AtomicCmpxchgOp {
  core_ir_atomic_cmpxchg_op_store(@lib.AtomicCmpxchgOp::i64_8_u())
}

///|
pub fn AtomicOrder::acq_rel() -> AtomicOrder {
  core_ir_atomic_order_store(@lib.AtomicOrder::acq_rel())
}

///|
pub fn AtomicOrder::seq_cst() -> AtomicOrder {
  core_ir_atomic_order_store(@lib.AtomicOrder::seq_cst())
}

///|
pub fn AtomicRmwOp::i32_16_add_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_16_add_u())
}

///|
pub fn AtomicRmwOp::i32_16_and_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_16_and_u())
}

///|
pub fn AtomicRmwOp::i32_16_or_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_16_or_u())
}

///|
pub fn AtomicRmwOp::i32_16_sub_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_16_sub_u())
}

///|
pub fn AtomicRmwOp::i32_16_xchg_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_16_xchg_u())
}

///|
pub fn AtomicRmwOp::i32_16_xor_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_16_xor_u())
}

///|
pub fn AtomicRmwOp::i32_8_add_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_8_add_u())
}

///|
pub fn AtomicRmwOp::i32_8_and_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_8_and_u())
}

///|
pub fn AtomicRmwOp::i32_8_or_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_8_or_u())
}

///|
pub fn AtomicRmwOp::i32_8_sub_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_8_sub_u())
}

///|
pub fn AtomicRmwOp::i32_8_xchg_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_8_xchg_u())
}

///|
pub fn AtomicRmwOp::i32_8_xor_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_8_xor_u())
}

///|
pub fn AtomicRmwOp::i32_add() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_add())
}

///|
pub fn AtomicRmwOp::i32_and() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_and())
}

///|
pub fn AtomicRmwOp::i32_or() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_or())
}

///|
pub fn AtomicRmwOp::i32_sub() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_sub())
}

///|
pub fn AtomicRmwOp::i32_xchg() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_xchg())
}

///|
pub fn AtomicRmwOp::i32_xor() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i32_xor())
}

///|
pub fn AtomicRmwOp::i64_16_add_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_16_add_u())
}

///|
pub fn AtomicRmwOp::i64_16_and_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_16_and_u())
}

///|
pub fn AtomicRmwOp::i64_16_or_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_16_or_u())
}

///|
pub fn AtomicRmwOp::i64_16_sub_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_16_sub_u())
}

///|
pub fn AtomicRmwOp::i64_16_xchg_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_16_xchg_u())
}

///|
pub fn AtomicRmwOp::i64_16_xor_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_16_xor_u())
}

///|
pub fn AtomicRmwOp::i64_32_add_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_32_add_u())
}

///|
pub fn AtomicRmwOp::i64_32_and_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_32_and_u())
}

///|
pub fn AtomicRmwOp::i64_32_or_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_32_or_u())
}

///|
pub fn AtomicRmwOp::i64_32_sub_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_32_sub_u())
}

///|
pub fn AtomicRmwOp::i64_32_xchg_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_32_xchg_u())
}

///|
pub fn AtomicRmwOp::i64_32_xor_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_32_xor_u())
}

///|
pub fn AtomicRmwOp::i64_8_add_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_8_add_u())
}

///|
pub fn AtomicRmwOp::i64_8_and_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_8_and_u())
}

///|
pub fn AtomicRmwOp::i64_8_or_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_8_or_u())
}

///|
pub fn AtomicRmwOp::i64_8_sub_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_8_sub_u())
}

///|
pub fn AtomicRmwOp::i64_8_xchg_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_8_xchg_u())
}

///|
pub fn AtomicRmwOp::i64_8_xor_u() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_8_xor_u())
}

///|
pub fn AtomicRmwOp::i64_add() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_add())
}

///|
pub fn AtomicRmwOp::i64_and() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_and())
}

///|
pub fn AtomicRmwOp::i64_or() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_or())
}

///|
pub fn AtomicRmwOp::i64_sub() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_sub())
}

///|
pub fn AtomicRmwOp::i64_xchg() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_xchg())
}

///|
pub fn AtomicRmwOp::i64_xor() -> AtomicRmwOp {
  core_ir_atomic_rmw_op_store(@lib.AtomicRmwOp::i64_xor())
}

///|
pub fn BlockType::type_idx(
  p0 : TypeIdx
) -> BlockType {
  core_ir_block_type_store(@lib.BlockType::type_idx(core_ir_type_idx_get(p0)))
}

///|
pub fn BlockType::val_type(
  p0 : ValType
) -> BlockType {
  core_ir_block_type_store(@lib.BlockType::val_type(core_ir_val_type_get(p0)))
}

///|
pub fn BlockType::void_() -> BlockType {
  core_ir_block_type_store(@lib.BlockType::void_())
}

///|
pub fn Catch::all(
  p0 : LabelIdx
) -> Catch {
  core_ir_catch_store(@lib.Catch::all(core_ir_label_idx_get(p0)))
}

///|
pub fn Catch::all_ref(
  p0 : LabelIdx
) -> Catch {
  core_ir_catch_store(@lib.Catch::all_ref(core_ir_label_idx_get(p0)))
}

///|
pub fn Catch::create(
  p0 : TagIdx,
  p1 : LabelIdx
) -> Catch {
  core_ir_catch_store(@lib.Catch::new(core_ir_tag_idx_get(p0), core_ir_label_idx_get(p1)))
}

///|
pub fn Catch::ref_(
  p0 : TagIdx,
  p1 : LabelIdx
) -> Catch {
  core_ir_catch_store(@lib.Catch::ref_(core_ir_tag_idx_get(p0), core_ir_label_idx_get(p1)))
}

///|
pub fn CodeSec::create(
  p0 : Array[FuncIr]
) -> CodeSec {
  core_ir_code_sec_store(@lib.CodeSec::new(core_ir_func_array(p0)))
}

///|
pub fn CompType::array(
  p0 : FieldType
) -> CompType {
  core_ir_comp_type_store(@lib.CompType::array(core_ir_field_type_get(p0)))
}

///|
pub fn CompType::cont(
  p0 : TypeIdx
) -> CompType {
  core_ir_comp_type_store(@lib.CompType::cont(core_ir_type_idx_get(p0)))
}

///|
pub fn CompType::func_value(
  p0 : Array[ValType],
  p1 : Array[ValType]
) -> CompType {
  core_ir_comp_type_store(@lib.CompType::func(core_ir_val_type_array(p0), core_ir_val_type_array(p1)))
}

///|
pub fn CompType::struct_(
  p0 : Array[FieldType]
) -> CompType {
  core_ir_comp_type_store(@lib.CompType::struct_(core_ir_field_type_array(p0)))
}

///|
pub fn CustomSec::create(
  p0 : Name,
  p1 : FixedArray[Byte]
) -> CustomSec {
  core_ir_custom_sec_store(@lib.CustomSec::new(core_ir_name_get(p0), core_ir_bytes(p1)))
}

///|
pub fn Data::create(
  p0 : DataMode,
  p1 : FixedArray[Byte]
) -> Data {
  core_ir_data_store(@lib.Data::new(core_ir_data_mode_get(p0), core_ir_bytes(p1)))
}

///|
pub fn DataCntSec::create(
  p0 : U32Ir
) -> DataCntSec {
  core_ir_data_cnt_sec_store(@lib.DataCntSec::new(core_ir_u32_get(p0)))
}

///|
pub fn DataIdx::create(
  p0 : UInt
) -> DataIdx {
  core_ir_data_idx_store(@lib.DataIdx::new(p0))
}

///|
pub fn DataMode::active(
  p0 : MemIdx,
  p1 : Expr
) -> DataMode {
  core_ir_data_mode_store(@lib.DataMode::active(core_ir_mem_idx_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn DataMode::passive() -> DataMode {
  core_ir_data_mode_store(@lib.DataMode::passive())
}

///|
pub fn DataSec::create(
  p0 : Array[Data]
) -> DataSec {
  core_ir_data_sec_store(@lib.DataSec::new(core_ir_data_array(p0)))
}

///|
pub fn DefType::create(
  p0 : RecType,
  p1 : UInt
) -> DefType {
  core_ir_def_type_store(@lib.DefType::new(core_ir_rec_type_get(p0), p1))
}

///|
pub fn Elem::create(
  p0 : ElemMode,
  p1 : ElemKind
) -> Elem {
  core_ir_elem_store(@lib.Elem::new(core_ir_elem_mode_get(p0), core_ir_elem_kind_get(p1)))
}

///|
pub fn ElemIdx::create(
  p0 : UInt
) -> ElemIdx {
  core_ir_elem_idx_store(@lib.ElemIdx::new(p0))
}

///|
pub fn ElemKind::func_exprs(
  p0 : Array[Expr]
) -> ElemKind {
  core_ir_elem_kind_store(@lib.ElemKind::func_exprs(core_ir_expr_array(p0)))
}

///|
pub fn ElemKind::funcs(
  p0 : Array[FuncIdx]
) -> ElemKind {
  core_ir_elem_kind_store(@lib.ElemKind::funcs(core_ir_func_idx_array(p0)))
}

///|
pub fn ElemKind::typed_exprs(
  p0 : RefType,
  p1 : Array[Expr]
) -> ElemKind {
  core_ir_elem_kind_store(@lib.ElemKind::typed_exprs(core_ir_ref_type_get(p0), core_ir_expr_array(p1)))
}

///|
pub fn ElemMode::active(
  p0 : TableIdx,
  p1 : Expr
) -> ElemMode {
  core_ir_elem_mode_store(@lib.ElemMode::active(core_ir_table_idx_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn ElemMode::declarative() -> ElemMode {
  core_ir_elem_mode_store(@lib.ElemMode::declarative())
}

///|
pub fn ElemMode::passive() -> ElemMode {
  core_ir_elem_mode_store(@lib.ElemMode::passive())
}

///|
pub fn ElemSec::create(
  p0 : Array[Elem]
) -> ElemSec {
  core_ir_elem_sec_store(@lib.ElemSec::new(core_ir_elem_array(p0)))
}

///|
pub fn ExportIr::create(
  p0 : Name,
  p1 : ExternIdx
) -> ExportIr {
  core_ir_export_store(@lib.Export::new(core_ir_name_get(p0), core_ir_extern_idx_get(p1)))
}

///|
pub fn ExportSec::create(
  p0 : Array[ExportIr]
) -> ExportSec {
  core_ir_export_sec_store(@lib.ExportSec::new(core_ir_export_array(p0)))
}

///|
pub fn Expr::create(
  p0 : Array[Instruction]
) -> Expr {
  core_ir_expr_store(@lib.Expr::new(core_ir_instruction_array(p0)))
}

///|
pub fn ExternIdx::func_value(
  p0 : FuncIdx
) -> ExternIdx {
  core_ir_extern_idx_store(@lib.ExternIdx::func(core_ir_func_idx_get(p0)))
}

///|
pub fn ExternIdx::global(
  p0 : GlobalIdx
) -> ExternIdx {
  core_ir_extern_idx_store(@lib.ExternIdx::global(core_ir_global_idx_get(p0)))
}

///|
pub fn ExternIdx::mem(
  p0 : MemIdx
) -> ExternIdx {
  core_ir_extern_idx_store(@lib.ExternIdx::mem(core_ir_mem_idx_get(p0)))
}

///|
pub fn ExternIdx::table(
  p0 : TableIdx
) -> ExternIdx {
  core_ir_extern_idx_store(@lib.ExternIdx::table(core_ir_table_idx_get(p0)))
}

///|
pub fn ExternIdx::tag(
  p0 : TagIdx
) -> ExternIdx {
  core_ir_extern_idx_store(@lib.ExternIdx::tag(core_ir_tag_idx_get(p0)))
}

///|
pub fn ExternType::func_value(
  p0 : TypeIdx
) -> ExternType {
  core_ir_extern_type_store(@lib.ExternType::func(core_ir_type_idx_get(p0)))
}

///|
pub fn ExternType::global(
  p0 : GlobalType
) -> ExternType {
  core_ir_extern_type_store(@lib.ExternType::global(core_ir_global_type_get(p0)))
}

///|
pub fn ExternType::mem(
  p0 : MemType
) -> ExternType {
  core_ir_extern_type_store(@lib.ExternType::mem(core_ir_mem_type_get(p0)))
}

///|
pub fn ExternType::table(
  p0 : TableType
) -> ExternType {
  core_ir_extern_type_store(@lib.ExternType::table(core_ir_table_type_get(p0)))
}

///|
pub fn ExternType::tag(
  p0 : TagType
) -> ExternType {
  core_ir_extern_type_store(@lib.ExternType::tag(core_ir_tag_type_get(p0)))
}

///|
pub fn F32Ir::create(
  p0 : Float
) -> F32Ir {
  core_ir_f32_store(@lib.F32::new(p0))
}

///|
pub fn F64Ir::create(
  p0 : Double
) -> F64Ir {
  core_ir_f64_store(@lib.F64::new(p0))
}

///|
pub fn FieldType::create(
  p0 : StorageType,
  p1 : Mut
) -> FieldType {
  core_ir_field_type_store(@lib.FieldType::new(core_ir_storage_type_get(p0), core_ir_mut_get(p1)))
}

///|
pub fn FuncIr::create(
  p0 : Locals,
  p1 : Expr
) -> FuncIr {
  core_ir_func_store(@lib.Func::new(core_ir_locals_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn FuncAnnotation::create(
  p0 : String,
  args : Array[String]
) -> FuncAnnotation {
  core_ir_func_annotation_store(@lib.FuncAnnotation::new(p0, args=args))
}

///|
pub fn FuncAnnotationAssoc::create(
  p0 : UInt,
  p1 : Array[FuncAnnotation]
) -> FuncAnnotationAssoc {
  core_ir_func_annotation_assoc_store(@lib.FuncAnnotationAssoc::new(p0, core_ir_func_annotation_array(p1)))
}

///|
pub fn FuncAnnotationSec::create(
  p0 : Array[FuncAnnotationAssoc]
) -> FuncAnnotationSec {
  core_ir_func_annotation_sec_store(@lib.FuncAnnotationSec::new(core_ir_func_annotation_assoc_array(p0)))
}

///|
pub fn FuncIdx::create(
  p0 : UInt
) -> FuncIdx {
  core_ir_func_idx_store(@lib.FuncIdx::new(p0))
}

///|
pub fn FuncSec::create(
  p0 : Array[TypeIdx]
) -> FuncSec {
  core_ir_func_sec_store(@lib.FuncSec::new(core_ir_type_idx_array(p0)))
}

///|
pub fn Global::create(
  p0 : GlobalType,
  p1 : Expr
) -> Global {
  core_ir_global_store(@lib.Global::new(core_ir_global_type_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn GlobalIdx::create(
  p0 : UInt
) -> GlobalIdx {
  core_ir_global_idx_store(@lib.GlobalIdx::new(p0))
}

///|
pub fn GlobalSec::create(
  p0 : Array[Global]
) -> GlobalSec {
  core_ir_global_sec_store(@lib.GlobalSec::new(core_ir_global_array(p0)))
}

///|
pub fn GlobalType::create(
  p0 : ValType,
  p1 : Bool
) -> GlobalType {
  core_ir_global_type_store(@lib.GlobalType::new(core_ir_val_type_get(p0), p1))
}

///|
pub fn HeapType::abs(
  p0 : AbsHeapType
) -> HeapType {
  core_ir_heap_type_store(@lib.HeapType::abs(core_ir_abs_heap_type_get(p0)))
}

///|
pub fn HeapType::bottom() -> HeapType {
  core_ir_heap_type_store(@lib.HeapType::bottom())
}

///|
pub fn HeapType::def_type(
  p0 : DefType
) -> HeapType {
  core_ir_heap_type_store(@lib.HeapType::def_type(core_ir_def_type_get(p0)))
}

///|
pub fn HeapType::create(
  p0 : TypeIdx
) -> HeapType {
  core_ir_heap_type_store(@lib.HeapType::new(core_ir_type_idx_get(p0)))
}

///|
pub fn HeapType::shared_abs(
  p0 : AbsHeapType
) -> HeapType {
  core_ir_heap_type_store(@lib.HeapType::shared_abs(core_ir_abs_heap_type_get(p0)))
}

///|
pub fn I32::create(
  p0 : Int
) -> I32 {
  core_ir_i32_store(@lib.I32::new(p0))
}

///|
pub fn I64::create(
  p0 : Int64
) -> I64 {
  core_ir_i64_store(@lib.I64::new(p0))
}

///|
pub fn ImportIr::create(
  p0 : Name,
  p1 : Name,
  p2 : ExternType
) -> ImportIr {
  core_ir_import_store(@lib.Import::new(core_ir_name_get(p0), core_ir_name_get(p1), core_ir_extern_type_get(p2)))
}

///|
pub fn ImportSec::create(
  p0 : Array[ImportIr]
) -> ImportSec {
  core_ir_import_sec_store(@lib.ImportSec::new(core_ir_import_array(p0)))
}

///|
pub fn IndirectNameAssoc::create(
  p0 : UInt,
  p1 : NameMap
) -> IndirectNameAssoc {
  core_ir_indirect_name_assoc_store(@lib.IndirectNameAssoc::new(p0, core_ir_name_map_get(p1)))
}

///|
pub fn IndirectNameMap::create(
  p0 : Array[IndirectNameAssoc]
) -> IndirectNameMap {
  core_ir_indirect_name_map_store(@lib.IndirectNameMap::new(core_ir_indirect_name_assoc_array(p0)))
}

///|
pub fn Instruction::any_convert_extern() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::any_convert_extern())
}

///|
pub fn Instruction::array_atomic_cmpxchg(
  p0 : TypeIdx,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_atomic_cmpxchg(core_ir_type_idx_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::array_atomic_get(
  p0 : AtomicOrder,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_atomic_get(core_ir_atomic_order_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::array_atomic_get_s(
  p0 : AtomicOrder,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_atomic_get_s(core_ir_atomic_order_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::array_atomic_get_u(
  p0 : AtomicOrder,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_atomic_get_u(core_ir_atomic_order_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::array_atomic_rmw(
  p0 : AggregateAtomicRmwOp,
  p1 : TypeIdx,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_atomic_rmw(core_ir_aggregate_atomic_rmw_op_get(p0), core_ir_type_idx_get(p1), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::array_copy(
  p0 : TypeIdx,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_copy(core_ir_type_idx_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::array_fill(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_fill(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_get(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_get(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_get_s(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_get_s(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_get_u(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_get_u(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_init_data(
  p0 : TypeIdx,
  p1 : DataIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_init_data(core_ir_type_idx_get(p0), core_ir_data_idx_get(p1)))
}

///|
pub fn Instruction::array_init_elem(
  p0 : TypeIdx,
  p1 : ElemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_init_elem(core_ir_type_idx_get(p0), core_ir_elem_idx_get(p1)))
}

///|
pub fn Instruction::array_len() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_len())
}

///|
pub fn Instruction::array_load(
  p0 : LoadOp,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_load(core_ir_load_op_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::array_new(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_new(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_new_data(
  p0 : TypeIdx,
  p1 : DataIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_new_data(core_ir_type_idx_get(p0), core_ir_data_idx_get(p1)))
}

///|
pub fn Instruction::array_new_default(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_new_default(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_new_elem(
  p0 : TypeIdx,
  p1 : ElemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_new_elem(core_ir_type_idx_get(p0), core_ir_elem_idx_get(p1)))
}

///|
pub fn Instruction::array_new_fixed(
  p0 : TypeIdx,
  p1 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_new_fixed(core_ir_type_idx_get(p0), core_ir_u32_get(p1)))
}

///|
pub fn Instruction::array_set(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_set(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::array_store(
  p0 : StoreOp,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::array_store(core_ir_store_op_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::atomic_cmpxchg(
  p0 : AtomicCmpxchgOp,
  p1 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::atomic_cmpxchg(core_ir_atomic_cmpxchg_op_get(p0), core_ir_mem_arg_get(p1), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::atomic_fence(
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::atomic_fence(order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::atomic_rmw(
  p0 : AtomicRmwOp,
  p1 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::atomic_rmw(core_ir_atomic_rmw_op_get(p0), core_ir_mem_arg_get(p1), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::block(
  p0 : BlockType,
  p1 : Expr
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::block(core_ir_block_type_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn Instruction::br(
  p0 : LabelIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br(core_ir_label_idx_get(p0)))
}

///|
pub fn Instruction::br_if(
  p0 : LabelIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_if(core_ir_label_idx_get(p0)))
}

///|
pub fn Instruction::br_on_cast(
  p0 : LabelIdx,
  p1 : Bool,
  p2 : HeapType,
  p3 : Bool,
  p4 : HeapType,
  source_exact : Bool,
  target_exact : Bool
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_on_cast(core_ir_label_idx_get(p0), p1, core_ir_heap_type_get(p2), p3, core_ir_heap_type_get(p4), source_exact=source_exact, target_exact=target_exact))
}

///|
pub fn Instruction::br_on_cast_desc_eq(
  p0 : LabelIdx,
  p1 : RefType,
  p2 : RefType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_on_cast_desc_eq(core_ir_label_idx_get(p0), core_ir_ref_type_get(p1), core_ir_ref_type_get(p2)))
}

///|
pub fn Instruction::br_on_cast_desc_eq_fail(
  p0 : LabelIdx,
  p1 : RefType,
  p2 : RefType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_on_cast_desc_eq_fail(core_ir_label_idx_get(p0), core_ir_ref_type_get(p1), core_ir_ref_type_get(p2)))
}

///|
pub fn Instruction::br_on_cast_fail(
  p0 : LabelIdx,
  p1 : Bool,
  p2 : HeapType,
  p3 : Bool,
  p4 : HeapType,
  source_exact : Bool,
  target_exact : Bool
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_on_cast_fail(core_ir_label_idx_get(p0), p1, core_ir_heap_type_get(p2), p3, core_ir_heap_type_get(p4), source_exact=source_exact, target_exact=target_exact))
}

///|
pub fn Instruction::br_on_non_null(
  p0 : LabelIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_on_non_null(core_ir_label_idx_get(p0)))
}

///|
pub fn Instruction::br_on_null(
  p0 : LabelIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_on_null(core_ir_label_idx_get(p0)))
}

///|
pub fn Instruction::br_table(
  p0 : Array[LabelIdx],
  p1 : LabelIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::br_table(core_ir_label_idx_array(p0), core_ir_label_idx_get(p1)))
}

///|
pub fn Instruction::call(
  p0 : FuncIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::call(core_ir_func_idx_get(p0)))
}

///|
pub fn Instruction::call_indirect(
  p0 : TypeIdx,
  p1 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::call_indirect(core_ir_type_idx_get(p0), core_ir_table_idx_get(p1)))
}

///|
pub fn Instruction::call_ref(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::call_ref(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::cont_bind(
  p0 : TypeIdx,
  p1 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::cont_bind(core_ir_type_idx_get(p0), core_ir_type_idx_get(p1)))
}

///|
pub fn Instruction::cont_new(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::cont_new(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::data_drop(
  p0 : DataIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::data_drop(core_ir_data_idx_get(p0)))
}

///|
pub fn Instruction::drop_op() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::drop())
}

///|
pub fn Instruction::elem_drop(
  p0 : ElemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::elem_drop(core_ir_elem_idx_get(p0)))
}

///|
pub fn Instruction::extern_convert_any() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::extern_convert_any())
}

///|
pub fn Instruction::f32_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_abs())
}

///|
pub fn Instruction::f32_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_add())
}

///|
pub fn Instruction::f32_ceil() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_ceil())
}

///|
pub fn Instruction::f32_const(
  p0 : F32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_const(core_ir_f32_get(p0)))
}

///|
pub fn Instruction::f32_convert_i32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_convert_i32s())
}

///|
pub fn Instruction::f32_convert_i32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_convert_i32u())
}

///|
pub fn Instruction::f32_convert_i64s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_convert_i64s())
}

///|
pub fn Instruction::f32_convert_i64u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_convert_i64u())
}

///|
pub fn Instruction::f32_copysign() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_copysign())
}

///|
pub fn Instruction::f32_demote_f64() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_demote_f64())
}

///|
pub fn Instruction::f32_div() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_div())
}

///|
pub fn Instruction::f32_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_eq())
}

///|
pub fn Instruction::f32_floor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_floor())
}

///|
pub fn Instruction::f32_ge() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_ge())
}

///|
pub fn Instruction::f32_gt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_gt())
}

///|
pub fn Instruction::f32_le() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_le())
}

///|
pub fn Instruction::f32_load(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_load(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::f32_lt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_lt())
}

///|
pub fn Instruction::f32_max() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_max())
}

///|
pub fn Instruction::f32_min() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_min())
}

///|
pub fn Instruction::f32_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_mul())
}

///|
pub fn Instruction::f32_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_ne())
}

///|
pub fn Instruction::f32_nearest() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_nearest())
}

///|
pub fn Instruction::f32_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_neg())
}

///|
pub fn Instruction::f32_reinterpret_i32() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_reinterpret_i32())
}

///|
pub fn Instruction::f32_sqrt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_sqrt())
}

///|
pub fn Instruction::f32_store(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_store(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::f32_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_sub())
}

///|
pub fn Instruction::f32_trunc() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32_trunc())
}

///|
pub fn Instruction::f32x4_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_abs())
}

///|
pub fn Instruction::f32x4_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_add())
}

///|
pub fn Instruction::f32x4_ceil() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_ceil())
}

///|
pub fn Instruction::f32x4_convert_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_convert_i32x4s())
}

///|
pub fn Instruction::f32x4_convert_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_convert_i32x4u())
}

///|
pub fn Instruction::f32x4_demote_f64x2_zero() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_demote_f64x2_zero())
}

///|
pub fn Instruction::f32x4_div() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_div())
}

///|
pub fn Instruction::f32x4_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_eq())
}

///|
pub fn Instruction::f32x4_extract_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_extract_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::f32x4_floor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_floor())
}

///|
pub fn Instruction::f32x4_ge() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_ge())
}

///|
pub fn Instruction::f32x4_gt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_gt())
}

///|
pub fn Instruction::f32x4_le() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_le())
}

///|
pub fn Instruction::f32x4_lt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_lt())
}

///|
pub fn Instruction::f32x4_max() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_max())
}

///|
pub fn Instruction::f32x4_min() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_min())
}

///|
pub fn Instruction::f32x4_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_mul())
}

///|
pub fn Instruction::f32x4_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_ne())
}

///|
pub fn Instruction::f32x4_nearest() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_nearest())
}

///|
pub fn Instruction::f32x4_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_neg())
}

///|
pub fn Instruction::f32x4_pmax() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_pmax())
}

///|
pub fn Instruction::f32x4_pmin() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_pmin())
}

///|
pub fn Instruction::f32x4_relaxed_madd() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_relaxed_madd())
}

///|
pub fn Instruction::f32x4_relaxed_max() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_relaxed_max())
}

///|
pub fn Instruction::f32x4_relaxed_min() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_relaxed_min())
}

///|
pub fn Instruction::f32x4_relaxed_nmadd() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_relaxed_nmadd())
}

///|
pub fn Instruction::f32x4_replace_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_replace_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::f32x4_splat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_splat())
}

///|
pub fn Instruction::f32x4_sqrt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_sqrt())
}

///|
pub fn Instruction::f32x4_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_sub())
}

///|
pub fn Instruction::f32x4_trunc() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f32x4_trunc())
}

///|
pub fn Instruction::f64_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_abs())
}

///|
pub fn Instruction::f64_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_add())
}

///|
pub fn Instruction::f64_ceil() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_ceil())
}

///|
pub fn Instruction::f64_const(
  p0 : F64Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_const(core_ir_f64_get(p0)))
}

///|
pub fn Instruction::f64_convert_i32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_convert_i32s())
}

///|
pub fn Instruction::f64_convert_i32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_convert_i32u())
}

///|
pub fn Instruction::f64_convert_i64s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_convert_i64s())
}

///|
pub fn Instruction::f64_convert_i64u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_convert_i64u())
}

///|
pub fn Instruction::f64_copysign() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_copysign())
}

///|
pub fn Instruction::f64_div() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_div())
}

///|
pub fn Instruction::f64_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_eq())
}

///|
pub fn Instruction::f64_floor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_floor())
}

///|
pub fn Instruction::f64_ge() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_ge())
}

///|
pub fn Instruction::f64_gt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_gt())
}

///|
pub fn Instruction::f64_le() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_le())
}

///|
pub fn Instruction::f64_load(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_load(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::f64_lt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_lt())
}

///|
pub fn Instruction::f64_max() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_max())
}

///|
pub fn Instruction::f64_min() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_min())
}

///|
pub fn Instruction::f64_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_mul())
}

///|
pub fn Instruction::f64_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_ne())
}

///|
pub fn Instruction::f64_nearest() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_nearest())
}

///|
pub fn Instruction::f64_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_neg())
}

///|
pub fn Instruction::f64_promote_f32() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_promote_f32())
}

///|
pub fn Instruction::f64_reinterpret_i64() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_reinterpret_i64())
}

///|
pub fn Instruction::f64_sqrt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_sqrt())
}

///|
pub fn Instruction::f64_store(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_store(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::f64_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_sub())
}

///|
pub fn Instruction::f64_trunc() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64_trunc())
}

///|
pub fn Instruction::f64x2_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_abs())
}

///|
pub fn Instruction::f64x2_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_add())
}

///|
pub fn Instruction::f64x2_ceil() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_ceil())
}

///|
pub fn Instruction::f64x2_convert_low_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_convert_low_i32x4s())
}

///|
pub fn Instruction::f64x2_convert_low_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_convert_low_i32x4u())
}

///|
pub fn Instruction::f64x2_div() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_div())
}

///|
pub fn Instruction::f64x2_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_eq())
}

///|
pub fn Instruction::f64x2_extract_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_extract_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::f64x2_floor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_floor())
}

///|
pub fn Instruction::f64x2_ge() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_ge())
}

///|
pub fn Instruction::f64x2_gt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_gt())
}

///|
pub fn Instruction::f64x2_le() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_le())
}

///|
pub fn Instruction::f64x2_lt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_lt())
}

///|
pub fn Instruction::f64x2_max() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_max())
}

///|
pub fn Instruction::f64x2_min() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_min())
}

///|
pub fn Instruction::f64x2_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_mul())
}

///|
pub fn Instruction::f64x2_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_ne())
}

///|
pub fn Instruction::f64x2_nearest() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_nearest())
}

///|
pub fn Instruction::f64x2_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_neg())
}

///|
pub fn Instruction::f64x2_pmax() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_pmax())
}

///|
pub fn Instruction::f64x2_pmin() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_pmin())
}

///|
pub fn Instruction::f64x2_promote_low_f32x4() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_promote_low_f32x4())
}

///|
pub fn Instruction::f64x2_relaxed_madd() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_relaxed_madd())
}

///|
pub fn Instruction::f64x2_relaxed_max() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_relaxed_max())
}

///|
pub fn Instruction::f64x2_relaxed_min() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_relaxed_min())
}

///|
pub fn Instruction::f64x2_relaxed_nmadd() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_relaxed_nmadd())
}

///|
pub fn Instruction::f64x2_replace_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_replace_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::f64x2_splat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_splat())
}

///|
pub fn Instruction::f64x2_sqrt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_sqrt())
}

///|
pub fn Instruction::f64x2_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_sub())
}

///|
pub fn Instruction::f64x2_trunc() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::f64x2_trunc())
}

///|
pub fn Instruction::global_get(
  p0 : GlobalIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::global_get(core_ir_global_idx_get(p0)))
}

///|
pub fn Instruction::global_set(
  p0 : GlobalIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::global_set(core_ir_global_idx_get(p0)))
}

///|
pub fn Instruction::i16x8_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_abs())
}

///|
pub fn Instruction::i16x8_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_add())
}

///|
pub fn Instruction::i16x8_add_sat_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_add_sat_s())
}

///|
pub fn Instruction::i16x8_add_sat_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_add_sat_u())
}

///|
pub fn Instruction::i16x8_all_true() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_all_true())
}

///|
pub fn Instruction::i16x8_avgr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_avgr_u())
}

///|
pub fn Instruction::i16x8_bitmask() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_bitmask())
}

///|
pub fn Instruction::i16x8_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_eq())
}

///|
pub fn Instruction::i16x8_extadd_pairwise_i8x16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extadd_pairwise_i8x16s())
}

///|
pub fn Instruction::i16x8_extadd_pairwise_i8x16u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extadd_pairwise_i8x16u())
}

///|
pub fn Instruction::i16x8_extend_high_i8x16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extend_high_i8x16s())
}

///|
pub fn Instruction::i16x8_extend_high_i8x16u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extend_high_i8x16u())
}

///|
pub fn Instruction::i16x8_extend_low_i8x16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extend_low_i8x16s())
}

///|
pub fn Instruction::i16x8_extend_low_i8x16u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extend_low_i8x16u())
}

///|
pub fn Instruction::i16x8_extmul_high_i8x16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extmul_high_i8x16s())
}

///|
pub fn Instruction::i16x8_extmul_high_i8x16u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extmul_high_i8x16u())
}

///|
pub fn Instruction::i16x8_extmul_low_i8x16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extmul_low_i8x16s())
}

///|
pub fn Instruction::i16x8_extmul_low_i8x16u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extmul_low_i8x16u())
}

///|
pub fn Instruction::i16x8_extract_lane_s(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extract_lane_s(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i16x8_extract_lane_u(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_extract_lane_u(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i16x8_ge_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_ge_s())
}

///|
pub fn Instruction::i16x8_ge_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_ge_u())
}

///|
pub fn Instruction::i16x8_gt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_gt_s())
}

///|
pub fn Instruction::i16x8_gt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_gt_u())
}

///|
pub fn Instruction::i16x8_le_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_le_s())
}

///|
pub fn Instruction::i16x8_le_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_le_u())
}

///|
pub fn Instruction::i16x8_lt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_lt_s())
}

///|
pub fn Instruction::i16x8_lt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_lt_u())
}

///|
pub fn Instruction::i16x8_max_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_max_s())
}

///|
pub fn Instruction::i16x8_max_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_max_u())
}

///|
pub fn Instruction::i16x8_min_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_min_s())
}

///|
pub fn Instruction::i16x8_min_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_min_u())
}

///|
pub fn Instruction::i16x8_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_mul())
}

///|
pub fn Instruction::i16x8_narrow_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_narrow_i32x4s())
}

///|
pub fn Instruction::i16x8_narrow_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_narrow_i32x4u())
}

///|
pub fn Instruction::i16x8_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_ne())
}

///|
pub fn Instruction::i16x8_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_neg())
}

///|
pub fn Instruction::i16x8_relaxed_dot_i8x16i7x16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_relaxed_dot_i8x16i7x16s())
}

///|
pub fn Instruction::i16x8_relaxed_laneselect() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_relaxed_laneselect())
}

///|
pub fn Instruction::i16x8_relaxed_q15mulr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_relaxed_q15mulr_s())
}

///|
pub fn Instruction::i16x8_replace_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_replace_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i16x8_shl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_shl())
}

///|
pub fn Instruction::i16x8_shr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_shr_s())
}

///|
pub fn Instruction::i16x8_shr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_shr_u())
}

///|
pub fn Instruction::i16x8_splat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_splat())
}

///|
pub fn Instruction::i16x8_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_sub())
}

///|
pub fn Instruction::i16x8_sub_sat_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_sub_sat_s())
}

///|
pub fn Instruction::i16x8_sub_sat_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8_sub_sat_u())
}

///|
pub fn Instruction::i16x8q15mulr_sat_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i16x8q15mulr_sat_s())
}

///|
pub fn Instruction::i31_get_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i31_get_s())
}

///|
pub fn Instruction::i31_get_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i31_get_u())
}

///|
pub fn Instruction::i32_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_add())
}

///|
pub fn Instruction::i32_and() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_and())
}

///|
pub fn Instruction::i32_atomic_load(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_atomic_load(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i32_atomic_load16_u(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_atomic_load16_u(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i32_atomic_load8_u(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_atomic_load8_u(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i32_atomic_store(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_atomic_store(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i32_atomic_store16(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_atomic_store16(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i32_atomic_store8(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_atomic_store8(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i32_clz() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_clz())
}

///|
pub fn Instruction::i32_const(
  p0 : I32
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_const(core_ir_i32_get(p0)))
}

///|
pub fn Instruction::i32_ctz() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_ctz())
}

///|
pub fn Instruction::i32_div_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_div_s())
}

///|
pub fn Instruction::i32_div_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_div_u())
}

///|
pub fn Instruction::i32_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_eq())
}

///|
pub fn Instruction::i32_eqz() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_eqz())
}

///|
pub fn Instruction::i32_extend16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_extend16s())
}

///|
pub fn Instruction::i32_extend8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_extend8s())
}

///|
pub fn Instruction::i32_ge_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_ge_s())
}

///|
pub fn Instruction::i32_ge_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_ge_u())
}

///|
pub fn Instruction::i32_gt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_gt_s())
}

///|
pub fn Instruction::i32_gt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_gt_u())
}

///|
pub fn Instruction::i32_le_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_le_s())
}

///|
pub fn Instruction::i32_le_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_le_u())
}

///|
pub fn Instruction::i32_load(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_load(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_load16s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_load16s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_load16u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_load16u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_load8s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_load8s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_load8u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_load8u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_lt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_lt_s())
}

///|
pub fn Instruction::i32_lt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_lt_u())
}

///|
pub fn Instruction::i32_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_mul())
}

///|
pub fn Instruction::i32_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_ne())
}

///|
pub fn Instruction::i32_or() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_or())
}

///|
pub fn Instruction::i32_popcnt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_popcnt())
}

///|
pub fn Instruction::i32_reinterpret_f32() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_reinterpret_f32())
}

///|
pub fn Instruction::i32_rem_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_rem_s())
}

///|
pub fn Instruction::i32_rem_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_rem_u())
}

///|
pub fn Instruction::i32_rotl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_rotl())
}

///|
pub fn Instruction::i32_rotr() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_rotr())
}

///|
pub fn Instruction::i32_shl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_shl())
}

///|
pub fn Instruction::i32_shr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_shr_s())
}

///|
pub fn Instruction::i32_shr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_shr_u())
}

///|
pub fn Instruction::i32_store(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_store(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_store16(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_store16(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_store8(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_store8(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i32_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_sub())
}

///|
pub fn Instruction::i32_trunc_f32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_f32s())
}

///|
pub fn Instruction::i32_trunc_f32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_f32u())
}

///|
pub fn Instruction::i32_trunc_f64s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_f64s())
}

///|
pub fn Instruction::i32_trunc_f64u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_f64u())
}

///|
pub fn Instruction::i32_trunc_sat_f32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_sat_f32s())
}

///|
pub fn Instruction::i32_trunc_sat_f32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_sat_f32u())
}

///|
pub fn Instruction::i32_trunc_sat_f64s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_sat_f64s())
}

///|
pub fn Instruction::i32_trunc_sat_f64u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_trunc_sat_f64u())
}

///|
pub fn Instruction::i32_wrap_i64() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_wrap_i64())
}

///|
pub fn Instruction::i32_xor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32_xor())
}

///|
pub fn Instruction::i32x4_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_abs())
}

///|
pub fn Instruction::i32x4_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_add())
}

///|
pub fn Instruction::i32x4_all_true() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_all_true())
}

///|
pub fn Instruction::i32x4_bitmask() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_bitmask())
}

///|
pub fn Instruction::i32x4_dot_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_dot_i16x8s())
}

///|
pub fn Instruction::i32x4_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_eq())
}

///|
pub fn Instruction::i32x4_extadd_pairwise_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extadd_pairwise_i16x8s())
}

///|
pub fn Instruction::i32x4_extadd_pairwise_i16x8u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extadd_pairwise_i16x8u())
}

///|
pub fn Instruction::i32x4_extend_high_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extend_high_i16x8s())
}

///|
pub fn Instruction::i32x4_extend_high_i16x8u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extend_high_i16x8u())
}

///|
pub fn Instruction::i32x4_extend_low_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extend_low_i16x8s())
}

///|
pub fn Instruction::i32x4_extend_low_i16x8u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extend_low_i16x8u())
}

///|
pub fn Instruction::i32x4_extmul_high_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extmul_high_i16x8s())
}

///|
pub fn Instruction::i32x4_extmul_high_i16x8u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extmul_high_i16x8u())
}

///|
pub fn Instruction::i32x4_extmul_low_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extmul_low_i16x8s())
}

///|
pub fn Instruction::i32x4_extmul_low_i16x8u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extmul_low_i16x8u())
}

///|
pub fn Instruction::i32x4_extract_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_extract_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i32x4_ge_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_ge_s())
}

///|
pub fn Instruction::i32x4_ge_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_ge_u())
}

///|
pub fn Instruction::i32x4_gt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_gt_s())
}

///|
pub fn Instruction::i32x4_gt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_gt_u())
}

///|
pub fn Instruction::i32x4_le_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_le_s())
}

///|
pub fn Instruction::i32x4_le_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_le_u())
}

///|
pub fn Instruction::i32x4_lt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_lt_s())
}

///|
pub fn Instruction::i32x4_lt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_lt_u())
}

///|
pub fn Instruction::i32x4_max_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_max_s())
}

///|
pub fn Instruction::i32x4_max_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_max_u())
}

///|
pub fn Instruction::i32x4_min_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_min_s())
}

///|
pub fn Instruction::i32x4_min_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_min_u())
}

///|
pub fn Instruction::i32x4_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_mul())
}

///|
pub fn Instruction::i32x4_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_ne())
}

///|
pub fn Instruction::i32x4_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_neg())
}

///|
pub fn Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s())
}

///|
pub fn Instruction::i32x4_relaxed_laneselect() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_relaxed_laneselect())
}

///|
pub fn Instruction::i32x4_relaxed_trunc_f32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_relaxed_trunc_f32x4s())
}

///|
pub fn Instruction::i32x4_relaxed_trunc_f32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_relaxed_trunc_f32x4u())
}

///|
pub fn Instruction::i32x4_relaxed_trunc_zero_f64x2s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_relaxed_trunc_zero_f64x2s())
}

///|
pub fn Instruction::i32x4_relaxed_trunc_zero_f64x2u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_relaxed_trunc_zero_f64x2u())
}

///|
pub fn Instruction::i32x4_replace_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_replace_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i32x4_shl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_shl())
}

///|
pub fn Instruction::i32x4_shr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_shr_s())
}

///|
pub fn Instruction::i32x4_shr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_shr_u())
}

///|
pub fn Instruction::i32x4_splat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_splat())
}

///|
pub fn Instruction::i32x4_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_sub())
}

///|
pub fn Instruction::i32x4_trunc_sat_f32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_trunc_sat_f32x4s())
}

///|
pub fn Instruction::i32x4_trunc_sat_f32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_trunc_sat_f32x4u())
}

///|
pub fn Instruction::i32x4_trunc_sat_f64x2s_zero() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_trunc_sat_f64x2s_zero())
}

///|
pub fn Instruction::i32x4_trunc_sat_f64x2u_zero() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i32x4_trunc_sat_f64x2u_zero())
}

///|
pub fn Instruction::i64_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_add())
}

///|
pub fn Instruction::i64_and() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_and())
}

///|
pub fn Instruction::i64_atomic_load(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_load(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_load16_u(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_load16_u(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_load32_u(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_load32_u(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_load8_u(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_load8_u(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_store(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_store(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_store16(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_store16(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_store32(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_store32(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_atomic_store8(
  p0 : MemArg,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_atomic_store8(core_ir_mem_arg_get(p0), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::i64_clz() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_clz())
}

///|
pub fn Instruction::i64_const(
  p0 : I64
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_const(core_ir_i64_get(p0)))
}

///|
pub fn Instruction::i64_ctz() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_ctz())
}

///|
pub fn Instruction::i64_div_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_div_s())
}

///|
pub fn Instruction::i64_div_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_div_u())
}

///|
pub fn Instruction::i64_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_eq())
}

///|
pub fn Instruction::i64_eqz() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_eqz())
}

///|
pub fn Instruction::i64_extend16s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_extend16s())
}

///|
pub fn Instruction::i64_extend32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_extend32s())
}

///|
pub fn Instruction::i64_extend8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_extend8s())
}

///|
pub fn Instruction::i64_extend_i32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_extend_i32s())
}

///|
pub fn Instruction::i64_extend_i32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_extend_i32u())
}

///|
pub fn Instruction::i64_ge_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_ge_s())
}

///|
pub fn Instruction::i64_ge_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_ge_u())
}

///|
pub fn Instruction::i64_gt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_gt_s())
}

///|
pub fn Instruction::i64_gt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_gt_u())
}

///|
pub fn Instruction::i64_le_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_le_s())
}

///|
pub fn Instruction::i64_le_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_le_u())
}

///|
pub fn Instruction::i64_load(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_load16s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load16s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_load16u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load16u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_load32s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load32s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_load32u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load32u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_load8s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load8s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_load8u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_load8u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_lt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_lt_s())
}

///|
pub fn Instruction::i64_lt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_lt_u())
}

///|
pub fn Instruction::i64_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_mul())
}

///|
pub fn Instruction::i64_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_ne())
}

///|
pub fn Instruction::i64_or() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_or())
}

///|
pub fn Instruction::i64_popcnt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_popcnt())
}

///|
pub fn Instruction::i64_reinterpret_f64() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_reinterpret_f64())
}

///|
pub fn Instruction::i64_rem_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_rem_s())
}

///|
pub fn Instruction::i64_rem_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_rem_u())
}

///|
pub fn Instruction::i64_rotl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_rotl())
}

///|
pub fn Instruction::i64_rotr() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_rotr())
}

///|
pub fn Instruction::i64_shl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_shl())
}

///|
pub fn Instruction::i64_shr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_shr_s())
}

///|
pub fn Instruction::i64_shr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_shr_u())
}

///|
pub fn Instruction::i64_store(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_store(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_store16(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_store16(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_store32(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_store32(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_store8(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_store8(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::i64_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_sub())
}

///|
pub fn Instruction::i64_trunc_f32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_f32s())
}

///|
pub fn Instruction::i64_trunc_f32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_f32u())
}

///|
pub fn Instruction::i64_trunc_f64s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_f64s())
}

///|
pub fn Instruction::i64_trunc_f64u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_f64u())
}

///|
pub fn Instruction::i64_trunc_sat_f32s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_sat_f32s())
}

///|
pub fn Instruction::i64_trunc_sat_f32u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_sat_f32u())
}

///|
pub fn Instruction::i64_trunc_sat_f64s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_sat_f64s())
}

///|
pub fn Instruction::i64_trunc_sat_f64u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_trunc_sat_f64u())
}

///|
pub fn Instruction::i64_xor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64_xor())
}

///|
pub fn Instruction::i64x2_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_abs())
}

///|
pub fn Instruction::i64x2_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_add())
}

///|
pub fn Instruction::i64x2_all_true() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_all_true())
}

///|
pub fn Instruction::i64x2_bitmask() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_bitmask())
}

///|
pub fn Instruction::i64x2_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_eq())
}

///|
pub fn Instruction::i64x2_extend_high_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extend_high_i32x4s())
}

///|
pub fn Instruction::i64x2_extend_high_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extend_high_i32x4u())
}

///|
pub fn Instruction::i64x2_extend_low_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extend_low_i32x4s())
}

///|
pub fn Instruction::i64x2_extend_low_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extend_low_i32x4u())
}

///|
pub fn Instruction::i64x2_extmul_high_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extmul_high_i32x4s())
}

///|
pub fn Instruction::i64x2_extmul_high_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extmul_high_i32x4u())
}

///|
pub fn Instruction::i64x2_extmul_low_i32x4s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extmul_low_i32x4s())
}

///|
pub fn Instruction::i64x2_extmul_low_i32x4u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extmul_low_i32x4u())
}

///|
pub fn Instruction::i64x2_extract_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_extract_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i64x2_ge_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_ge_s())
}

///|
pub fn Instruction::i64x2_gt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_gt_s())
}

///|
pub fn Instruction::i64x2_le_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_le_s())
}

///|
pub fn Instruction::i64x2_lt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_lt_s())
}

///|
pub fn Instruction::i64x2_mul() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_mul())
}

///|
pub fn Instruction::i64x2_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_ne())
}

///|
pub fn Instruction::i64x2_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_neg())
}

///|
pub fn Instruction::i64x2_relaxed_laneselect() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_relaxed_laneselect())
}

///|
pub fn Instruction::i64x2_replace_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_replace_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i64x2_shl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_shl())
}

///|
pub fn Instruction::i64x2_shr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_shr_s())
}

///|
pub fn Instruction::i64x2_shr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_shr_u())
}

///|
pub fn Instruction::i64x2_splat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_splat())
}

///|
pub fn Instruction::i64x2_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i64x2_sub())
}

///|
pub fn Instruction::i8x16_abs() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_abs())
}

///|
pub fn Instruction::i8x16_add() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_add())
}

///|
pub fn Instruction::i8x16_add_sat_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_add_sat_s())
}

///|
pub fn Instruction::i8x16_add_sat_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_add_sat_u())
}

///|
pub fn Instruction::i8x16_all_true() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_all_true())
}

///|
pub fn Instruction::i8x16_avgr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_avgr_u())
}

///|
pub fn Instruction::i8x16_bitmask() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_bitmask())
}

///|
pub fn Instruction::i8x16_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_eq())
}

///|
pub fn Instruction::i8x16_extract_lane_s(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_extract_lane_s(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i8x16_extract_lane_u(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_extract_lane_u(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i8x16_ge_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_ge_s())
}

///|
pub fn Instruction::i8x16_ge_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_ge_u())
}

///|
pub fn Instruction::i8x16_gt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_gt_s())
}

///|
pub fn Instruction::i8x16_gt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_gt_u())
}

///|
pub fn Instruction::i8x16_le_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_le_s())
}

///|
pub fn Instruction::i8x16_le_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_le_u())
}

///|
pub fn Instruction::i8x16_lt_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_lt_s())
}

///|
pub fn Instruction::i8x16_lt_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_lt_u())
}

///|
pub fn Instruction::i8x16_max_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_max_s())
}

///|
pub fn Instruction::i8x16_max_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_max_u())
}

///|
pub fn Instruction::i8x16_min_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_min_s())
}

///|
pub fn Instruction::i8x16_min_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_min_u())
}

///|
pub fn Instruction::i8x16_narrow_i16x8s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_narrow_i16x8s())
}

///|
pub fn Instruction::i8x16_narrow_i16x8u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_narrow_i16x8u())
}

///|
pub fn Instruction::i8x16_ne() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_ne())
}

///|
pub fn Instruction::i8x16_neg() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_neg())
}

///|
pub fn Instruction::i8x16_popcnt() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_popcnt())
}

///|
pub fn Instruction::i8x16_relaxed_laneselect() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_relaxed_laneselect())
}

///|
pub fn Instruction::i8x16_relaxed_swizzle() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_relaxed_swizzle())
}

///|
pub fn Instruction::i8x16_replace_lane(
  p0 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_replace_lane(core_ir_lane_idx_get(p0)))
}

///|
pub fn Instruction::i8x16_shl() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_shl())
}

///|
pub fn Instruction::i8x16_shr_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_shr_s())
}

///|
pub fn Instruction::i8x16_shr_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_shr_u())
}

///|
pub fn Instruction::i8x16_shuffle(
  p0 : LaneIdx,
  p1 : LaneIdx,
  p2 : LaneIdx,
  p3 : LaneIdx,
  p4 : LaneIdx,
  p5 : LaneIdx,
  p6 : LaneIdx,
  p7 : LaneIdx,
  p8 : LaneIdx,
  p9 : LaneIdx,
  p10 : LaneIdx,
  p11 : LaneIdx,
  p12 : LaneIdx,
  p13 : LaneIdx,
  p14 : LaneIdx,
  p15 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_shuffle(core_ir_lane_idx_get(p0), core_ir_lane_idx_get(p1), core_ir_lane_idx_get(p2), core_ir_lane_idx_get(p3), core_ir_lane_idx_get(p4), core_ir_lane_idx_get(p5), core_ir_lane_idx_get(p6), core_ir_lane_idx_get(p7), core_ir_lane_idx_get(p8), core_ir_lane_idx_get(p9), core_ir_lane_idx_get(p10), core_ir_lane_idx_get(p11), core_ir_lane_idx_get(p12), core_ir_lane_idx_get(p13), core_ir_lane_idx_get(p14), core_ir_lane_idx_get(p15)))
}

///|
pub fn Instruction::i8x16_splat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_splat())
}

///|
pub fn Instruction::i8x16_sub() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_sub())
}

///|
pub fn Instruction::i8x16_sub_sat_s() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_sub_sat_s())
}

///|
pub fn Instruction::i8x16_sub_sat_u() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_sub_sat_u())
}

///|
pub fn Instruction::i8x16_swizzle() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::i8x16_swizzle())
}

///|
pub fn Instruction::if_(
  p0 : BlockType,
  p1 : Array[Instruction],
  p2 : Array[Instruction]?
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::if_(core_ir_block_type_get(p0), core_ir_instruction_array(p1), match p2 {
    Some(value) => Some(core_ir_instruction_array(value))
    None => None
  }))
}

///|
pub fn Instruction::local_get(
  p0 : LocalIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::local_get(core_ir_local_idx_get(p0)))
}

///|
pub fn Instruction::local_set(
  p0 : LocalIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::local_set(core_ir_local_idx_get(p0)))
}

///|
pub fn Instruction::local_tee(
  p0 : LocalIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::local_tee(core_ir_local_idx_get(p0)))
}

///|
pub fn Instruction::loop_(
  p0 : BlockType,
  p1 : Expr
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::loop_(core_ir_block_type_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn Instruction::memory_atomic_notify(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_atomic_notify(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::memory_atomic_wait32(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_atomic_wait32(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::memory_atomic_wait64(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_atomic_wait64(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::memory_copy(
  p0 : MemIdx,
  p1 : MemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_copy(core_ir_mem_idx_get(p0), core_ir_mem_idx_get(p1)))
}

///|
pub fn Instruction::memory_fill(
  p0 : MemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_fill(core_ir_mem_idx_get(p0)))
}

///|
pub fn Instruction::memory_grow(
  p0 : MemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_grow(core_ir_mem_idx_get(p0)))
}

///|
pub fn Instruction::memory_init(
  p0 : DataIdx,
  p1 : MemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_init(core_ir_data_idx_get(p0), core_ir_mem_idx_get(p1)))
}

///|
pub fn Instruction::memory_size(
  p0 : MemIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::memory_size(core_ir_mem_idx_get(p0)))
}

///|
pub fn Instruction::nop() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::nop())
}

///|
pub fn Instruction::ref_as_non_null() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_as_non_null())
}

///|
pub fn Instruction::ref_cast(
  p0 : Bool,
  p1 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_cast(p0, core_ir_heap_type_get(p1)))
}

///|
pub fn Instruction::ref_cast_desc_eq(
  p0 : Bool,
  p1 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_cast_desc_eq(p0, core_ir_heap_type_get(p1)))
}

///|
pub fn Instruction::ref_cast_desc_eq_type(
  p0 : RefType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_cast_desc_eq_type(core_ir_ref_type_get(p0)))
}

///|
pub fn Instruction::ref_cast_exact(
  p0 : Bool,
  p1 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_cast_exact(p0, core_ir_heap_type_get(p1)))
}

///|
pub fn Instruction::ref_cast_type(
  p0 : RefType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_cast_type(core_ir_ref_type_get(p0)))
}

///|
pub fn Instruction::ref_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_eq())
}

///|
pub fn Instruction::ref_func(
  p0 : FuncIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_func(core_ir_func_idx_get(p0)))
}

///|
pub fn Instruction::ref_get_desc(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_get_desc(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::ref_i31() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_i31())
}

///|
pub fn Instruction::ref_is_null() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_is_null())
}

///|
pub fn Instruction::ref_null(
  p0 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_null(core_ir_heap_type_get(p0)))
}

///|
pub fn Instruction::ref_null_type(
  p0 : RefType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_null_type(core_ir_ref_type_get(p0)))
}

///|
pub fn Instruction::ref_test(
  p0 : Bool,
  p1 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_test(p0, core_ir_heap_type_get(p1)))
}

///|
pub fn Instruction::ref_test_desc(
  p0 : Bool,
  p1 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_test_desc(p0, core_ir_heap_type_get(p1)))
}

///|
pub fn Instruction::ref_test_exact(
  p0 : Bool,
  p1 : HeapType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_test_exact(p0, core_ir_heap_type_get(p1)))
}

///|
pub fn Instruction::ref_test_type(
  p0 : RefType
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::ref_test_type(core_ir_ref_type_get(p0)))
}

///|
pub fn Instruction::resume_(
  p0 : TypeIdx,
  p1 : Array[ResumeHandler]
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::resume_(core_ir_type_idx_get(p0), core_ir_resume_handler_array(p1)))
}

///|
pub fn Instruction::resume_throw(
  p0 : TypeIdx,
  p1 : TagIdx,
  p2 : Array[ResumeHandler]
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::resume_throw(core_ir_type_idx_get(p0), core_ir_tag_idx_get(p1), core_ir_resume_handler_array(p2)))
}

///|
pub fn Instruction::resume_throw_ref(
  p0 : TypeIdx,
  p1 : Array[ResumeHandler]
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::resume_throw_ref(core_ir_type_idx_get(p0), core_ir_resume_handler_array(p1)))
}

///|
pub fn Instruction::rethrow(
  p0 : LabelIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::rethrow(core_ir_label_idx_get(p0)))
}

///|
pub fn Instruction::return_() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::return_())
}

///|
pub fn Instruction::return_call(
  p0 : FuncIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::return_call(core_ir_func_idx_get(p0)))
}

///|
pub fn Instruction::return_call_indirect(
  p0 : TypeIdx,
  p1 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::return_call_indirect(core_ir_type_idx_get(p0), core_ir_table_idx_get(p1)))
}

///|
pub fn Instruction::return_call_ref(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::return_call_ref(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::select(
  types : Array[ValType]?
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::select(types=match types {
    Some(value) => Some(core_ir_val_type_array(value))
    None => None
  }))
}

///|
pub fn Instruction::stack_switch(
  p0 : TypeIdx,
  p1 : TagIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::stack_switch(core_ir_type_idx_get(p0), core_ir_tag_idx_get(p1)))
}

///|
pub fn Instruction::string_as_wtf16() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_as_wtf16())
}

///|
pub fn Instruction::string_concat() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_concat())
}

///|
pub fn Instruction::string_const(
  p0 : FixedArray[Byte]
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_const(core_ir_bytes(p0)))
}

///|
pub fn Instruction::string_encode_lossy_utf8_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_encode_lossy_utf8_array())
}

///|
pub fn Instruction::string_encode_utf8_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_encode_utf8_array())
}

///|
pub fn Instruction::string_encode_wtf16_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_encode_wtf16_array())
}

///|
pub fn Instruction::string_encode_wtf8_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_encode_wtf8_array())
}

///|
pub fn Instruction::string_eq() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_eq())
}

///|
pub fn Instruction::string_measure_wtf16() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_measure_wtf16())
}

///|
pub fn Instruction::string_new_lossy_utf8_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_new_lossy_utf8_array())
}

///|
pub fn Instruction::string_new_utf8_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_new_utf8_array())
}

///|
pub fn Instruction::string_new_wtf16_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_new_wtf16_array())
}

///|
pub fn Instruction::string_new_wtf8_array() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::string_new_wtf8_array())
}

///|
pub fn Instruction::stringview_wtf16_get_codeunit() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::stringview_wtf16_get_codeunit())
}

///|
pub fn Instruction::stringview_wtf16_slice() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::stringview_wtf16_slice())
}

///|
pub fn Instruction::struct_atomic_cmpxchg(
  p0 : TypeIdx,
  p1 : U32Ir,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_atomic_cmpxchg(core_ir_type_idx_get(p0), core_ir_u32_get(p1), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::struct_atomic_get(
  p0 : AtomicOrder,
  p1 : TypeIdx,
  p2 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_atomic_get(core_ir_atomic_order_get(p0), core_ir_type_idx_get(p1), core_ir_u32_get(p2)))
}

///|
pub fn Instruction::struct_atomic_get_s(
  p0 : AtomicOrder,
  p1 : TypeIdx,
  p2 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_atomic_get_s(core_ir_atomic_order_get(p0), core_ir_type_idx_get(p1), core_ir_u32_get(p2)))
}

///|
pub fn Instruction::struct_atomic_get_u(
  p0 : AtomicOrder,
  p1 : TypeIdx,
  p2 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_atomic_get_u(core_ir_atomic_order_get(p0), core_ir_type_idx_get(p1), core_ir_u32_get(p2)))
}

///|
pub fn Instruction::struct_atomic_rmw(
  p0 : AggregateAtomicRmwOp,
  p1 : TypeIdx,
  p2 : U32Ir,
  order : AtomicOrder
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_atomic_rmw(core_ir_aggregate_atomic_rmw_op_get(p0), core_ir_type_idx_get(p1), core_ir_u32_get(p2), order=core_ir_atomic_order_get(order)))
}

///|
pub fn Instruction::struct_get(
  p0 : TypeIdx,
  p1 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_get(core_ir_type_idx_get(p0), core_ir_u32_get(p1)))
}

///|
pub fn Instruction::struct_get_s(
  p0 : TypeIdx,
  p1 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_get_s(core_ir_type_idx_get(p0), core_ir_u32_get(p1)))
}

///|
pub fn Instruction::struct_get_u(
  p0 : TypeIdx,
  p1 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_get_u(core_ir_type_idx_get(p0), core_ir_u32_get(p1)))
}

///|
pub fn Instruction::struct_new(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_new(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::struct_new_default(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_new_default(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::struct_new_default_desc(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_new_default_desc(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::struct_new_desc(
  p0 : TypeIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_new_desc(core_ir_type_idx_get(p0)))
}

///|
pub fn Instruction::struct_set(
  p0 : TypeIdx,
  p1 : U32Ir
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::struct_set(core_ir_type_idx_get(p0), core_ir_u32_get(p1)))
}

///|
pub fn Instruction::suspend(
  p0 : TagIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::suspend(core_ir_tag_idx_get(p0)))
}

///|
pub fn Instruction::table_copy(
  p0 : TableIdx,
  p1 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_copy(core_ir_table_idx_get(p0), core_ir_table_idx_get(p1)))
}

///|
pub fn Instruction::table_fill(
  p0 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_fill(core_ir_table_idx_get(p0)))
}

///|
pub fn Instruction::table_get(
  p0 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_get(core_ir_table_idx_get(p0)))
}

///|
pub fn Instruction::table_grow(
  p0 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_grow(core_ir_table_idx_get(p0)))
}

///|
pub fn Instruction::table_init(
  p0 : ElemIdx,
  p1 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_init(core_ir_elem_idx_get(p0), core_ir_table_idx_get(p1)))
}

///|
pub fn Instruction::table_set(
  p0 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_set(core_ir_table_idx_get(p0)))
}

///|
pub fn Instruction::table_size(
  p0 : TableIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::table_size(core_ir_table_idx_get(p0)))
}

///|
pub fn Instruction::throw_(
  p0 : TagIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::throw_(core_ir_tag_idx_get(p0)))
}

///|
pub fn Instruction::throw_ref() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::throw_ref())
}

///|
pub fn Instruction::try_(
  p0 : BlockType,
  p1 : Expr,
  p2 : Array[LegacyCatch],
  delegate : LabelIdx?
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::try_(core_ir_block_type_get(p0), core_ir_expr_get(p1), core_ir_legacy_catch_array(p2), delegate=core_ir_label_idx_option(delegate)))
}

///|
pub fn Instruction::try_table(
  p0 : BlockType,
  p1 : Array[Catch],
  p2 : Expr
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::try_table(core_ir_block_type_get(p0), core_ir_catch_array(p1), core_ir_expr_get(p2)))
}

///|
pub fn Instruction::unreachable_() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::unreachable_())
}

///|
pub fn Instruction::v128_and() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_and())
}

///|
pub fn Instruction::v128_andnot() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_andnot())
}

///|
pub fn Instruction::v128_any_true() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_any_true())
}

///|
pub fn Instruction::v128_bitselect() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_bitselect())
}

///|
pub fn Instruction::v128_const(
  p0 : Byte,
  p1 : Byte,
  p2 : Byte,
  p3 : Byte,
  p4 : Byte,
  p5 : Byte,
  p6 : Byte,
  p7 : Byte,
  p8 : Byte,
  p9 : Byte,
  p10 : Byte,
  p11 : Byte,
  p12 : Byte,
  p13 : Byte,
  p14 : Byte,
  p15 : Byte
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_const(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15))
}

///|
pub fn Instruction::v128_load(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load16_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load16_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_load16_splat(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load16_splat(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load16x4s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load16x4s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load16x4u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load16x4u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load32_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load32_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_load32_splat(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load32_splat(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load32_zero(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load32_zero(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load32x2s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load32x2s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load32x2u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load32x2u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load64_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load64_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_load64_splat(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load64_splat(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load64_zero(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load64_zero(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load8_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load8_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_load8_splat(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load8_splat(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load8x8s(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load8x8s(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_load8x8u(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_load8x8u(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_not() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_not())
}

///|
pub fn Instruction::v128_or() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_or())
}

///|
pub fn Instruction::v128_store(
  p0 : MemArg
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_store(core_ir_mem_arg_get(p0)))
}

///|
pub fn Instruction::v128_store16_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_store16_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_store32_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_store32_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_store64_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_store64_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_store8_lane(
  p0 : MemArg,
  p1 : LaneIdx
) -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_store8_lane(core_ir_mem_arg_get(p0), core_ir_lane_idx_get(p1)))
}

///|
pub fn Instruction::v128_xor() -> Instruction {
  core_ir_instruction_store(@lib.Instruction::v128_xor())
}

///|
pub fn LabelIdx::create(
  p0 : UInt
) -> LabelIdx {
  core_ir_label_idx_store(@lib.LabelIdx::new(p0))
}

///|
pub fn LaneIdx::create(
  p0 : Byte
) -> LaneIdx {
  core_ir_lane_idx_store(@lib.LaneIdx::new(p0))
}

///|
pub fn LegacyCatch::all(
  p0 : Expr
) -> LegacyCatch {
  core_ir_legacy_catch_store(@lib.LegacyCatch::all(core_ir_expr_get(p0)))
}

///|
pub fn LegacyCatch::tagged(
  p0 : TagIdx,
  p1 : Expr
) -> LegacyCatch {
  core_ir_legacy_catch_store(@lib.LegacyCatch::tagged(core_ir_tag_idx_get(p0), core_ir_expr_get(p1)))
}

///|
pub fn Limits::i32(
  p0 : UInt,
  p1 : UInt?
) -> Limits {
  core_ir_limits_store(@lib.Limits::i32(p0, p1))
}

///|
pub fn Limits::i64(
  p0 : UInt64,
  p1 : UInt64?
) -> Limits {
  core_ir_limits_store(@lib.Limits::i64(p0, p1))
}

///|
pub fn LoadOp::f32_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::f32_load())
}

///|
pub fn LoadOp::f64_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::f64_load())
}

///|
pub fn LoadOp::i32_atomic_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_atomic_load())
}

///|
pub fn LoadOp::i32_atomic_load16_u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_atomic_load16_u())
}

///|
pub fn LoadOp::i32_atomic_load8_u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_atomic_load8_u())
}

///|
pub fn LoadOp::i32_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_load())
}

///|
pub fn LoadOp::i32_load16s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_load16s())
}

///|
pub fn LoadOp::i32_load16u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_load16u())
}

///|
pub fn LoadOp::i32_load8s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_load8s())
}

///|
pub fn LoadOp::i32_load8u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i32_load8u())
}

///|
pub fn LoadOp::i64_atomic_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_atomic_load())
}

///|
pub fn LoadOp::i64_atomic_load16_u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_atomic_load16_u())
}

///|
pub fn LoadOp::i64_atomic_load32_u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_atomic_load32_u())
}

///|
pub fn LoadOp::i64_atomic_load8_u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_atomic_load8_u())
}

///|
pub fn LoadOp::i64_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load())
}

///|
pub fn LoadOp::i64_load16s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load16s())
}

///|
pub fn LoadOp::i64_load16u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load16u())
}

///|
pub fn LoadOp::i64_load32s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load32s())
}

///|
pub fn LoadOp::i64_load32u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load32u())
}

///|
pub fn LoadOp::i64_load8s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load8s())
}

///|
pub fn LoadOp::i64_load8u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::i64_load8u())
}

///|
pub fn LoadOp::v128_load() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load())
}

///|
pub fn LoadOp::v128_load16_splat() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load16_splat())
}

///|
pub fn LoadOp::v128_load16x4s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load16x4s())
}

///|
pub fn LoadOp::v128_load16x4u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load16x4u())
}

///|
pub fn LoadOp::v128_load32_splat() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load32_splat())
}

///|
pub fn LoadOp::v128_load32_zero() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load32_zero())
}

///|
pub fn LoadOp::v128_load32x2s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load32x2s())
}

///|
pub fn LoadOp::v128_load32x2u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load32x2u())
}

///|
pub fn LoadOp::v128_load64_splat() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load64_splat())
}

///|
pub fn LoadOp::v128_load64_zero() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load64_zero())
}

///|
pub fn LoadOp::v128_load8_splat() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load8_splat())
}

///|
pub fn LoadOp::v128_load8x8s() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load8x8s())
}

///|
pub fn LoadOp::v128_load8x8u() -> LoadOp {
  core_ir_load_op_store(@lib.LoadOp::v128_load8x8u())
}

///|
pub fn LocalIdx::create(
  p0 : UInt
) -> LocalIdx {
  core_ir_local_idx_store(@lib.LocalIdx::new(p0))
}

///|
pub fn LocalRun::create(
  p0 : UInt,
  p1 : ValType
) -> LocalRun {
  core_ir_local_run_store(@lib.LocalRun::new(p0, core_ir_val_type_get(p1)))
}

///|
pub fn Locals::copy(
  p0 : Locals
) -> Locals {
  core_ir_locals_store(@lib.Locals::copy(core_ir_locals_get(p0)))
}

///|
pub fn Locals::empty() -> Locals {
  core_ir_locals_store(@lib.Locals::empty())
}

///|
pub fn Locals::from_decl_runs_preserving_groups(
  p0 : Array[LocalRun]
) -> Locals {
  core_ir_locals_store(@lib.Locals::from_decl_runs_preserving_groups(core_ir_local_run_array(p0)))
}

///|
pub fn Locals::from_types(
  p0 : Array[ValType]
) -> Locals {
  core_ir_locals_store(@lib.Locals::from_types(core_ir_val_type_array(p0)))
}

///|
pub fn Locals::create(
  p0 : Array[LocalRun]
) -> Locals {
  core_ir_locals_store(@lib.Locals::new(core_ir_local_run_array(p0)))
}

///|
pub fn Locals::single(
  p0 : UInt,
  p1 : ValType
) -> Locals {
  core_ir_locals_store(@lib.Locals::single(p0, core_ir_val_type_get(p1)))
}

///|
pub fn Locals::without_prefix(
  p0 : Locals,
  p1 : Int
) -> Locals {
  core_ir_locals_store(@lib.Locals::without_prefix(core_ir_locals_get(p0), p1))
}

///|
pub fn MemArg::create(
  p0 : U32Ir,
  p1 : MemIdx?,
  p2 : U64Ir
) -> MemArg {
  core_ir_mem_arg_store(@lib.MemArg::new(core_ir_u32_get(p0), core_ir_mem_idx_option(p1), core_ir_u64_get(p2)))
}

///|
pub fn MemIdx::create(
  p0 : UInt
) -> MemIdx {
  core_ir_mem_idx_store(@lib.MemIdx::new(p0))
}

///|
pub fn MemSec::create(
  p0 : Array[MemType]
) -> MemSec {
  core_ir_mem_sec_store(@lib.MemSec::new(core_ir_mem_type_array(p0)))
}

///|
pub fn MemType::create(
  p0 : Limits,
  shared : Bool
) -> MemType {
  core_ir_mem_type_store(@lib.MemType::new(core_ir_limits_get(p0), shared=shared))
}

///|
pub fn Module::create(
  custom_secs : Array[CustomSec],
  type_sec : TypeSec?,
  import_sec : ImportSec?,
  func_annotation_sec : FuncAnnotationSec?,
  func_sec : FuncSec?,
  table_sec : TableSec?,
  mem_sec : MemSec?,
  tag_sec : TagSec?,
  stringrefs_sec : StringRefsSec?,
  global_sec : GlobalSec?,
  export_sec : ExportSec?,
  start_sec : StartSec?,
  elem_sec : ElemSec?,
  data_cnt_sec : DataCntSec?,
  code_sec : CodeSec?,
  data_sec : DataSec?,
  name_sec : NameSec?,
  raw_name_sec_payload : FixedArray[Byte]?
) -> Module {
  core_ir_module_store(@lib.Module::new(custom_secs=core_ir_custom_sec_array(custom_secs), type_sec=core_ir_type_sec_option(type_sec), import_sec=core_ir_import_sec_option(import_sec), func_annotation_sec=core_ir_func_annotation_sec_option(func_annotation_sec), func_sec=core_ir_func_sec_option(func_sec), table_sec=core_ir_table_sec_option(table_sec), mem_sec=core_ir_mem_sec_option(mem_sec), tag_sec=core_ir_tag_sec_option(tag_sec), stringrefs_sec=core_ir_string_refs_sec_option(stringrefs_sec), global_sec=core_ir_global_sec_option(global_sec), export_sec=core_ir_export_sec_option(export_sec), start_sec=core_ir_start_sec_option(start_sec), elem_sec=core_ir_elem_sec_option(elem_sec), data_cnt_sec=core_ir_data_cnt_sec_option(data_cnt_sec), code_sec=core_ir_code_sec_option(code_sec), data_sec=core_ir_data_sec_option(data_sec), name_sec=core_ir_name_sec_option(name_sec), raw_name_sec_payload=core_ir_bytes_option(raw_name_sec_payload)))
}

///|
pub fn Module::with_code_sec(
  p0 : Module,
  p1 : CodeSec
) -> Module {
  core_ir_module_store(@lib.Module::with_code_sec(core_ir_module_get(p0), core_ir_code_sec_get(p1)))
}

///|
pub fn Module::with_custom_secs(
  p0 : Module,
  p1 : Array[CustomSec]
) -> Module {
  core_ir_module_store(@lib.Module::with_custom_secs(core_ir_module_get(p0), core_ir_custom_sec_array(p1)))
}

///|
pub fn Module::with_data_cnt_sec(
  p0 : Module,
  p1 : DataCntSec
) -> Module {
  core_ir_module_store(@lib.Module::with_data_cnt_sec(core_ir_module_get(p0), core_ir_data_cnt_sec_get(p1)))
}

///|
pub fn Module::with_data_sec(
  p0 : Module,
  p1 : DataSec
) -> Module {
  core_ir_module_store(@lib.Module::with_data_sec(core_ir_module_get(p0), core_ir_data_sec_get(p1)))
}

///|
pub fn Module::with_elem_sec(
  p0 : Module,
  p1 : ElemSec
) -> Module {
  core_ir_module_store(@lib.Module::with_elem_sec(core_ir_module_get(p0), core_ir_elem_sec_get(p1)))
}

///|
pub fn Module::with_export_sec(
  p0 : Module,
  p1 : ExportSec
) -> Module {
  core_ir_module_store(@lib.Module::with_export_sec(core_ir_module_get(p0), core_ir_export_sec_get(p1)))
}

///|
pub fn Module::with_func_annotation_sec(
  p0 : Module,
  p1 : FuncAnnotationSec
) -> Module {
  core_ir_module_store(@lib.Module::with_func_annotation_sec(core_ir_module_get(p0), core_ir_func_annotation_sec_get(p1)))
}

///|
pub fn Module::with_func_sec(
  p0 : Module,
  p1 : FuncSec
) -> Module {
  core_ir_module_store(@lib.Module::with_func_sec(core_ir_module_get(p0), core_ir_func_sec_get(p1)))
}

///|
pub fn Module::with_global_sec(
  p0 : Module,
  p1 : GlobalSec
) -> Module {
  core_ir_module_store(@lib.Module::with_global_sec(core_ir_module_get(p0), core_ir_global_sec_get(p1)))
}

///|
pub fn Module::with_import_sec(
  p0 : Module,
  p1 : ImportSec
) -> Module {
  core_ir_module_store(@lib.Module::with_import_sec(core_ir_module_get(p0), core_ir_import_sec_get(p1)))
}

///|
pub fn Module::with_mem_sec(
  p0 : Module,
  p1 : MemSec
) -> Module {
  core_ir_module_store(@lib.Module::with_mem_sec(core_ir_module_get(p0), core_ir_mem_sec_get(p1)))
}

///|
pub fn Module::with_name_sec(
  p0 : Module,
  p1 : NameSec
) -> Module {
  core_ir_module_store(@lib.Module::with_name_sec(core_ir_module_get(p0), core_ir_name_sec_get(p1)))
}

///|
pub fn Module::with_raw_name_sec_payload(
  p0 : Module,
  p1 : FixedArray[Byte]
) -> Module {
  core_ir_module_store(@lib.Module::with_raw_name_sec_payload(core_ir_module_get(p0), core_ir_bytes(p1)))
}

///|
pub fn Module::with_start_sec(
  p0 : Module,
  p1 : StartSec
) -> Module {
  core_ir_module_store(@lib.Module::with_start_sec(core_ir_module_get(p0), core_ir_start_sec_get(p1)))
}

///|
pub fn Module::with_stringrefs_sec(
  p0 : Module,
  p1 : StringRefsSec
) -> Module {
  core_ir_module_store(@lib.Module::with_stringrefs_sec(core_ir_module_get(p0), core_ir_string_refs_sec_get(p1)))
}

///|
pub fn Module::with_table_sec(
  p0 : Module,
  p1 : TableSec
) -> Module {
  core_ir_module_store(@lib.Module::with_table_sec(core_ir_module_get(p0), core_ir_table_sec_get(p1)))
}

///|
pub fn Module::with_tag_sec(
  p0 : Module,
  p1 : TagSec
) -> Module {
  core_ir_module_store(@lib.Module::with_tag_sec(core_ir_module_get(p0), core_ir_tag_sec_get(p1)))
}

///|
pub fn Module::with_type_sec(
  p0 : Module,
  p1 : TypeSec
) -> Module {
  core_ir_module_store(@lib.Module::with_type_sec(core_ir_module_get(p0), core_ir_type_sec_get(p1)))
}

///|
pub fn Module::without_name_sec(
  p0 : Module
) -> Module {
  core_ir_module_store(@lib.Module::without_name_sec(core_ir_module_get(p0)))
}

///|
pub fn Mut::const_() -> Mut {
  core_ir_mut_store(@lib.Mut::const_())
}

///|
pub fn Mut::var_() -> Mut {
  core_ir_mut_store(@lib.Mut::var_())
}

///|
pub fn Name::from_string(
  p0 : String
) -> Name {
  core_ir_name_store(@lib.Name::from_string(p0))
}

///|
pub fn NameAssoc::create(
  p0 : UInt,
  p1 : Name
) -> NameAssoc {
  core_ir_name_assoc_store(@lib.NameAssoc::new(p0, core_ir_name_get(p1)))
}

///|
pub fn NameMap::create(
  p0 : Array[NameAssoc]
) -> NameMap {
  core_ir_name_map_store(@lib.NameMap::new(core_ir_name_assoc_array(p0)))
}

///|
pub fn NameSec::create(
  module_name : Name?,
  func_names : NameMap?,
  local_names : IndirectNameMap?,
  label_names : IndirectNameMap?,
  type_names : NameMap?,
  table_names : NameMap?,
  memory_names : NameMap?,
  global_names : NameMap?,
  elem_names : NameMap?,
  data_names : NameMap?,
  field_names : IndirectNameMap?,
  tag_names : NameMap?
) -> NameSec {
  core_ir_name_sec_store(@lib.NameSec::new(module_name=core_ir_name_option(module_name), func_names=core_ir_name_map_option(func_names), local_names=core_ir_indirect_name_map_option(local_names), label_names=core_ir_indirect_name_map_option(label_names), type_names=core_ir_name_map_option(type_names), table_names=core_ir_name_map_option(table_names), memory_names=core_ir_name_map_option(memory_names), global_names=core_ir_name_map_option(global_names), elem_names=core_ir_name_map_option(elem_names), data_names=core_ir_name_map_option(data_names), field_names=core_ir_indirect_name_map_option(field_names), tag_names=core_ir_name_map_option(tag_names)))
}

///|
pub fn NumType::f32_value() -> NumType {
  core_ir_num_type_store(@lib.NumType::f32())
}

///|
pub fn NumType::f64_value() -> NumType {
  core_ir_num_type_store(@lib.NumType::f64())
}

///|
pub fn NumType::i32() -> NumType {
  core_ir_num_type_store(@lib.NumType::i32())
}

///|
pub fn NumType::i64() -> NumType {
  core_ir_num_type_store(@lib.NumType::i64())
}

///|
pub fn PackType::i16() -> PackType {
  core_ir_pack_type_store(@lib.PackType::i16())
}

///|
pub fn PackType::i8() -> PackType {
  core_ir_pack_type_store(@lib.PackType::i8())
}

///|
pub fn RecType::group(
  p0 : Array[SubType]
) -> RecType {
  core_ir_rec_type_store(@lib.RecType::group(core_ir_sub_type_array(p0)))
}

///|
pub fn RecType::create(
  p0 : SubType
) -> RecType {
  core_ir_rec_type_store(@lib.RecType::new(core_ir_sub_type_get(p0)))
}

///|
pub fn RefType::abs(
  p0 : AbsHeapType
) -> RefType {
  core_ir_ref_type_store(@lib.RefType::abs(core_ir_abs_heap_type_get(p0)))
}

///|
pub fn RefType::make_nullable(
  p0 : RefType
) -> RefType {
  core_ir_ref_type_store(@lib.RefType::make_nullable(core_ir_ref_type_get(p0)))
}

///|
pub fn RefType::create(
  p0 : Bool,
  p1 : HeapType,
  exact : Bool
) -> RefType {
  core_ir_ref_type_store(@lib.RefType::new(p0, core_ir_heap_type_get(p1), exact=exact))
}

///|
pub fn ResumeHandler::on_label(
  p0 : TagIdx,
  p1 : LabelIdx
) -> ResumeHandler {
  core_ir_resume_handler_store(@lib.ResumeHandler::on_label(core_ir_tag_idx_get(p0), core_ir_label_idx_get(p1)))
}

///|
pub fn ResumeHandler::on_switch(
  p0 : TagIdx
) -> ResumeHandler {
  core_ir_resume_handler_store(@lib.ResumeHandler::on_switch(core_ir_tag_idx_get(p0)))
}

///|
pub fn StartSec::create(
  p0 : FuncIdx
) -> StartSec {
  core_ir_start_sec_store(@lib.StartSec::new(core_ir_func_idx_get(p0)))
}

///|
pub fn StorageType::pack_type(
  p0 : PackType
) -> StorageType {
  core_ir_storage_type_store(@lib.StorageType::pack_type(core_ir_pack_type_get(p0)))
}

///|
pub fn StorageType::val_type(
  p0 : ValType
) -> StorageType {
  core_ir_storage_type_store(@lib.StorageType::val_type(core_ir_val_type_get(p0)))
}

///|
pub fn StoreOp::f32_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::f32_store())
}

///|
pub fn StoreOp::f64_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::f64_store())
}

///|
pub fn StoreOp::i32_atomic_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i32_atomic_store())
}

///|
pub fn StoreOp::i32_atomic_store16() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i32_atomic_store16())
}

///|
pub fn StoreOp::i32_atomic_store8() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i32_atomic_store8())
}

///|
pub fn StoreOp::i32_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i32_store())
}

///|
pub fn StoreOp::i32_store16() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i32_store16())
}

///|
pub fn StoreOp::i32_store8() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i32_store8())
}

///|
pub fn StoreOp::i64_atomic_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_atomic_store())
}

///|
pub fn StoreOp::i64_atomic_store16() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_atomic_store16())
}

///|
pub fn StoreOp::i64_atomic_store32() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_atomic_store32())
}

///|
pub fn StoreOp::i64_atomic_store8() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_atomic_store8())
}

///|
pub fn StoreOp::i64_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_store())
}

///|
pub fn StoreOp::i64_store16() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_store16())
}

///|
pub fn StoreOp::i64_store32() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_store32())
}

///|
pub fn StoreOp::i64_store8() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::i64_store8())
}

///|
pub fn StoreOp::v128_store() -> StoreOp {
  core_ir_store_op_store(@lib.StoreOp::v128_store())
}

///|
pub fn StringRefsSec::create(
  p0 : Array[FixedArray[Byte]]
) -> StringRefsSec {
  core_ir_string_refs_sec_store(@lib.StringRefsSec::new(core_ir_bytes_array(p0)))
}

///|
pub fn SubType::comp_type(
  p0 : CompType,
  metadata : TypeMetadata
) -> SubType {
  core_ir_sub_type_store(@lib.SubType::comp_type(core_ir_comp_type_get(p0), metadata=core_ir_type_metadata_get(metadata)))
}

///|
pub fn SubType::create(
  p0 : Bool,
  p1 : Array[TypeIdx],
  p2 : CompType,
  metadata : TypeMetadata
) -> SubType {
  core_ir_sub_type_store(@lib.SubType::new(p0, core_ir_type_idx_array(p1), core_ir_comp_type_get(p2), metadata=core_ir_type_metadata_get(metadata)))
}

///|
pub fn Table::create(
  p0 : TableType,
  p1 : Expr?
) -> Table {
  core_ir_table_store(@lib.Table::new(core_ir_table_type_get(p0), core_ir_expr_option(p1)))
}

///|
pub fn TableIdx::create(
  p0 : UInt
) -> TableIdx {
  core_ir_table_idx_store(@lib.TableIdx::new(p0))
}

///|
pub fn TableSec::create(
  p0 : Array[Table]
) -> TableSec {
  core_ir_table_sec_store(@lib.TableSec::new(core_ir_table_array(p0)))
}

///|
pub fn TableType::create(
  p0 : RefType,
  p1 : Limits
) -> TableType {
  core_ir_table_type_store(@lib.TableType::new(core_ir_ref_type_get(p0), core_ir_limits_get(p1)))
}

///|
pub fn TagIdx::create(
  p0 : UInt
) -> TagIdx {
  core_ir_tag_idx_store(@lib.TagIdx::new(p0))
}

///|
pub fn TagSec::create(
  p0 : Array[TagType]
) -> TagSec {
  core_ir_tag_sec_store(@lib.TagSec::new(core_ir_tag_type_array(p0)))
}

///|
pub fn TagType::create(
  p0 : TypeIdx
) -> TagType {
  core_ir_tag_type_store(@lib.TagType::new(core_ir_type_idx_get(p0)))
}

///|
pub fn TypeIdx::create(
  p0 : UInt
) -> TypeIdx {
  core_ir_type_idx_store(@lib.TypeIdx::new(p0))
}

///|
pub fn TypeIdx::rec(
  p0 : UInt
) -> TypeIdx {
  core_ir_type_idx_store(@lib.TypeIdx::rec(p0))
}

///|
pub fn TypeMetadata::create(
  describes : TypeIdx?,
  descriptor : TypeIdx?,
  shared : Bool
) -> TypeMetadata {
  core_ir_type_metadata_store(@lib.TypeMetadata::new(describes=core_ir_type_idx_option(describes), descriptor=core_ir_type_idx_option(descriptor), shared=shared))
}

///|
pub fn TypeMetadata::with_shared(
  p0 : TypeMetadata,
  p1 : Bool
) -> TypeMetadata {
  core_ir_type_metadata_store(@lib.TypeMetadata::with_shared(core_ir_type_metadata_get(p0), p1))
}

///|
pub fn TypeSec::create(
  p0 : Array[RecType]
) -> TypeSec {
  core_ir_type_sec_store(@lib.TypeSec::new(core_ir_rec_type_array(p0)))
}

///|
pub fn U32Ir::create(
  p0 : UInt
) -> U32Ir {
  core_ir_u32_store(@lib.U32::new(p0))
}

///|
pub fn U64Ir::create(
  p0 : UInt64
) -> U64Ir {
  core_ir_u64_store(@lib.U64::new(p0))
}

///|
pub fn ValType::anyref() -> ValType {
  core_ir_val_type_store(@lib.ValType::anyref())
}

///|
pub fn ValType::bottom() -> ValType {
  core_ir_val_type_store(@lib.ValType::bottom())
}

///|
pub fn ValType::eqref_null() -> ValType {
  core_ir_val_type_store(@lib.ValType::eqref_null())
}

///|
pub fn ValType::externref() -> ValType {
  core_ir_val_type_store(@lib.ValType::externref())
}

///|
pub fn ValType::f32_value() -> ValType {
  core_ir_val_type_store(@lib.ValType::f32())
}

///|
pub fn ValType::f64_value() -> ValType {
  core_ir_val_type_store(@lib.ValType::f64())
}

///|
pub fn ValType::funcref() -> ValType {
  core_ir_val_type_store(@lib.ValType::funcref())
}

///|
pub fn ValType::i31ref() -> ValType {
  core_ir_val_type_store(@lib.ValType::i31ref())
}

///|
pub fn ValType::i31ref_nullable() -> ValType {
  core_ir_val_type_store(@lib.ValType::i31ref_nullable())
}

///|
pub fn ValType::i32() -> ValType {
  core_ir_val_type_store(@lib.ValType::i32())
}

///|
pub fn ValType::i64() -> ValType {
  core_ir_val_type_store(@lib.ValType::i64())
}

///|
pub fn ValType::num_type(
  p0 : NumType
) -> ValType {
  core_ir_val_type_store(@lib.ValType::num_type(core_ir_num_type_get(p0)))
}

///|
pub fn ValType::ref_array_nonnull(
  p0 : TypeIdx
) -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_array_nonnull(core_ir_type_idx_get(p0)))
}

///|
pub fn ValType::ref_array_nullable(
  p0 : TypeIdx
) -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_array_nullable(core_ir_type_idx_get(p0)))
}

///|
pub fn ValType::ref_null(
  p0 : HeapType
) -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_null(core_ir_heap_type_get(p0)))
}

///|
pub fn ValType::ref_null_array_of(
  p0 : TypeIdx
) -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_null_array_of(core_ir_type_idx_get(p0)))
}

///|
pub fn ValType::ref_null_exn() -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_null_exn())
}

///|
pub fn ValType::ref_null_type(
  p0 : RefType
) -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_null_type(core_ir_ref_type_get(p0)))
}

///|
pub fn ValType::ref_type(
  p0 : RefType
) -> ValType {
  core_ir_val_type_store(@lib.ValType::ref_type(core_ir_ref_type_get(p0)))
}

///|
pub fn ValType::stringref() -> ValType {
  core_ir_val_type_store(@lib.ValType::stringref())
}

///|
pub fn ValType::v128() -> ValType {
  core_ir_val_type_store(@lib.ValType::v128())
}

///|
pub fn empty_module() -> Module {
  core_ir_module_store(@lib.Module::new())
}

///|
pub fn decode_module(wasm : FixedArray[Byte]) -> Result[Module, Diagnostic] {
  match @binary.decode_module(core_ir_bytes(wasm)) {
    Ok(value) => Ok(core_ir_module_store(value))
    Err(err) => Err({ stage: "decode", message: "\{err}" })
  }
}

///|
pub fn parse_module(wat : String) -> Result[Module, Diagnostic] {
  match @wast.wast_to_binary_module(wat, filename="component-core-ir.wat") {
    Ok(value) => Ok(core_ir_module_store(value))
    Err(err) => Err({ stage: "parse", message: err })
  }
}

///|
pub fn encode_module(value : Module) -> Result[FixedArray[Byte], Diagnostic] {
  match @binary.encode_module(core_ir_module_get(value)) {
    Ok(bytes) => Ok(bytes.to_fixedarray())
    Err(err) => Err({ stage: "encode", message: "\{err}" })
  }
}

///|
pub fn validate_module(value : Module) -> Result[Unit, Diagnostic] {
  match @validate.validate_module(core_ir_module_get(value)) {
    Ok(_) => Ok(())
    Err(err) => Err({ stage: "validate", message: "\{err}" })
  }
}
