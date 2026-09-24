// Descending distinct strings exercise collection, lexical sorting, and
// literal rewrite lookup. Validation stays outside the timed module pass.

///|
fn string_gathering_index_fixture(count : Int) -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for index = 0; index < count; index = index + 1 {
    let value = count - index
    let key = "s\{value / 1000}\{(value / 100) % 10}\{(value / 10) % 10}\{value % 10}"
    body.push(@lib.Instruction::string_const(key.to_bytes()))
    body.push(@lib.Instruction::drop())
  }
  opportunity_module(body, [], [])
}

///|
fn string_gathering_index_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = string_gathering_index_fixture(count)
  let expected = opportunity_run(fixture, "string-gathering", true)
  let original_code = fixture.code_sec
  it.bench(fn() { it.keep(@passes.string_gathering_run_module_pass(fixture)) })
  if @passes.string_gathering_run_module_pass(fixture) != expected ||
    fixture.code_sec != original_code {
    abort("string-gathering fixture changed across runs")
  }
}

///|
test "bench string-gathering distinct literals=256" (it : @bench.T) {
  string_gathering_index_bench(it, 256)
}

///|
test "bench string-gathering distinct literals=512" (it : @bench.T) {
  string_gathering_index_bench(it, 512)
}
