///|
pub enum DiffCompareMode {
  CompareLines
  CompareWords
  CompareChars
} derive(Eq, Show, Debug)

///|
pub fn DiffCompareMode::lines() -> DiffCompareMode {
  CompareLines
}

///|
pub fn DiffCompareMode::words() -> DiffCompareMode {
  CompareWords
}

///|
pub fn DiffCompareMode::chars() -> DiffCompareMode {
  CompareChars
}

///|
pub struct DiffOptions {
  compare : DiffCompareMode
  ignore_whitespace : Bool
  ignore_case : Bool
  ignore_accents : Bool
} derive(Eq, Show, Debug)

///|
pub fn DiffOptions::new(
  compare? : DiffCompareMode = DiffCompareMode::lines(),
  ignore_whitespace? : Bool = false,
  ignore_case? : Bool = false,
  ignore_accents? : Bool = false,
) -> DiffOptions {
  { compare, ignore_whitespace, ignore_case, ignore_accents }
}

///|
pub struct DiffChange {
  lhs_at : Int
  lhs_del : Int
  rhs_at : Int
  rhs_add : Int
} derive(Eq, Show, Debug)

///|
pub fn DiffChange::new(
  lhs_at : Int,
  lhs_del : Int,
  rhs_at : Int,
  rhs_add : Int,
) -> DiffChange {
  { lhs_at, lhs_del, rhs_at, rhs_add }
}

///|
priv struct MyersContext {
  codes : Array[Int]
  modified : Array[Bool]
  parts : Array[String]
}

///|
fn MyersContext::new(codes : Array[Int], parts : Array[String]) -> MyersContext {
  let modified : Array[Bool] = []
  for _ in 0..<codes.length() {
    modified.push(false)
  }
  { codes, modified, parts }
}

///|
fn myers_ascii_lower(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn myers_strip_ascii_whitespace(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c != ' ' && c != '\n' && c != '\r' && c != '\t' {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn myers_fold_latin1_accent(c : Char) -> Char {
  match c.to_int() {
    0x00c0
    | 0x00c1
    | 0x00c2
    | 0x00c3
    | 0x00c4
    | 0x00c5
    | 0x00e0
    | 0x00e1
    | 0x00e2
    | 0x00e3
    | 0x00e4
    | 0x00e5 => 'a'
    0x00c7 | 0x00e7 => 'c'
    0x00c8 | 0x00c9 | 0x00ca | 0x00cb | 0x00e8 | 0x00e9 | 0x00ea | 0x00eb => 'e'
    0x00cc | 0x00cd | 0x00ce | 0x00cf | 0x00ec | 0x00ed | 0x00ee | 0x00ef => 'i'
    0x00d1 | 0x00f1 => 'n'
    0x00d2
    | 0x00d3
    | 0x00d4
    | 0x00d5
    | 0x00d6
    | 0x00d8
    | 0x00f2
    | 0x00f3
    | 0x00f4
    | 0x00f5
    | 0x00f6
    | 0x00f8 => 'o'
    0x00d9 | 0x00da | 0x00db | 0x00dc | 0x00f9 | 0x00fa | 0x00fb | 0x00fc => 'u'
    0x00dd | 0x00fd | 0x00ff => 'y'
    _ => c
  }
}

///|
fn myers_strip_accents_latin1(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    out.write_char(myers_fold_latin1_accent(c))
  }
  out.to_string()
}

///|
fn myers_normalize_token(token : String, options : DiffOptions) -> String {
  let mut out = token
  if options.ignore_whitespace {
    out = myers_strip_ascii_whitespace(out)
  }
  if options.ignore_case {
    out = myers_ascii_lower(out)
  }
  if options.ignore_accents {
    // MoonBit does not currently expose full Unicode normalization in this
    // repository, so we fold common Latin-1 accented letters as a pragmatic
    // approximation.
    out = myers_strip_accents_latin1(out)
  }
  out
}

///|
fn myers_split_on_char(text : String, sep : Char) -> Array[String] {
  if text.length() == 0 {
    return []
  }
  let out : Array[String] = []
  let mut current = StringBuilder::new()
  for c in text {
    if c == sep {
      out.push(current.to_string())
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  out.push(current.to_string())
  out
}

///|
fn myers_split_text(text : String, compare : DiffCompareMode) -> Array[String] {
  match compare {
    CompareLines => myers_split_on_char(text, '\n')
    CompareWords => myers_split_on_char(text, ' ')
    CompareChars => {
      let out : Array[String] = []
      for c in text {
        out.push(c.to_string())
      }
      out
    }
  }
}

///|
fn myers_make_int_array(size : Int, value : Int) -> Array[Int] {
  let out : Array[Int] = []
  for _ in 0..<size {
    out.push(value)
  }
  out
}

///|
fn myers_build_contexts(
  lhs : String,
  rhs : String,
  options : DiffOptions,
) -> (MyersContext, MyersContext) {
  let lhs_parts = myers_split_text(lhs, options.compare)
  let rhs_parts = myers_split_text(rhs, options.compare)

  let code_by_text : Map[String, Int] = {}
  let mut next_code = 0

  let lhs_codes : Array[Int] = []
  for part in lhs_parts {
    let key = myers_normalize_token(part, options)
    match code_by_text.get(key) {
      Some(code) => lhs_codes.push(code)
      None => {
        next_code += 1
        code_by_text[key] = next_code
        lhs_codes.push(next_code)
      }
    }
  }

  let rhs_codes : Array[Int] = []
  for part in rhs_parts {
    let key = myers_normalize_token(part, options)
    match code_by_text.get(key) {
      Some(code) => rhs_codes.push(code)
      None => {
        next_code += 1
        code_by_text[key] = next_code
        rhs_codes.push(next_code)
      }
    }
  }

  (
    MyersContext::new(lhs_codes, lhs_parts),
    MyersContext::new(rhs_codes, rhs_parts),
  )
}

///|
fn myers_get_shortest_middle_snake(
  lhs_ctx : MyersContext,
  lhs_lower : Int,
  lhs_upper : Int,
  rhs_ctx : MyersContext,
  rhs_lower : Int,
  rhs_upper : Int,
  vector_u : Array[Int],
  vector_d : Array[Int],
  max : Int,
) -> (Int, Int) {
  let kdown = lhs_lower - rhs_lower
  let kup = lhs_upper - rhs_upper
  let delta = lhs_upper - lhs_lower - (rhs_upper - rhs_lower)
  let odd = (delta & 1) != 0
  let offset_down = max - kdown
  let offset_up = max - kup
  let maxd = (lhs_upper - lhs_lower + rhs_upper - rhs_lower) / 2 + 1

  vector_d[offset_down + kdown + 1] = lhs_lower
  vector_u[offset_up + kup - 1] = lhs_upper

  let mut d = 0
  while d <= maxd {
    let mut k = kdown - d
    while k <= kdown + d {
      let mut x = if k == kdown - d {
        vector_d[offset_down + k + 1]
      } else {
        let mut x = vector_d[offset_down + k - 1] + 1
        if k < kdown + d && vector_d[offset_down + k + 1] >= x {
          x = vector_d[offset_down + k + 1]
        }
        x
      }
      let mut y = x - k
      while x < lhs_upper &&
            y < rhs_upper &&
            lhs_ctx.codes[x] == rhs_ctx.codes[y] {
        x += 1
        y += 1
      }
      vector_d[offset_down + k] = x
      if odd && kup - d < k && k < kup + d {
        if vector_u[offset_up + k] <= vector_d[offset_down + k] {
          let snake_x = vector_d[offset_down + k]
          return (snake_x, snake_x - k)
        }
      }
      k += 2
    }

    k = kup - d
    while k <= kup + d {
      let mut x = if k == kup + d {
        vector_u[offset_up + k - 1]
      } else {
        let mut x = vector_u[offset_up + k + 1] - 1
        if k > kup - d && vector_u[offset_up + k - 1] < x {
          x = vector_u[offset_up + k - 1]
        }
        x
      }
      let mut y = x - k
      while x > lhs_lower &&
            y > rhs_lower &&
            lhs_ctx.codes[x - 1] == rhs_ctx.codes[y - 1] {
        x -= 1
        y -= 1
      }
      vector_u[offset_up + k] = x
      if !odd && kdown - d <= k && k <= kdown + d {
        if vector_u[offset_up + k] <= vector_d[offset_down + k] {
          let snake_x = vector_d[offset_down + k]
          return (snake_x, snake_x - k)
        }
      }
      k += 2
    }
    d += 1
  }

  (lhs_lower, rhs_lower)
}

///|
fn myers_mark_lcs(
  lhs_ctx : MyersContext,
  lhs_lower : Int,
  lhs_upper : Int,
  rhs_ctx : MyersContext,
  rhs_lower : Int,
  rhs_upper : Int,
  vector_u : Array[Int],
  vector_d : Array[Int],
  max : Int,
) -> Unit {
  let mut lhs_lower = lhs_lower
  let mut lhs_upper = lhs_upper
  let mut rhs_lower = rhs_lower
  let mut rhs_upper = rhs_upper

  while lhs_lower < lhs_upper &&
        rhs_lower < rhs_upper &&
        lhs_ctx.codes[lhs_lower] == rhs_ctx.codes[rhs_lower] {
    lhs_lower += 1
    rhs_lower += 1
  }
  while lhs_lower < lhs_upper &&
        rhs_lower < rhs_upper &&
        lhs_ctx.codes[lhs_upper - 1] == rhs_ctx.codes[rhs_upper - 1] {
    lhs_upper -= 1
    rhs_upper -= 1
  }

  if lhs_lower == lhs_upper {
    while rhs_lower < rhs_upper {
      rhs_ctx.modified[rhs_lower] = true
      rhs_lower += 1
    }
    return
  }
  if rhs_lower == rhs_upper {
    while lhs_lower < lhs_upper {
      lhs_ctx.modified[lhs_lower] = true
      lhs_lower += 1
    }
    return
  }

  let (x, y) = myers_get_shortest_middle_snake(
    lhs_ctx, lhs_lower, lhs_upper, rhs_ctx, rhs_lower, rhs_upper, vector_u, vector_d,
    max,
  )
  myers_mark_lcs(
    lhs_ctx, lhs_lower, x, rhs_ctx, rhs_lower, y, vector_u, vector_d, max,
  )
  myers_mark_lcs(
    lhs_ctx, x, lhs_upper, rhs_ctx, y, rhs_upper, vector_u, vector_d, max,
  )
}

///|
fn myers_collect_changes(
  lhs_ctx : MyersContext,
  rhs_ctx : MyersContext,
) -> Array[DiffChange] {
  let out : Array[DiffChange] = []
  let mut lhs_line = 0
  let mut rhs_line = 0
  while lhs_line < lhs_ctx.codes.length() || rhs_line < rhs_ctx.codes.length() {
    if lhs_line < lhs_ctx.codes.length() &&
      rhs_line < rhs_ctx.codes.length() &&
      !lhs_ctx.modified[lhs_line] &&
      !rhs_ctx.modified[rhs_line] {
      lhs_line += 1
      rhs_line += 1
    } else {
      let lhs_start = lhs_line
      let rhs_start = rhs_line
      while lhs_line < lhs_ctx.codes.length() &&
            (rhs_line >= rhs_ctx.codes.length() || lhs_ctx.modified[lhs_line]) {
        lhs_line += 1
      }
      while rhs_line < rhs_ctx.codes.length() &&
            (lhs_line >= lhs_ctx.codes.length() || rhs_ctx.modified[rhs_line]) {
        rhs_line += 1
      }
      if lhs_start < lhs_line || rhs_start < rhs_line {
        out.push(
          DiffChange::new(
            lhs_start,
            lhs_line - lhs_start,
            rhs_start,
            rhs_line - rhs_start,
          ),
        )
      }
    }
  }
  out
}

///|
fn myers_diff_internal(
  lhs : String,
  rhs : String,
  options : DiffOptions,
) -> (Array[DiffChange], Array[String], Array[String]) {
  let (lhs_ctx, rhs_ctx) = myers_build_contexts(lhs, rhs, options)
  let lhs_len = lhs_ctx.codes.length()
  let rhs_len = rhs_ctx.codes.length()
  let max = lhs_len + rhs_len + 1
  let vector_size = max * 2 + 4
  let vector_u = myers_make_int_array(vector_size, 0)
  let vector_d = myers_make_int_array(vector_size, 0)
  myers_mark_lcs(
    lhs_ctx, 0, lhs_len, rhs_ctx, 0, rhs_len, vector_u, vector_d, max,
  )
  let changes = myers_collect_changes(lhs_ctx, rhs_ctx)
  (changes, lhs_ctx.parts, rhs_ctx.parts)
}

///|
pub fn myers_diff(
  lhs : String,
  rhs : String,
  options? : DiffOptions = DiffOptions::new(),
) -> Array[DiffChange] {
  let (changes, _, _) = myers_diff_internal(lhs, rhs, options)
  changes
}

///|
pub fn render_line_diff(
  lhs : String,
  rhs : String,
  options? : DiffOptions = DiffOptions::new(),
) -> String {
  let context_lines = 2
  let (changes, lhs_parts, rhs_parts) = myers_diff_internal(lhs, rhs, options)
  if changes.is_empty() {
    return "(no changes)\n"
  }
  let out = StringBuilder::new()
  for change in changes {
    let lhs_context_start = if change.lhs_at > context_lines {
      change.lhs_at - context_lines
    } else {
      0
    }
    let lhs_context_end_base = change.lhs_at + change.lhs_del + context_lines
    let lhs_context_end = if lhs_context_end_base < lhs_parts.length() {
      lhs_context_end_base
    } else {
      lhs_parts.length()
    }
    out.write_string(
      "@@ lhs[\{change.lhs_at},\{change.lhs_del}] rhs[\{change.rhs_at},\{change.rhs_add}] @@\n",
    )
    for i in lhs_context_start..<change.lhs_at {
      out.write_string(" \{lhs_parts[i]}\n")
    }
    for i in change.lhs_at..<(change.lhs_at + change.lhs_del) {
      out.write_string("-\{lhs_parts[i]}\n")
    }
    for i in change.rhs_at..<(change.rhs_at + change.rhs_add) {
      out.write_string("+\{rhs_parts[i]}\n")
    }
    for i in (change.lhs_at + change.lhs_del)..<lhs_context_end {
      out.write_string(" \{lhs_parts[i]}\n")
    }
  }
  out.to_string()
}
