///|
fn db19_f14_bench(it : @bench.T, n : Int32, shape : Int32) -> Unit {
  let long = StringBuilder::new()
  for _ in 0..<64 {
    long.write_string("directory/")
  }
  long.write_string("fixture.wast")
  let path = if shape == 0 {
    "fixtures/a.wast"
  } else if shape == 1 {
    long.to_string()
  } else if shape == 2 {
    " \t fixtures/a.wast  "
  } else {
    " \t  "
  }
  let args = ["spec-runner"]
  let expected : Array[String] = []
  for _ in 0..<n {
    args.push(path)
    expected.push(path)
  }
  let mut callbacks = 0
  it.bench(count=5, fn() {
    callbacks = callbacks + 1
    it.keep(spec_runner_normalize_args(args))
  })
  println("DB19_CALLBACKS=\{callbacks}")
  let actual = spec_runner_normalize_args(args)
  println("DB19_PATHS_PRESERVED=\{actual == expected}")
  println("DB19_PATH_COUNT=\{actual.length()}")
}

///|
test "bench db19 F14 no path arguments" (it : @bench.T) {
  db19_f14_bench(it, 0, 0)
}

///|
test "bench db19 F14 1 paths / short ordinary" (it : @bench.T) {
  db19_f14_bench(it, 1, 0)
}

///|
test "bench db19 F14 1 paths / long ordinary" (it : @bench.T) {
  db19_f14_bench(it, 1, 1)
}

///|
test "bench db19 F14 1 paths / leading and trailing spaces" (it : @bench.T) {
  db19_f14_bench(it, 1, 2)
}

///|
test "bench db19 F14 1 paths / whitespace-only" (it : @bench.T) {
  db19_f14_bench(it, 1, 3)
}

///|
test "bench db19 F14 64 paths / short ordinary" (it : @bench.T) {
  db19_f14_bench(it, 64, 0)
}

///|
test "bench db19 F14 64 paths / long ordinary" (it : @bench.T) {
  db19_f14_bench(it, 64, 1)
}

///|
test "bench db19 F14 64 paths / leading and trailing spaces" (it : @bench.T) {
  db19_f14_bench(it, 64, 2)
}

///|
test "bench db19 F14 64 paths / whitespace-only" (it : @bench.T) {
  db19_f14_bench(it, 64, 3)
}

///|
test "bench db19 F14 512 paths / short ordinary" (it : @bench.T) {
  db19_f14_bench(it, 512, 0)
}

///|
test "bench db19 F14 512 paths / long ordinary" (it : @bench.T) {
  db19_f14_bench(it, 512, 1)
}

///|
test "bench db19 F14 512 paths / leading and trailing spaces" (it : @bench.T) {
  db19_f14_bench(it, 512, 2)
}

///|
test "bench db19 F14 512 paths / whitespace-only" (it : @bench.T) {
  db19_f14_bench(it, 512, 3)
}
