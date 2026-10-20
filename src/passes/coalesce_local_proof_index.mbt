// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.

///|
priv enum CLLocalProofControlKind {
  Block(@lib.BlockType, Int32)
  If(@lib.BlockType, Int32, Int32?)
  Barrier(@lib.Instruction)
}

///|
priv struct CLLocalProofControl {
  offset : Int32
  kind : CLLocalProofControlKind
}

///|
priv struct CLLocalProofRegion {
  instrs : Array[@lib.Instruction]
  controls : Array[CLLocalProofControl]
  base : Int32
}

///|
priv struct CLLocalProofIndex {
  regions : Array[CLLocalProofRegion]
  root : Int32
  // One compressed row per local. Positions are offsets in the concatenated
  // original regions, sorted by region then source instruction position.
  starts : Array[Int32]
  positions : Array[Int32]
  instruction_count : Int32
  control_count : Int32
}

///|
// One structured coalesce rewrite owns this cache and its immutable original
// body. Queries read original instructions and predecessor slots directly; no
// reconstructed instruction forest or mutable effect fact is retained.
priv struct CLLocalProofCache {
  mut index : CLLocalProofIndex?
  mut probes : Int32
  local_count : Int32
}

///|
fn CLLocalProofCache::new(local_count~ : Int32 = 0) -> CLLocalProofCache {
  { index: None, probes: 0, local_count, }
}

///|
fn cl_local_proof_access_local(instr : @lib.Instruction) -> Int32 {
  match instr {
    @lib.LocalGet(local) | @lib.LocalSet(local) | @lib.LocalTee(local) =>
      cl_local_idx_raw(local)
    _ => -1
  }
}

///|
fn cl_local_proof_build_region(
  instrs : Array[@lib.Instruction],
  regions : Array[CLLocalProofRegion],
) -> Int32 {
  let controls : Array[CLLocalProofControl] = []
  for offset in 0..<instrs.length() {
    let kind = match instrs[offset] {
      @lib.Block(ty, @lib.Expr(body)) =>
        Some(
          CLLocalProofControlKind::Block(
            ty,
            cl_local_proof_build_region(body, regions),
          ),
        )
      @lib.If(ty, then_body, else_body) => {
        let yes = cl_local_proof_build_region(then_body, regions)
        let no = match else_body {
          Some(body) => Some(cl_local_proof_build_region(body, regions))
          None => None
        }
        Some(CLLocalProofControlKind::If(ty, yes, no))
      }
      @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.Return
      | @lib.Loop(_, _)
      | @lib.TryTable(_, _, _) =>
        Some(CLLocalProofControlKind::Barrier(instrs[offset]))
      // Match the original proof machines' exact legacy-exception scope.
      _ => None
    }
    if kind is Some(kind) {
      controls.push({ offset, kind, })
    }
  }
  let base = if regions.is_empty() {
    0
  } else {
    let previous = regions[regions.length() - 1]
    previous.base + previous.instrs.length()
  }
  let id = regions.length()
  regions.push({ instrs, controls, base, })
  id
}

///|
fn cl_local_proof_index(
  instrs : Array[@lib.Instruction],
  local_count~ : Int32 = 0,
) -> CLLocalProofIndex {
  let regions : Array[CLLocalProofRegion] = []
  let root = cl_local_proof_build_region(instrs, regions)
  let mut locals = local_count
  if locals <= 0 {
    for region in regions {
      for instr in region.instrs {
        let local = cl_local_proof_access_local(instr)
        if local >= locals {
          locals = local + 1
        }
      }
    }
  }
  let starts = Array::make(locals + 1, 0)
  let mut control_count = 0
  for region in regions {
    control_count += region.controls.length()
    for instr in region.instrs {
      let local = cl_local_proof_access_local(instr)
      if local >= 0 && local < locals {
        starts[local + 1] += 1
      }
    }
  }
  for local in 0..<locals {
    starts[local + 1] += starts[local]
  }
  let access_count = starts[locals]
  let positions = Array::make(access_count, 0)
  // Fill backwards using row ends as cursors, then shift the resulting row
  // starts into place. Construction needs no per-access object or cursor copy.
  for id = regions.length() - 1; id >= 0; id = id - 1 {
    let region = regions[id]
    for offset = region.instrs.length() - 1; offset >= 0; offset = offset - 1 {
      let local = cl_local_proof_access_local(region.instrs[offset])
      if local >= 0 && local < locals {
        starts[local + 1] -= 1
        positions[starts[local + 1]] = region.base + offset
      }
    }
  }
  for local in 0..<locals {
    starts[local] = starts[local + 1]
  }
  starts[locals] = access_count
  let region = regions[root]
  {
    regions,
    root,
    starts,
    positions,
    instruction_count: region.base + region.instrs.length(),
    control_count,
  }
}

///|
fn CLLocalProofIndex::bound(
  self : CLLocalProofIndex,
  local : Int32,
  position : Int32,
) -> Int32 {
  if local < 0 || local + 1 >= self.starts.length() {
    return 0
  }
  let mut begin = self.starts[local]
  let mut end = self.starts[local + 1]
  while begin < end {
    let mid = begin + (end - begin) / 2
    if self.positions[mid] < position {
      begin = mid + 1
    } else {
      end = mid
    }
  }
  begin
}

///|
fn CLLocalProofIndex::access_count(
  self : CLLocalProofIndex,
  local : Int32,
) -> Int32 {
  if local < 0 || local + 1 >= self.starts.length() {
    0
  } else {
    self.starts[local + 1] - self.starts[local]
  }
}

///|
fn CLLocalProofCache::use_index(
  self : CLLocalProofCache,
  instrs : Array[@lib.Instruction],
  source : Int32,
  dest : Int32,
) -> Bool {
  if self.local_count > 0 && self.local_count <= 8 {
    return false
  }
  self.probes += 1
  if self.probes <= 2 {
    return false
  }
  let index = match self.index {
    Some(index) => index
    None => {
      let index = cl_local_proof_index(instrs, local_count=self.local_count)
      self.index = Some(index)
      index
    }
  }
  let relevant = index.access_count(source) + index.access_count(dest)
  relevant * 4 + index.control_count * 8 < index.instruction_count
}

///|
#valtype
priv struct CLSparseConsumeScan {
  ok : Bool
  saw : Bool
  clobbered : Bool
  initialized : Bool
  source_written : Bool
}

///|
fn cl_sparse_consume_failed() -> CLSparseConsumeScan {
  {
    ok: false,
    saw: false,
    clobbered: false,
    initialized: false,
    source_written: false,
  }
}

///|
fn CLLocalProofIndex::scan_consume(
  self : CLLocalProofIndex,
  region_id : Int32,
  source : Int32,
  dest : Int32,
  seen_source : Bool,
  clobbered : Bool,
  initialized : Bool,
  source_written : Bool,
) -> CLSparseConsumeScan {
  let mut seen = seen_source
  let mut may_be_clobbered = clobbered
  let mut has_source_value = initialized
  let mut source_may_have_clobbered_dest = source_written
  let mut saw = false
  let region = self.regions[region_id]
  let instrs = region.instrs
  let finish = region.base + instrs.length()
  let mut left = self.bound(source, region.base)
  let left_end = self.bound(source, finish)
  let mut right = self.bound(dest, region.base)
  let right_end = self.bound(dest, finish)
  let mut next_control = 0
  while left < left_end ||
        right < right_end ||
        next_control < region.controls.length() {
    let lp = if left < left_end {
      self.positions[left] - region.base
    } else {
      2147483647
    }
    let rp = if right < right_end {
      self.positions[right] - region.base
    } else {
      2147483647
    }
    let cp = if next_control < region.controls.length() {
      region.controls[next_control].offset
    } else {
      2147483647
    }
    let mut control = -1
    let idx = if cp <= lp && cp <= rp {
      control = next_control
      next_control += 1
      cp
    } else if lp <= rp {
      left += 1
      lp
    } else {
      right += 1
      rp
    }
    let instr = instrs[idx]
    match instr {
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        if may_be_clobbered {
          return cl_sparse_consume_failed()
        }
        if has_source_value {
          seen = true
        }
      }
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == dest =>
        if source_may_have_clobbered_dest {
          return cl_sparse_consume_failed()
        }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        if seen {
          saw = true
          may_be_clobbered = true
          seen = false
        }
        source_may_have_clobbered_dest = false
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        if seen {
          saw = true
          may_be_clobbered = true
          seen = false
        }
        source_may_have_clobbered_dest = false
      }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        may_be_clobbered = false
        has_source_value = true
        source_may_have_clobbered_dest = true
        seen = false
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == source => {
        may_be_clobbered = false
        has_source_value = true
        source_may_have_clobbered_dest = true
        seen = false
      }
      @lib.Block(_, _) => {
        let body = match region.controls[control].kind {
          CLLocalProofControlKind::Block(_, body) => body
          _ => abort("local proof block has no region index")
        }
        let scanned = self.scan_consume(
          body, source, dest, false, may_be_clobbered, has_source_value, source_may_have_clobbered_dest,
        )
        if !scanned.ok {
          return cl_sparse_consume_failed()
        }
        if scanned.saw {
          saw = true
        }
        may_be_clobbered = scanned.clobbered
        has_source_value = scanned.initialized
        source_may_have_clobbered_dest = scanned.source_written
        seen = false
      }
      @lib.If(_, _, _) => {
        let then_body = match region.controls[control].kind {
          CLLocalProofControlKind::If(_, yes, _) => yes
          _ => abort("local proof conditional has no region index")
        }
        let else_body = match region.controls[control].kind {
          CLLocalProofControlKind::If(_, _, no) => no
          _ => abort("local proof conditional has no region index")
        }
        let then_scanned = self.scan_consume(
          then_body, source, dest, false, may_be_clobbered, has_source_value, source_may_have_clobbered_dest,
        )
        if !then_scanned.ok {
          return cl_sparse_consume_failed()
        }
        let mut else_clobbered = may_be_clobbered
        let mut else_initialized = has_source_value
        let mut else_source_written = source_may_have_clobbered_dest
        let mut else_saw = false
        match else_body {
          Some(body) => {
            let else_scanned = self.scan_consume(
              body, source, dest, false, may_be_clobbered, has_source_value, source_may_have_clobbered_dest,
            )
            if !else_scanned.ok {
              return cl_sparse_consume_failed()
            }
            else_clobbered = else_scanned.clobbered
            else_initialized = else_scanned.initialized
            else_source_written = else_scanned.source_written
            else_saw = else_scanned.saw
          }
          None => ()
        }
        if then_scanned.saw || else_saw {
          saw = true
        }
        may_be_clobbered = then_scanned.clobbered || else_clobbered
        has_source_value = then_scanned.initialized && else_initialized
        source_may_have_clobbered_dest = then_scanned.source_written ||
          else_source_written
        seen = false
      }
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) | @lib.Return =>
        return cl_sparse_consume_failed()
      @lib.Loop(_, _) | @lib.TryTable(_, _, _) =>
        return cl_sparse_consume_failed()
      _ => ()
    }
  }
  ignore(seen)
  {
    ok: true,
    saw,
    clobbered: may_be_clobbered,
    initialized: has_source_value,
    source_written: source_may_have_clobbered_dest,
  }
}

///|
fn CLLocalProofIndex::scan_path(
  self : CLLocalProofIndex,
  region_id : Int32,
  source : Int32,
  dest : Int32,
  source_initialized : Bool,
  source_clobbers_dest : Bool,
  dest_clobbers_source : Bool,
) -> CLPathDisjointScan {
  let mut has_source_value = source_initialized
  let mut source_may_clobber_dest = source_clobbers_dest
  let mut dest_may_clobber_source = dest_clobbers_source
  let mut saw_source_write = false
  let region = self.regions[region_id]
  let instrs = region.instrs
  let finish = region.base + instrs.length()
  let mut left = self.bound(source, region.base)
  let left_end = self.bound(source, finish)
  let mut right = self.bound(dest, region.base)
  let right_end = self.bound(dest, finish)
  let mut next_control = 0
  while left < left_end ||
        right < right_end ||
        next_control < region.controls.length() {
    let lp = if left < left_end {
      self.positions[left] - region.base
    } else {
      2147483647
    }
    let rp = if right < right_end {
      self.positions[right] - region.base
    } else {
      2147483647
    }
    let cp = if next_control < region.controls.length() {
      region.controls[next_control].offset
    } else {
      2147483647
    }
    let mut control = -1
    let idx = if cp <= lp && cp <= rp {
      control = next_control
      next_control += 1
      cp
    } else if lp <= rp {
      left += 1
      lp
    } else {
      right += 1
      rp
    }
    let instr = instrs[idx]
    match instr {
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == source =>
        if !has_source_value || dest_may_clobber_source {
          return cl_path_disjoint_scan_failed()
        }
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == dest =>
        if source_may_clobber_dest {
          return cl_path_disjoint_scan_failed()
        }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        has_source_value = true
        saw_source_write = true
        source_may_clobber_dest = !cl_source_write_is_dest_copy(
          instrs, idx, dest,
        )
        dest_may_clobber_source = false
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == source => {
        has_source_value = true
        saw_source_write = true
        source_may_clobber_dest = !cl_source_write_is_dest_copy(
          instrs, idx, dest,
        )
        dest_may_clobber_source = false
      }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        source_may_clobber_dest = false
        dest_may_clobber_source = has_source_value &&
          !cl_dest_write_is_source_copy(instrs, idx, source)
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        source_may_clobber_dest = false
        dest_may_clobber_source = has_source_value &&
          !cl_dest_write_is_source_copy(instrs, idx, source)
      }
      @lib.Block(_, _) => {
        let body = match region.controls[control].kind {
          CLLocalProofControlKind::Block(_, body) => body
          _ => abort("local proof block has no region index")
        }
        let scanned = self.scan_path(
          body, source, dest, has_source_value, source_may_clobber_dest, dest_may_clobber_source,
        )
        if !scanned.ok {
          return cl_path_disjoint_scan_failed()
        }
        if scanned.saw_source_write {
          saw_source_write = true
        }
        has_source_value = scanned.source_initialized
        source_may_clobber_dest = scanned.source_clobbers_dest
        dest_may_clobber_source = scanned.dest_clobbers_source
      }
      @lib.If(_, _, _) => {
        let then_body = match region.controls[control].kind {
          CLLocalProofControlKind::If(_, yes, _) => yes
          _ => abort("local proof conditional has no region index")
        }
        let else_body = match region.controls[control].kind {
          CLLocalProofControlKind::If(_, _, no) => no
          _ => abort("local proof conditional has no region index")
        }
        let then_scanned = self.scan_path(
          then_body, source, dest, has_source_value, source_may_clobber_dest, dest_may_clobber_source,
        )
        if !then_scanned.ok {
          return cl_path_disjoint_scan_failed()
        }
        let mut else_scanned : CLPathDisjointScan = {
          ok: true,
          saw_source_write: false,
          source_initialized: has_source_value,
          source_clobbers_dest: source_may_clobber_dest,
          dest_clobbers_source: dest_may_clobber_source,
        }
        match else_body {
          Some(body) => {
            else_scanned = self.scan_path(
              body, source, dest, has_source_value, source_may_clobber_dest, dest_may_clobber_source,
            )
            if !else_scanned.ok {
              return cl_path_disjoint_scan_failed()
            }
          }
          None => ()
        }
        saw_source_write = saw_source_write ||
          then_scanned.saw_source_write ||
          else_scanned.saw_source_write
        has_source_value = then_scanned.source_initialized &&
          else_scanned.source_initialized
        source_may_clobber_dest = then_scanned.source_clobbers_dest ||
          else_scanned.source_clobbers_dest
        dest_may_clobber_source = then_scanned.dest_clobbers_source ||
          else_scanned.dest_clobbers_source
      }
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) | @lib.Return =>
        return cl_path_disjoint_scan_failed()
      @lib.Loop(_, _) | @lib.TryTable(_, _, _) =>
        return cl_path_disjoint_scan_failed()
      _ => ()
    }
  }
  {
    ok: true,
    saw_source_write,
    source_initialized: has_source_value,
    source_clobbers_dest: source_may_clobber_dest,
    dest_clobbers_source: dest_may_clobber_source,
  }
}

///|
fn CLLocalProofIndex::consume_pair_safe(
  self : CLLocalProofIndex,
  source : Int32,
  dest : Int32,
) -> Bool {
  if source == dest {
    return cl_consume_forward_pair_safe(
      self.regions[self.root].instrs,
      source,
      dest,
    )
  }
  let state = self.scan_consume(
    self.root,
    source,
    dest,
    false,
    false,
    false,
    false,
  )
  state.ok && state.saw
}

///|
fn CLLocalProofIndex::path_pair_safe(
  self : CLLocalProofIndex,
  source : Int32,
  dest : Int32,
) -> Bool {
  if source == dest {
    return cl_path_disjoint_branch_result_pair_safe(
      self.regions[self.root].instrs,
      source,
      dest,
    )
  }
  let state = self.scan_path(self.root, source, dest, false, false, false)
  state.ok && state.saw_source_write
}

///|
fn CLLocalProofCache::consume_pair_safe(
  self : CLLocalProofCache,
  instrs : Array[@lib.Instruction],
  source : Int32,
  dest : Int32,
) -> Bool {
  if self.use_index(instrs, source, dest) {
    self.index.unwrap().consume_pair_safe(source, dest)
  } else {
    cl_consume_forward_pair_safe(instrs, source, dest)
  }
}

///|
fn CLLocalProofCache::path_pair_safe(
  self : CLLocalProofCache,
  instrs : Array[@lib.Instruction],
  source : Int32,
  dest : Int32,
) -> Bool {
  if self.use_index(instrs, source, dest) {
    self.index.unwrap().path_pair_safe(source, dest)
  } else {
    cl_path_disjoint_branch_result_pair_safe(instrs, source, dest)
  }
}
