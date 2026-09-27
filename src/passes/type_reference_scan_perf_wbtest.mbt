///|
fn type_reference_probe_reference(mod_ : @lib.Module) -> @lib.Module {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      if rec_types.length() == 0 {
        return mod_
      }
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(_) => ()
          @lib.GroupRecType(_) => return mod_
        }
      }
      let live : Array[Bool] = Array::make(rec_types.length(), false)
      // Function-section references are direct and common. Avoid probing the
      // entire module separately for each already-live signature.
      match mod_.func_sec {
        Some(@lib.FuncSec(type_idxs)) =>
          for entry in type_idxs {
            match entry {
              @lib.TypeIdx(raw_idx) => {
                let type_idx = raw_idx.reinterpret_as_int()
                if type_idx >= 0 && type_idx < live.length() {
                  live[type_idx] = true
                }
              }
              @lib.RecIdx(_) => ()
            }
          }
        None => ()
      }
      match mod_.import_sec {
        Some(@lib.ImportSec(imports)) =>
          for import_ in imports {
            match import_ {
              @lib.Import(_, _, @lib.FuncExternType(@lib.TypeIdx(raw_idx))) => {
                let type_idx = raw_idx.reinterpret_as_int()
                if type_idx >= 0 && type_idx < live.length() {
                  live[type_idx] = true
                }
              }
              @lib.Import(
                _,
                _,
                @lib.TagExternType(@lib.TagType(@lib.TypeIdx(raw_idx)))
              ) => {
                let type_idx = raw_idx.reinterpret_as_int()
                if type_idx >= 0 && type_idx < live.length() {
                  live[type_idx] = true
                }
              }
              _ => ()
            }
          }
        None => ()
      }
      match mod_.tag_sec {
        Some(@lib.TagSec(tags)) =>
          for tag in tags {
            match tag {
              @lib.TagType(@lib.TypeIdx(raw_idx)) => {
                let type_idx = raw_idx.reinterpret_as_int()
                if type_idx >= 0 && type_idx < live.length() {
                  live[type_idx] = true
                }
              }
              _ => ()
            }
          }
        None => ()
      }
      if live.all(fn(is_live) { is_live }) {
        return mod_
      }
      let without_types = mod_.with_type_sec(@lib.TypeSec::new([]))
      let bulk_probe : Map[UInt, UInt] = Map([])
      let mut candidate_count = 0
      for candidate_idx = 0
          candidate_idx < rec_types.length()
          candidate_idx = candidate_idx + 1 {
        if !live[candidate_idx] {
          bulk_probe[candidate_idx.reinterpret_as_uint()] = rec_types
            .length()
            .reinterpret_as_uint()
          candidate_count += 1
        }
      }
      let needs_individual_probes = candidate_count == 1 ||
        dfe_module_type_refs_use_remap(without_types, bulk_probe)
      let mut idx = 0
      if needs_individual_probes {
        while idx < rec_types.length() {
          if !live[idx] {
            let probe : Map[UInt, UInt] = Map([])
            let raw_idx = idx.reinterpret_as_uint()
            probe[raw_idx] = rec_types.length().reinterpret_as_uint()
            if dfe_module_type_refs_use_remap(without_types, probe) {
              live[idx] = true
            }
          }
          idx += 1
        }
      }
      let mut discovered = true
      while discovered {
        discovered = false
        idx = 0
        while idx < rec_types.length() {
          if live[idx] {
            let mut dependency_idx = 0
            while dependency_idx < rec_types.length() {
              if !live[dependency_idx] {
                let probe : Map[UInt, UInt] = Map([])
                let raw_dependency_idx = dependency_idx.reinterpret_as_uint()
                probe[raw_dependency_idx] = rec_types
                  .length()
                  .reinterpret_as_uint()
                if dfe_rec_type_uses_remap(rec_types[idx], probe) {
                  live[dependency_idx] = true
                  discovered = true
                }
              }
              dependency_idx += 1
            }
          }
          idx += 1
        }
      }
      let kept : Array[@lib.RecType] = []
      let remap : Map[UInt, UInt] = Map([])
      idx = 0
      while idx < rec_types.length() {
        if live[idx] {
          remap[idx.reinterpret_as_uint()] = kept.length().reinterpret_as_uint()
          kept.push(rec_types[idx])
        }
        idx += 1
      }
      if kept.length() == rec_types.length() {
        return mod_
      }
      let rewritten = dfe_rewrite_module_type_idxs(
        mod_.with_type_sec(@lib.TypeSec::new(kept)),
        remap,
      )
      match rewritten.name_sec {
        Some(name_sec) =>
          rewritten.with_name_sec(dfe_rewrite_type_name_sec(name_sec, remap))
        None => rewritten
      }
    }
    None => mod_
  }
}

///|
fn type_reference_scan_benchmark(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let input = type_reference_scan_fixture(count, 2048)
  let expected = type_reference_probe_reference(input)
  let actual = dfe_prune_unused_simple_types(input)
  if actual != expected {
    abort("type reference benchmark changed pruning")
  }
  if @validate.validate_module(actual).is_err() {
    abort("invalid type reference fixture")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        type_reference_probe_reference(input)
      } else {
        dfe_prune_unused_simple_types(input)
      },
    )
  })
}

///|
test "bench type roots probes types=32 body=2048" (it : @bench.T) {
  type_reference_scan_benchmark(it, 32, true)
}

///|
test "bench type roots single scan types=32 body=2048" (it : @bench.T) {
  type_reference_scan_benchmark(it, 32, false)
}

///|
test "bench type roots probes types=128 body=2048" (it : @bench.T) {
  type_reference_scan_benchmark(it, 128, true)
}

///|
test "bench type roots single scan types=128 body=2048" (it : @bench.T) {
  type_reference_scan_benchmark(it, 128, false)
}
