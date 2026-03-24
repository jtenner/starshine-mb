///|
pub enum HotAnalysis {
  Cfg
  Dominance
  Liveness
  UseDef
  Effects
  LoopInfo
  Ssa
} derive(Eq, Show, Debug)

///|
pub fn HotAnalysis::cfg() -> HotAnalysis {
  HotAnalysis::Cfg
}

///|
pub fn HotAnalysis::dominance() -> HotAnalysis {
  HotAnalysis::Dominance
}

///|
pub fn HotAnalysis::liveness() -> HotAnalysis {
  HotAnalysis::Liveness
}

///|
pub fn HotAnalysis::use_def() -> HotAnalysis {
  HotAnalysis::UseDef
}

///|
pub fn HotAnalysis::effects() -> HotAnalysis {
  HotAnalysis::Effects
}

///|
pub fn HotAnalysis::loop_info() -> HotAnalysis {
  HotAnalysis::LoopInfo
}

///|
pub fn HotAnalysis::ssa() -> HotAnalysis {
  HotAnalysis::Ssa
}

///|
pub struct HotPassDescriptor {
  name : String
  requires : Array[HotAnalysis]
  invalidates : Array[HotAnalysis]
} derive(Eq, Show, Debug)

///|
pub fn HotPassDescriptor::new(
  name : String,
  requires? : Array[HotAnalysis] = [],
  invalidates? : Array[HotAnalysis] = [],
) -> HotPassDescriptor {
  { name, requires, invalidates }
}

///|
pub fn hot_revision_current(func : HotFunc) -> Int {
  func.revision
}

///|
pub fn hot_pass_requires(descriptor : HotPassDescriptor) -> Array[HotAnalysis] {
  descriptor.requires
}

///|
pub fn hot_pass_invalidates(
  descriptor : HotPassDescriptor,
) -> Array[HotAnalysis] {
  descriptor.invalidates
}
