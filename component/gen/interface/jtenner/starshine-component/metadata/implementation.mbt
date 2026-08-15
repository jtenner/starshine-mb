///|
pub fn version() -> String {
  "0.1.1"
}

///|
pub fn implementation_target() -> String {
  "portable-component-linear-wasm"
}

///|
pub fn capabilities() -> Array[Capability] {
  [
    { name: "binary", description: "decode, validate, and encode Core WebAssembly binaries" },
    { name: "text", description: "parse WAT/WAST module text into Core WebAssembly" },
    { name: "validate", description: "validate decoded Core WebAssembly modules" },
    { name: "passes", description: "discover and run Starshine preset and named optimization passes" },
    { name: "generate", description: "generate deterministic valid Core WebAssembly modules from named profiles and seeds" },
    { name: "core-ir", description: "construct complete Core WebAssembly module IR through typed resource constructors" },
  ]
}
