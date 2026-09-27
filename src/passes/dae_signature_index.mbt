///|
fn dae_snapshot_function_types(
  mod_ : @lib.Module,
  indices : Array[@lib.TypeIdx],
  visited_types? : Array[Int]? = None,
) -> Array[@lib.FuncType?] {
  let mut last_needed = -1
  for index in indices {
    match index {
      @lib.TypeIdx(raw) =>
        if raw.reinterpret_as_int() > last_needed {
          last_needed = raw.reinterpret_as_int()
        }
      @lib.RecIdx(_) => ()
    }
  }
  if last_needed < 0 {
    return Array::make(indices.length(), None)
  }
  let flat : Array[@lib.FuncType?] = []
  match mod_.type_sec {
    Some(@lib.TypeSec(groups)) =>
      for group in groups {
        if flat.length() > last_needed {
          break
        }
        let subtypes = match group {
          @lib.SingleRecType(subtype) => [subtype]
          @lib.GroupRecType(subtypes) => subtypes
        }
        for subtype in subtypes {
          if flat.length() > last_needed {
            break
          }
          match visited_types {
            Some(count) => count[0] += 1
            None => ()
          }
          flat.push(
            match subtype.get_comptype() {
              @lib.FuncCompType(params, results) =>
                Some(@lib.FuncType::new(params, results))
              _ => None
            },
          )
        }
      }
    None => ()
  }
  indices.map(fn(index) {
    match index {
      @lib.TypeIdx(raw) =>
        match flat.get(raw.reinterpret_as_int()) {
          Some(signature) => signature
          None => None
        }
      @lib.RecIdx(_) => None
    }
  })
}
