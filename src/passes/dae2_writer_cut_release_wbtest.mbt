///|
test "writer cut releases admitted provenance before real rewrite and lower" {
  dae2_writer_cut_probe_check(0)
}

///|
test "writer cut releases intentionally invalid source provenance after full fallback" {
  dae2_writer_cut_probe_check(1)
}

///|
test "writer cut restores every graph field after intentionally tampered private writer demand" {
  dae2_writer_cut_probe_check(2)
}
