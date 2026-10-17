// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
priv struct InlBodyMeasureCache {
  mut measurements : Array[(Bool, Bool, Bool, Bool, Int32)?]
  mut bodies : Array[Array[@lib.Instruction]?]
  flat_only : Bool
}

///|
fn InlBodyMeasureCache::new(
  count : Int32,
  flat_only~ : Bool = false,
) -> InlBodyMeasureCache {
  {
    measurements: Array::make(count, None),
    bodies: Array::make(count, None),
    flat_only,
  }
}

///|
fn InlBodyMeasureCache::measure(
  self : InlBodyMeasureCache,
  index : Int32,
  body : Array[@lib.Instruction],
  visits~ : Array[Int32]? = None,
) -> (Bool, Bool, Bool, Bool, Int32) {
  if index < 0 || index >= self.measurements.length() {
    return inl_measure_body(body, visits~)
  }
  match self.measurements[index] {
    Some(facts) if self.bodies[index] is Some(previous) &&
      physical_equal(previous, body) => facts
    _ => {
      let facts = inl_measure_body(body, visits~)
      // Raw optimizing cleanup may own and change nested arrays. Until those
      // ownership contracts are complete, only retain flat bodies in that mode.
      if self.flat_only &&
        body.any(fn(instr) {
          match instr {
            @lib.Block(_, _)
            | @lib.Loop(_, _)
            | @lib.If(_, _, _)
            | @lib.Try(_, _, _, _)
            | @lib.TryTable(_, _, _) => true
            _ => false
          }
        }) {
        self.measurements[index] = None
        self.bodies[index] = None
        return facts
      }
      self.measurements[index] = Some(facts)
      self.bodies[index] = Some(body)
      facts
    }
  }
}

///|
fn InlBodyMeasureCache::remap(
  self : InlBodyMeasureCache,
  touched : Array[Bool],
  final_to_prior : Array[Int32],
) -> Unit {
  let previous = self.measurements
  let previous_bodies = self.bodies
  self.measurements = final_to_prior.map(fn(prior) {
    if prior >= 0 &&
      prior < previous.length() &&
      (prior >= touched.length() || !touched[prior]) {
      previous[prior]
    } else {
      None
    }
  })
  self.bodies = final_to_prior.map(fn(prior) {
    if prior >= 0 &&
      prior < previous_bodies.length() &&
      (prior >= touched.length() || !touched[prior]) {
      previous_bodies[prior]
    } else {
      None
    }
  })
}
