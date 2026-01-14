/// Represents the possible writers to a local.get
enum LocalSet {
  InitValue              // implicit initial value
  Set(LocalIdx, TInstr)  // actual local.set
} derive(Eq, Hash)

struct LocalGraph {
  /// Map each local.get instruction (by id) to its possible sets
  get_sets : Map[Int, Set[LocalSet]]

  /// Maps instruction index → instruction
  instrs : Array[TInstr]

  /// Maps instruction index → basic block id
  block_of : Array[Int]

  /// Predecessor blocks
  preds : Map[Int, Array[Int]]
}

struct InstrIdAssigner {
  next : Int
  ids : Map[TInstr, Int]
}

struct Block {
  id : Int
  instr_ids : Array[Int]
  preds : Array[Int]
}

struct BlockBuilder {
  id : Int
  instr_ids : Array[Int]
}

struct BlockInfo {
  /// Actions in this block, in program order
  actions : Array[Action]

  /// For each local, the last local.set in this block (instr id)
  last_sets : Map[LocalIdx, Int]
}


enum Action {
  Get(LocalIdx, Int) // local + instr id
  Set(LocalIdx, Int)
}

fn build_blocks(
  instrs : Array[TInstr],
) -> Array[Block] {

  let blocks = Array::new()
  let preds = Map::new()

  let mut next_block_id = 0

  fn new_block() -> BlockBuilder {
    let id = next_block_id
    next_block_id = next_block_id + 1
    BlockBuilder::{ id : id, instr_ids : Array::new() }
  }

  let mut current = new_block()

  for i in 0..<instrs.length() {
    match instrs[i] {
      TInstr::TIf(_, _, then_expr, else_expr) => {
        // The if instruction stays in the current block
        current.instr_ids.push(i)

        // Finalize current block
        blocks.push(Block::{
          id : current.id,
          instr_ids : current.instr_ids,
          preds : preds.get(current.id).unwrap_or([]),
        })

        let parent_id = current.id

        // THEN block
        let then_block = new_block()
        for instr in then_expr.inner() {
          then_block.instr_ids.push(-1) // placeholder
        }

        // ELSE block (optional)
        let else_block =
          if else_expr is Some(e) {
            let b = new_block()
            for instr in e.inner() {
              b.instr_ids.push(-1)
            }
            Some(b)
          } else {
            None
          }

        // MERGE block
        let merge_block = new_block()

        // Set predecessors
        preds[then_block.id] = [parent_id]
        preds[merge_block.id] =
          match else_block {
            Some(b) => [then_block.id, b.id]
            None => [then_block.id]
          }

        if else_block is Some(b) {
          preds[b.id] = [parent_id]
        }

        // Push THEN and ELSE blocks
        blocks.push(Block::{
          id : then_block.id,
          instr_ids : then_block.instr_ids,
          preds : preds.get(then_block.id).unwrap_or([]),
        })

        if else_block is Some(b) {
          blocks.push(Block::{
            id : b.id,
            instr_ids : b.instr_ids,
            preds : preds.get(b.id).unwrap_or([]),
          })
        }

        // Continue in MERGE block
        current = merge_block
      }

      _ => {
        current.instr_ids.push(i)
      }
    }
  }

  // Final block
  blocks.push(Block::{
    id : current.id,
    instr_ids : current.instr_ids,
    preds : preds.get(current.id).unwrap_or([]),
  })

  blocks
}

fn assign_instr_ids(instrs : Array[TInstr]) -> Array[Int] {
  let ids = Array::new()
  for i in 0..<instrs.length() {
    ids.push(i)
  }
  ids
}
fn extract_actions_linear(
  instrs : Array[TInstr],
) -> Array[Action] {
  let actions = Array::new()

  for i in 0..<instrs.length() {
    match instrs[i] {
      TInstr::TLocalGet(idx) =>
        actions.push(Action::Get(idx, i))

      TInstr::TLocalSet(idx, _) =>
        actions.push(Action::Set(idx, i))

      _ => ()
    }
  }

  actions
}

fn extract_block_info(
  block : Block,
  instrs : Array[TInstr],
) -> BlockInfo {

  let actions = Array::new()
  let last_sets = Map::new()

  for instr_id in block.instr_ids {
    let instr = instrs[instr_id]

    match instr {
      TInstr::TLocalGet(idx) => {
        actions.push(Action::Get(idx, instr_id))
      }

      TInstr::TLocalSet(idx, _) => {
        actions.push(Action::Set(idx, instr_id))
        // overwrite: last set wins
        last_sets[idx] = instr_id
      }

      _ => ()
    }
  }

  BlockInfo::{
    actions : actions,
    last_sets : last_sets,
  }
}

fn extract_all_block_infos(
  blocks : Array[Block],
  instrs : Array[TInstr],
) -> Map[Int, BlockInfo] {

  let infos = Map::new()

  for block in blocks {
    infos[block.id] = extract_block_info(block, instrs)
  }

  infos
}

fn compute_get_sets_linear(
  instrs : Array[TInstr],
) -> Map[Int, Set[LocalSet]] {

  let actions = extract_actions_linear(instrs)
  let get_sets = Map::new()

  // LocalIdx → Array[Int] (pending get instr ids)
  let pending = Map::new()

  let mut i = actions.length() - 1
  while i >= 0 {
    match actions[i] {
      Action::Get(idx, get_id) => {
        let arr = pending.get(idx).unwrap_or(Array::new())
        arr.push(get_id)
        pending[idx] = arr
      }

      Action::Set(idx, set_id) => {
        let gets = pending.get(idx).unwrap_or([])
        for get_id in gets {
          let set = get_sets.get(get_id).unwrap_or(Set::new())
          set.add(LocalSet::Set(idx, instrs[set_id]))
          get_sets[get_id] = set
        }
        pending.remove(idx)
      }
    }

    i = i - 1
  }

  // Any remaining gets read InitValue
  for g in pending {
    let (_, gets) = g
    for get_id in gets {
      let set = get_sets.get(get_id).unwrap_or(Set::new())
      set.add(LocalSet::InitValue)
      get_sets[get_id] = set
    }
  }

  get_sets
}

/// Create an empty LocalGraph
fn LocalGraph::new(instrs : Array[TInstr]) -> Self {
  let get_sets = compute_get_sets_linear(instrs)

  LocalGraph::{
    get_sets : get_sets,
    instrs : instrs,
    block_of : Array::new(),
    preds : Map::new(),
  }
}

/// Assign instruction IDs to a TExpr
fn InstrIdAssigner::new() -> Self {
  InstrIdAssigner::{ next : 0, ids : Map::new() }
}

fn InstrIdAssigner::assign(
  self : Self,
  instr : TInstr,
) -> (Self, Int) {
  if self.ids.get(instr) is Some(id) {
    (self, id)
  } else {
    let id = self.next
    let ids = self.ids.copy()
    ids[instr] = id
    (
      InstrIdAssigner::{
        next : id + 1,
        ids : ids,
      },
      id,
    )
  }
}

/// Compute predecessor edges
fn compute_predecessors(
  blocks : Array[Block],
) -> Map[Int, Array[Int]] {
  // TODO: implement
  Map::new()
}

/// Extract local.get / local.set actions for a block
fn extract_actions(
  block : Block,
  instrs : Array[TInstr],
) -> Array[Action] {
  // TODO: implement
  []
}

/// Compute get_sets for all local.gets
fn compute_get_sets(
  graph : LocalGraph,
  blocks : Array[Block],
) -> LocalGraph {
  // TODO: implement
  graph
}

fn LocalGraph::get_sets(
  self : Self,
  get_id : Int,
) -> Set[LocalSet] {
  self.get_sets.get(get_id).unwrap_or(Set::new())
}

test "LocalGraph empty graph has no sets" {
  let instrs = []
  let graph = LocalGraph::new(instrs)

  let sets = graph.get_sets(0)

  assert_true(sets.is_empty())
}

test "LocalGraph: local.get with no prior set reads InitValue" {
  let x = LocalIdx::new(0)

  let instrs =
    [
      TInstr::local_get(x)
    ]

  let graph = LocalGraph::new(instrs)

  // instruction 0 is the get
  let sets = graph.get_sets(0)

  assert_eq(sets.length(), 1)
  assert_true(sets.contains(LocalSet::InitValue))
}

test "LocalGraph: local.get reads immediately preceding local.set" {
  let x = LocalIdx::new(0)

  let instrs =
    [
      TInstr::local_set(x, TInstr::i32_const(I32(42))),
      TInstr::local_get(x)
    ]

  let graph = LocalGraph::new(instrs)

  // instruction 1 is the get
  let sets = graph.get_sets(1)

  assert_eq(sets.length(), 1)

  match sets.to_array()[0] {
    LocalSet::Set(idx, _) => assert_eq(idx, x)
    _ => fail("expected concrete local.set")
  }
}

test "LocalGraph: local.get before local.set reads InitValue" {
  let x = LocalIdx::new(0)

  let instrs =
    [
      TInstr::local_get(x),
      TInstr::local_set(x, TInstr::i32_const(I32(1)))
    ]

  let graph = LocalGraph::new(instrs)

  let sets = graph.get_sets(0)

  assert_eq(sets.length(), 1)
  assert_true(sets.contains(LocalSet::InitValue))
}

test "LocalGraph: local.get reads most recent local.set" {
  let x = LocalIdx::new(0)

  let instrs =
    [
      TInstr::local_set(x, TInstr::i32_const(I32(1))),
      TInstr::local_set(x, TInstr::i32_const(I32(2))),
      TInstr::local_get(x)
    ]

  let graph = LocalGraph::new(instrs)

  let sets = graph.get_sets(2)

  assert_eq(sets.length(), 1)

  match sets.to_array()[0] {
    LocalSet::Set(_, TLocalSet(_, TI32Const(I32(2)))) => ()
    _ => fail("expected second local.set")
  }
}

test "LocalGraph: local.get after if sees multiple possible sets" {
  let x = LocalIdx::new(0)

  let then_expr =
    TExpr::new([
      TInstr::local_set(x, TInstr::i32_const(I32(1)))
    ])

  let else_expr =
    TExpr::new([
      TInstr::local_set(x, TInstr::i32_const(I32(2)))
    ])

  let instrs =
    [
      TInstr::if_(
        BlockType::empty(),
        TInstr::i32_const(I32(0)),
        then_expr,
        Some(else_expr)
      ),
      TInstr::local_get(x)
    ]

  let graph = LocalGraph::new(instrs)

  let sets = graph.get_sets(1)

  assert_eq(sets.length(), 2)
}

test "LocalGraph: locals are independent" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)

  let instrs =
    [
      TInstr::local_set(x, TInstr::i32_const(I32(1))),
      TInstr::local_get(y)
    ]

  let graph = LocalGraph::new(instrs)

  let sets = graph.get_sets(1)

  assert_eq(sets.length(), 1)
  assert_true(sets.contains(LocalSet::InitValue))
}

test "build_blocks: if creates then/else/merge blocks" {
  let x = LocalIdx::new(0)

  let instrs =
    [
      TInstr::if_(
        BlockType::empty(),
        TInstr::i32_const(I32(0)),
        TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
        Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))]))
      ),
      TInstr::local_get(x)
    ]

  let blocks = build_blocks(instrs)

  // entry, then, else, merge
  assert_eq(blocks.length(), 4)
}

test "extract_block_info: collects actions and last_sets" {
  let x = LocalIdx::new(0)

  let instrs =
    [
      TInstr::local_set(x, TInstr::i32_const(I32(1))),
      TInstr::local_get(x),
      TInstr::local_set(x, TInstr::i32_const(I32(2))),
    ]

  let block =
    Block::{
      id : 0,
      instr_ids : [0, 1, 2],
      preds : [],
    }

  let info = extract_block_info(block, instrs)

  assert_eq(info.actions.length(), 3)
  assert_eq(info.last_sets.length(), 1)

  assert_eq(info.last_sets.get(x).unwrap(), 2)
}

test "extract_block_info: ignores non-local instructions" {
  let instrs =
    [
      TInstr::i32_const(I32(1)),
      TInstr::i32_const(I32(2)),
    ]

  let block =
    Block::{
      id : 0,
      instr_ids : [0, 1],
      preds : [],
    }

  let info = extract_block_info(block, instrs)

  assert_true(info.actions.is_empty())
  assert_true(info.last_sets.is_empty())
}
