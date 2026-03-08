///|
fn spec_runner_normalize_args(argv : Array[String]) -> Array[String] {
  let out : Array[String] = []
  let mut i = 1
  while i < argv.length() {
    let trimmed = argv[i].trim().to_string()
    if trimmed.length() > 0 {
      out.push(trimmed)
    }
    i += 1
  }
  out
}

///|
fn spec_runner_failed_preview(
  summary : WastSpecRunSummary,
  limit : Int,
) -> String {
  let out : Array[String] = []
  for report in summary.files {
    match report.status {
      Failed(msg) => out.push("\{report.path}: \{msg}")
      _ => ()
    }
  }
  let builder = StringBuilder::new()
  let mut i = 0
  while i < out.length() && i < limit {
    if i > 0 {
      builder.write_string(" | ")
    }
    builder.write_string(out[i])
    i += 1
  }
  builder.to_string()
}

///|
fn spec_runner_read_source(path : String) -> Result[String, String] {
  let data = read_file_sync(path) catch {
    e => return Err("read_file_sync failed: \{e}")
  }
  let text = data.text() catch { e => return Err("text decode failed: \{e}") }
  Ok(text)
}

///|
fn run_spec_runner(argv : Array[String]) -> Int {
  let paths = spec_runner_normalize_args(argv)
  if paths.length() == 0 {
    println("usage: spec_runner <tests/spec/*.wast ...>")
    return 2
  }

  let files : Array[(String, String)] = []
  let mut read_failed = false
  for path in paths {
    match spec_runner_read_source(path) {
      Ok(text) => files.push((path, text))
      Err(e) => {
        println("failed to load \{path}: \{e}")
        read_failed = true
      }
    }
  }

  if read_failed {
    return 2
  }

  let summary = run_wast_spec_suite(files)
  println(
    "spec suite summary: total=\{summary.total_files} passed=\{summary.passed_files} skipped=\{summary.skipped_files} failed=\{summary.failed_files}",
  )
  if summary.failed_files > 0 {
    let preview = spec_runner_failed_preview(summary, 20)
    println("failed files preview: \{preview}")
    return 1
  }
  0
}

///|
fn main {
  let args = try! args_get()
  let code = run_spec_runner(args)
  if code != 0 {
    proc_exit(code.reinterpret_as_uint())
  }
}
