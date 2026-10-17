///|
test "DAE2 writer cut keeps both conditional writers and every HOT demand bit" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(0))
}

///|
test "DAE2 writer cut keeps overwritten Tee and held read order" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(1))
}

///|
test "DAE2 writer cut keeps nested capture effects and both branch sources" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(2))
}

///|
test "DAE2 writer cut keeps loop backedge local and parameter demand" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(3))
}

///|
test "DAE2 writer cut keeps trapping prefix before void loop effects" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(4))
}

///|
test "DAE2 writer cut intentionally rejects a mismatched source write journal" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(0), journal_fault=1)
}

///|
test "DAE2 writer cut intentionally rejects stale lift provenance" {
  dae2_writer_cut_check(dae2_writer_cut_fixture(0), journal_fault=2)
}
