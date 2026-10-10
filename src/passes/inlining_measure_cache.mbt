// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
priv struct InlBodyMeasureCache {
  mut measurements : Array[(Bool, Bool, Bool, Bool, Int)?]
}

///|
fn InlBodyMeasureCache::new(count : Int) -> InlBodyMeasureCache {
  { measurements: Array::make(count, None), }
}

///|
fn InlBodyMeasureCache::measure(
  self : InlBodyMeasureCache,
  index : Int,
  body : Array[@lib.Instruction],
  visits? : Array[Int]? = None,
) -> (Bool, Bool, Bool, Bool, Int) {
  if index < 0 || index >= self.measurements.length() {
    return inl_measure_body(body, visits~)
  }
  match self.measurements[index] {
    Some(facts) => facts
    None => {
      let facts = inl_measure_body(body, visits~)
      self.measurements[index] = Some(facts)
      facts
    }
  }
}

///|
fn InlBodyMeasureCache::remap(
  self : InlBodyMeasureCache,
  touched : Array[Bool],
  final_to_prior : Array[Int],
) -> Unit {
  let previous = self.measurements
  self.measurements = final_to_prior.map(fn(prior) {
    if prior >= 0 &&
      prior < previous.length() &&
      (prior >= touched.length() || !touched[prior]) {
      previous[prior]
    } else {
      None
    }
  })
}
