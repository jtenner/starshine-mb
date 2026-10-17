///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut cold-noCFG width=16 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 0, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut cold-noCFG width=16 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 0, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut cold-noCFG width=128 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 0, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut cold-noCFG width=128 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 0, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut cold-noCFG width=1024 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 0, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut cold-noCFG width=1024 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 0, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut successful-CFG width=16 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 1, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut successful-CFG width=16 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 1, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut successful-CFG width=128 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 1, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut successful-CFG width=128 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 1, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut successful-CFG width=1024 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 1, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut successful-CFG width=1024 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 1, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut intentional-stale-fallback width=16 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 2, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut intentional-stale-fallback width=16 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 2, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut intentional-stale-fallback width=128 full" (
  it : @bench.T,
) {
  dae2_writer_cut_native_bench(it, 128, 2, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut intentional-stale-fallback width=128 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 2, true)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut intentional-stale-fallback width=1024 full" (
  it : @bench.T,
) {
  dae2_writer_cut_native_bench(it, 1024, 2, false)
}

///|
#skip("paired native writer-cut analysis including lift/journal allocation; dedicated lane")
test "bench writer cut intentional-stale-fallback width=1024 cut" (
  it : @bench.T,
) {
  dae2_writer_cut_native_bench(it, 1024, 2, true)
}

///|
#skip("paired native capture-heavy writer-cut allocation/control; dedicated lane")
test "bench writer cut successful-CFG-captures width=16 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 3, false)
}

///|
#skip("paired native capture-heavy writer-cut allocation/control; dedicated lane")
test "bench writer cut successful-CFG-captures width=16 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 3, true)
}

///|
#skip("paired native capture-heavy writer-cut allocation/control; dedicated lane")
test "bench writer cut successful-CFG-captures width=128 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 3, false)
}

///|
#skip("paired native capture-heavy writer-cut allocation/control; dedicated lane")
test "bench writer cut successful-CFG-captures width=128 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 128, 3, true)
}

///|
#skip("paired native capture-heavy writer-cut allocation/control; dedicated lane")
test "bench writer cut successful-CFG-captures width=1024 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 3, false)
}

///|
#skip("paired native capture-heavy writer-cut allocation/control; dedicated lane")
test "bench writer cut successful-CFG-captures width=1024 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 3, true)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut cold-one-source-write width=16 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 4, false)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut cold-one-source-write width=16 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 4, true)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut cold-one-source-write width=1024 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 4, false)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut cold-one-source-write width=1024 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 4, true)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut capture-only-old-CFG width=16 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 5, false)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut capture-only-old-CFG width=16 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 16, 5, true)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut capture-only-old-CFG width=1024 full" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 5, false)
}

///|
#skip("paired native cold gate footprint and capture-only fallback; dedicated lane")
test "bench writer cut capture-only-old-CFG width=1024 cut" (it : @bench.T) {
  dae2_writer_cut_native_bench(it, 1024, 5, true)
}
