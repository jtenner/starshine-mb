/// Represents the possible writers to a local.get
enum LocalSet {
  InitValue              // implicit initial value
  Set(LocalIdx, TInstr)  // actual local.set
} derive(Eq, Hash)

priv struct LocalGraph {
  /// Map each local.get instruction (by id) to its possible sets
  get_sets : Map[Int, Set[LocalSet]]
}

priv struct Block {
  id : Int
  instr_ids : Array[Int]
  preds : Array[Int]
}

priv struct BlockBuilder {
  id : Int
  instr_ids : Array[Int]
}

priv struct BlockInfo {
  /// Actions in this block, in program order
  actions : Array[Action]

  /// For each local, the last local.set in this block (instr id)
  last_sets : Map[LocalIdx, Int]
}


priv enum Action {
  Get(LocalIdx, Int, Int) // local, instr_id, action_index
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
      TInstr::TIf(_, _, _, _) => {
        current.instr_ids.push(i)

        blocks.push(Block::{
          id : current.id,
          instr_ids : current.instr_ids,
          preds : preds.get(current.id).unwrap_or([]),
        })

        let parent = current.id
        let merge = new_block()

        // IMPORTANT: mark ambiguity
        preds[merge.id] = [parent, parent]

        current = merge
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

fn extract_block_info(
  block : Block,
  instrs : Array[TInstr],
) -> BlockInfo {

  let actions = Array::new()
  let last_sets = Map::new()
  let mut action_index = 0

  for instr_id in block.instr_ids {
    let instr = instrs[instr_id]

    match instr {
      TInstr::TLocalGet(idx) => {
        actions.push(Action::Get(idx, instr_id, action_index))
        action_index = action_index + 1
      }

      TInstr::TLocalSet(idx, _) => {
        actions.push(Action::Set(idx, instr_id))
        // overwrite: last set wins
        last_sets[idx] = instr_id
        action_index = action_index + 1
      }

      _ => ()
    }
  }

  BlockInfo::{
    actions : actions,
    last_sets : last_sets,
  }
}

fn flatten_instrs(instrs : Array[TInstr]) -> Array[TInstr] {
  let out = Array::new()

  for instr in instrs {
    match instr {
      TInstr::TIf(bt, cond, then_expr, else_expr) => {
        // Keep the if itself, but strip its bodies
        out.push(
          TInstr::TIf(bt, cond, TExpr::new([]), None)
        )

        // Flatten then branch
        let then_flat = flatten_instrs(then_expr.0)
        for i in then_flat {
          out.push(i)
        }

        // Flatten else branch, if present
        if else_expr is Some(e) {
          let else_flat = flatten_instrs(e.0)
          for i in else_flat {
            out.push(i)
          }
        }
      }

      _ => {
        out.push(instr)
      }
    }
  }

  out
}

fn compute_get_sets_cfg(
  blocks : Array[Block],
  instrs : Array[TInstr],
) -> Map[Int, Set[LocalSet]] {

  let block_map = Map::new()
  for b in blocks {
    block_map[b.id] = b
  }

  let infos = extract_all_block_infos(blocks, instrs)
  let result = Map::new()

  for block in blocks {
    let info = infos.get(block.id).unwrap()

    // collect gets in this block
    for action in info.actions {
      match action {
        Action::Get(idx, get_id, get_action_index) => {
          // scan backward inside block
          let mut found = false
          let mut i = get_action_index - 1
          while i >= 0 {
            match info.actions[i] {
              Action::Set(sidx, set_id) if sidx == idx => {
                let s = Set::new()
                s.add(LocalSet::Set(idx, instrs[set_id]))
                result[get_id] = s
                found = true
                break
              }
              _ => ()
            }
            i = i - 1
          }

          if !found {
            let sets = Set::new()

            if block.preds.is_empty() {
              // Entry block: implicit init value
              sets.add(LocalSet::InitValue)
            } else {
              for pred in block.preds {
                let pred_sets =
                  flow_back_from_block(
                    pred,
                    idx,
                    block_map,
                    infos,
                    instrs,
                    Set::new()
                  )
                for s in pred_sets {
                  sets.add(s)
                }
              }
            }

            result[get_id] = sets
          }
        }
        _ => ()
      }
    }
  }

  result
}

fn flow_back_from_block(
  block_id : Int,
  local_idx : LocalIdx,
  blocks : Map[Int, Block],
  infos : Map[Int, BlockInfo],
  instrs : Array[TInstr],
  visited : Set[Int],
) -> Set[LocalSet] {

  // avoid infinite loops
  if visited.contains(block_id) {
    return Set::new()
  }

  let visited = visited.copy()
  visited.add(block_id)

  let info = infos.get(block_id).unwrap()
  let block = blocks.get(block_id).unwrap()

  // If this block has a set for the local, use it and stop.
  if info.last_sets.get(local_idx) is Some(set_id) {
    let instr = instrs[set_id]
    let result = Set::new()
    result.add(LocalSet::Set(local_idx, instr))
    return result
  }

  // Otherwise, flow to predecessors
  let result = Set::new()

  if block.preds.is_empty() {
    // Entry block: implicit init value
    result.add(LocalSet::InitValue)
    return result
  }

  for pred in block.preds {
    let pred_sets =
      flow_back_from_block(pred, local_idx, blocks, infos, instrs, visited)
    for s in pred_sets {
      result.add(s)
    }
  }

  result
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

/// Create an empty LocalGraph
fn LocalGraph::new(instrs : Array[TInstr]) -> Self {
  let flat = flatten_instrs(instrs)
  let blocks = build_blocks(flat)
  let get_sets = compute_get_sets_cfg(blocks, flat)

  LocalGraph::{
    get_sets : get_sets,
  }
}

/// Assign instruction IDs to a TExpr
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
