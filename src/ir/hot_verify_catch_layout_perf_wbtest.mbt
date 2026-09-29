///|
fn catch_layout_perf_fixture(roots : Int, with_catch : Bool) -> HotFunc {
  let func = HotFunc::new()
  for _ in 0..<roots {
    hot_root_append(func, hot_build_nop(func))
  }
  if with_catch {
    let payload = hot_build_catch_payload(
      func,
      @lib.TagIdx::new(0U),
      @lib.ValType::i32(),
    )
    let try_node = hot_build_try(
      func,
      @lib.BlockType::void_(),
      [hot_build_nop(func)],
      catch_body=Some([payload, hot_build_drop(func, payload)]),
    )
    hot_root_append(func, try_node)
  }
  func
}

///|
fn catch_layout_perf_run(
  it : @bench.T,
  roots : Int,
  with_catch : Bool,
  original : Bool,
) -> Unit {
  let func = catch_layout_perf_fixture(roots, with_catch)
  hot_verify_all_or_abort(func)
  it.bench(fn() {
    it.keep(
      if original {
        catch_layout_reference_control(func)
      } else {
        hot_verify_control(func)
      },
    )
  })
}

///|
test "bench catch layout roots=128 catch=false original" (it : @bench.T) {
  catch_layout_perf_run(it, 128, false, true)
}

///|
test "bench catch layout roots=128 catch=false guarded" (it : @bench.T) {
  catch_layout_perf_run(it, 128, false, false)
}

///|
test "bench catch layout roots=128 catch=true original" (it : @bench.T) {
  catch_layout_perf_run(it, 128, true, true)
}

///|
test "bench catch layout roots=128 catch=true guarded" (it : @bench.T) {
  catch_layout_perf_run(it, 128, true, false)
}

///|
test "bench catch layout roots=4096 catch=false original" (it : @bench.T) {
  catch_layout_perf_run(it, 4096, false, true)
}

///|
test "bench catch layout roots=4096 catch=false guarded" (it : @bench.T) {
  catch_layout_perf_run(it, 4096, false, false)
}

///|
test "bench catch layout roots=4096 catch=true original" (it : @bench.T) {
  catch_layout_perf_run(it, 4096, true, true)
}

///|
test "bench catch layout roots=4096 catch=true guarded" (it : @bench.T) {
  catch_layout_perf_run(it, 4096, true, false)
}
