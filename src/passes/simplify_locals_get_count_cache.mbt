// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
priv struct SimplifyLocalsGetCounts {
  mut owner : @ir.HotFunc?
  mut revision : Int32
  mut local_count : Int32
  mut counts : Array[Int32]
}

///|
fn SimplifyLocalsGetCounts::new() -> SimplifyLocalsGetCounts {
  { owner: None, revision: -1, local_count: -1, counts: [], }
}

///|
fn simplify_locals_new_get_count_cache(
  func : @ir.HotFunc,
) -> SimplifyLocalsGetCounts? {
  let nodes = @ir.hot_node_count(func)
  if nodes >= 32 && nodes / 4 >= @ir.hot_local_count(func) {
    Some(SimplifyLocalsGetCounts::new())
  } else {
    None
  }
}

///|
fn simplify_locals_counts_for_cycle(
  func : @ir.HotFunc,
  cache : SimplifyLocalsGetCounts?,
  full_scans~ : Array[Int32]? = None,
) -> Array[Int32] {
  match cache {
    Some(cache) => cache.snapshot(func, full_scans~)
    None => {
      match full_scans {
        Some(scans) => scans[0] += 1
        None => ()
      }
      simplify_locals_count_local_gets(func)
    }
  }
}

///|
fn SimplifyLocalsGetCounts::snapshot(
  self : SimplifyLocalsGetCounts,
  func : @ir.HotFunc,
  full_scans~ : Array[Int32]? = None,
) -> Array[Int32] {
  let revision = @ir.hot_revision_current(func)
  let local_count = @ir.hot_local_count(func)
  match self.owner {
    Some(owner) if physical_equal(owner, func) &&
      self.revision == revision &&
      self.local_count == local_count => return self.counts.copy()
    _ => ()
  }
  match full_scans {
    Some(scans) => scans[0] += 1
    None => ()
  }
  let counts = simplify_locals_count_local_gets(func)
  self.owner = Some(func)
  self.revision = revision
  self.local_count = local_count
  self.counts = counts
  // Both cleanup consumers may adjust counts. Keep the stored fact read-only.
  counts.copy()
}
