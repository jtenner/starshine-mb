///|
fn is_ascii_letter(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
priv struct CompiledGlobPath {
  normalized : String
  prefix : String
  absolute : Bool
  segments : Array[String]
}

///|
priv struct CompiledGlobPattern {
  path : CompiledGlobPath
  first_segment_literal : String?
  min_segment_count : Int
  max_segment_count : Int?
}

///|
priv struct GlobPrefixBucket {
  all : Array[CompiledGlobPath]
  by_first_segment : @hashmap.HashMap[String, Array[CompiledGlobPath]]
}

///|
fn GlobPrefixBucket::new() -> GlobPrefixBucket {
  { all: [], by_first_segment: @hashmap.new(capacity=16) }
}

///|
priv struct GlobAbsoluteBucket {
  all : Array[CompiledGlobPath]
  by_first_segment : @hashmap.HashMap[String, Array[CompiledGlobPath]]
  by_prefix : @hashmap.HashMap[String, GlobPrefixBucket]
}

///|
fn GlobAbsoluteBucket::new() -> GlobAbsoluteBucket {
  {
    all: [],
    by_first_segment: @hashmap.new(capacity=16),
    by_prefix: @hashmap.new(capacity=16),
  }
}

///|
fn split_normalized_path(path : String) -> (String, Bool, Array[String]) {
  let mut index = 0
  let mut prefix = ""
  if path.length() >= 2 && is_ascii_letter(path[0]) && path[1] == ':' {
    prefix = path.sub(end=2).to_owned()
    index = 2
  }
  let mut absolute = false
  while index < path.length() && path[index] == '/' {
    absolute = true
    index += 1
  }
  let tail = path.sub(start=index).to_owned()
  let segments = Array::new()
  for part in tail.split("/") {
    let segment = part.to_owned()
    if segment.length() > 0 {
      segments.push(segment)
    }
  }
  (prefix, absolute, segments)
}

///|
fn compile_normalized_glob_path(normalized : String) -> CompiledGlobPath {
  let (prefix, absolute, segments) = split_normalized_path(normalized)
  { normalized, prefix, absolute, segments }
}

///|
fn is_literal_glob_segment(segment : String) -> Bool {
  if segment == "**" {
    return false
  }
  for c in segment {
    if c == '*' || c == '?' {
      return false
    }
  }
  true
}

///|
fn compile_glob_pattern(pattern : String) -> CompiledGlobPattern {
  let path = compile_normalized_glob_path(normalize_cli_path(pattern))
  let mut first_segment_literal : String? = None
  if path.segments.length() > 0 {
    let first = path.segments[0]
    if is_literal_glob_segment(first) {
      first_segment_literal = Some(first)
    }
  }
  let mut min_segment_count = 0
  let mut max_segment_count : Int? = Some(path.segments.length())
  for segment in path.segments {
    if segment == "**" {
      max_segment_count = None
    } else {
      min_segment_count += 1
    }
  }
  { path, first_segment_literal, min_segment_count, max_segment_count }
}

///|
fn wildcard_segment_match(pattern : String, text : String) -> Bool {
  let mut p = 0
  let mut t = 0
  let mut last_star = -1
  let mut last_match = 0
  while t < text.length() {
    if p < pattern.length() && (pattern[p] == '?' || pattern[p] == text[t]) {
      p += 1
      t += 1
      continue
    }
    if p < pattern.length() && pattern[p] == '*' {
      last_star = p
      p += 1
      last_match = t
      continue
    }
    if last_star >= 0 {
      p = last_star + 1
      last_match += 1
      t = last_match
      continue
    }
    return false
  }
  while p < pattern.length() && pattern[p] == '*' {
    p += 1
  }
  p == pattern.length()
}

///|
fn glob_match_segments(
  pattern_segments : Array[String],
  pattern_index : Int,
  path_segments : Array[String],
  path_index : Int,
) -> Bool {
  if pattern_index == pattern_segments.length() {
    return path_index == path_segments.length()
  }
  let segment = pattern_segments[pattern_index]
  if segment == "**" {
    let mut next = pattern_index + 1
    while next < pattern_segments.length() && pattern_segments[next] == "**" {
      next += 1
    }
    if next == pattern_segments.length() {
      return true
    }
    let mut i = path_index
    while i <= path_segments.length() {
      if glob_match_segments(pattern_segments, next, path_segments, i) {
        return true
      }
      i += 1
    }
    return false
  }
  if path_index >= path_segments.length() {
    return false
  }
  if !wildcard_segment_match(segment, path_segments[path_index]) {
    return false
  }
  glob_match_segments(
    pattern_segments,
    pattern_index + 1,
    path_segments,
    path_index + 1,
  )
}

///|
fn compiled_glob_pattern_matches_candidate(
  pattern : CompiledGlobPattern,
  candidate : CompiledGlobPath,
) -> Bool {
  if pattern.path.prefix.length() > 0 && pattern.path.prefix != candidate.prefix {
    return false
  }
  if pattern.path.absolute != candidate.absolute {
    return false
  }
  let candidate_segment_count = candidate.segments.length()
  if candidate_segment_count < pattern.min_segment_count {
    return false
  }
  match pattern.max_segment_count {
    Some(max_segment_count) if candidate_segment_count > max_segment_count =>
      return false
    _ => ()
  }
  match pattern.first_segment_literal {
    Some(first_segment) =>
      if candidate_segment_count == 0 || candidate.segments[0] != first_segment {
        return false
      }
    None => ()
  }
  glob_match_segments(pattern.path.segments, 0, candidate.segments, 0)
}

///|
fn is_dot_or_dotdot_segment(path : String, start : Int, end : Int) -> Bool {
  let length = end - start
  (length == 1 && path[start] == '.') ||
  (length == 2 && path[start] == '.' && path[start + 1] == '.')
}

///|
fn cli_path_needs_normalization(path : String) -> Bool {
  if path.length() == 0 {
    return true
  }
  let mut index = 0
  if path.length() >= 2 && is_ascii_letter(path[0]) && path[1] == ':' {
    index = 2
  }
  let mut segment_start = index
  let mut previous_was_separator = false
  while index < path.length() {
    let c = path[index]
    if c == '\\' {
      return true
    }
    if c == '/' {
      if previous_was_separator {
        return true
      }
      if is_dot_or_dotdot_segment(path, segment_start, index) {
        return true
      }
      previous_was_separator = true
      segment_start = index + 1
    } else {
      previous_was_separator = false
    }
    index += 1
  }
  if previous_was_separator && segment_start > 1 {
    return true
  }
  is_dot_or_dotdot_segment(path, segment_start, path.length())
}

///|
pub fn normalize_cli_path(path : String) -> String {
  if !cli_path_needs_normalization(path) {
    return path
  }
  let separators = StringBuilder::new()
  for c in path {
    if c == '\\' {
      separators.write_char('/')
    } else {
      separators.write_char(c)
    }
  }
  let unix_separators = separators.to_string()
  let mut index = 0
  let mut prefix = ""
  if unix_separators.length() >= 2 &&
    is_ascii_letter(unix_separators[0]) &&
    unix_separators[1] == ':' {
    prefix = unix_separators.sub(end=2).to_owned()
    index = 2
  }
  let mut absolute = false
  while index < unix_separators.length() && unix_separators[index] == '/' {
    absolute = true
    index += 1
  }
  let tail = unix_separators.sub(start=index).to_owned()
  let segments = Array::new()
  for part in tail.split("/") {
    let segment = part.to_owned()
    if segment.length() == 0 || segment == "." {
      continue
    }
    if segment == ".." {
      if segments.length() > 0 && segments[segments.length() - 1] != ".." {
        ignore(segments.pop())
      } else if !absolute {
        segments.push(segment)
      }
      continue
    }
    segments.push(segment)
  }
  let out = StringBuilder::new()
  out.write_string(prefix)
  if absolute {
    out.write_char('/')
  }
  let mut first = true
  for segment in segments {
    if !first {
      out.write_char('/')
    }
    out.write_string(segment)
    first = false
  }
  let normalized = out.to_string()
  if normalized.length() == 0 {
    "."
  } else {
    normalized
  }
}

///|
fn glob_bucket_add_candidate_by_first_segment(
  by_first_segment : @hashmap.HashMap[String, Array[CompiledGlobPath]],
  candidate : CompiledGlobPath,
) -> Unit {
  if candidate.segments.length() == 0 {
    return
  }
  let first_segment = candidate.segments[0]
  match by_first_segment.get(first_segment) {
    Some(bucket) => bucket.push(candidate)
    None => by_first_segment.set(first_segment, [candidate])
  }
}

///|
fn glob_prefix_bucket_add(
  bucket : GlobPrefixBucket,
  candidate : CompiledGlobPath,
) -> Unit {
  bucket.all.push(candidate)
  glob_bucket_add_candidate_by_first_segment(bucket.by_first_segment, candidate)
}

///|
fn glob_absolute_bucket_add(
  bucket : GlobAbsoluteBucket,
  candidate : CompiledGlobPath,
) -> Unit {
  bucket.all.push(candidate)
  glob_bucket_add_candidate_by_first_segment(bucket.by_first_segment, candidate)
  if candidate.prefix.length() == 0 {
    return
  }
  let prefix_bucket = match bucket.by_prefix.get(candidate.prefix) {
    Some(existing) => existing
    None => {
      let new_bucket = GlobPrefixBucket::new()
      bucket.by_prefix.set(candidate.prefix, new_bucket)
      new_bucket
    }
  }
  glob_prefix_bucket_add(prefix_bucket, candidate)
}

///|
fn glob_bucket_candidates_for_first_segment(
  all : Array[CompiledGlobPath],
  by_first_segment : @hashmap.HashMap[String, Array[CompiledGlobPath]],
  first_segment_literal : String?,
) -> Array[CompiledGlobPath]? {
  match first_segment_literal {
    Some(first_segment) => by_first_segment.get(first_segment)
    None => Some(all)
  }
}

///|
fn glob_absolute_bucket_candidates(
  bucket : GlobAbsoluteBucket,
  pattern : CompiledGlobPattern,
) -> Array[CompiledGlobPath]? {
  if pattern.path.prefix.length() > 0 {
    match bucket.by_prefix.get(pattern.path.prefix) {
      Some(prefix_bucket) =>
        glob_bucket_candidates_for_first_segment(
          prefix_bucket.all,
          prefix_bucket.by_first_segment,
          pattern.first_segment_literal,
        )
      None => None
    }
  } else {
    glob_bucket_candidates_for_first_segment(
      bucket.all,
      bucket.by_first_segment,
      pattern.first_segment_literal,
    )
  }
}

///|
pub fn glob_match(pattern : String, candidate : String) -> Bool {
  let compiled_pattern = compile_glob_pattern(pattern)
  let compiled_candidate = compile_normalized_glob_path(
    normalize_cli_path(candidate),
  )
  compiled_glob_pattern_matches_candidate(compiled_pattern, compiled_candidate)
}

///|
pub fn expand_globs(
  patterns : Array[String],
  candidates : Array[String],
) -> Array[String] {
  let normalized_candidates = Array::new()
  let seen_candidates : Set[String] = Set::new()
  for candidate in candidates {
    let normalized = normalize_cli_path(candidate)
    if !seen_candidates.contains(normalized) {
      seen_candidates.add(normalized)
      normalized_candidates.push(normalized)
    }
  }
  normalized_candidates.sort()

  let relative_candidates = GlobAbsoluteBucket::new()
  let absolute_candidates = GlobAbsoluteBucket::new()
  for normalized in normalized_candidates {
    let compiled = compile_normalized_glob_path(normalized)
    if compiled.absolute {
      glob_absolute_bucket_add(absolute_candidates, compiled)
    } else {
      glob_absolute_bucket_add(relative_candidates, compiled)
    }
  }

  let compiled_patterns = Array::new()
  for pattern in patterns {
    compiled_patterns.push(compile_glob_pattern(pattern))
  }

  let out = Array::new()
  let seen_out : Set[String] = Set::new()
  for pattern in compiled_patterns {
    let candidates_for_pattern = if pattern.path.absolute {
      glob_absolute_bucket_candidates(absolute_candidates, pattern)
    } else {
      glob_absolute_bucket_candidates(relative_candidates, pattern)
    }
    match candidates_for_pattern {
      Some(bucket_candidates) =>
        for candidate in bucket_candidates {
          if compiled_glob_pattern_matches_candidate(pattern, candidate) &&
            !seen_out.contains(candidate.normalized) {
            seen_out.add(candidate.normalized)
            out.push(candidate.normalized)
          }
        }
      None => ()
    }
  }
  out
}

///|
pub fn expand_globs_with_adapter(
  patterns : Array[String],
  list_candidates : () -> Array[String],
) -> Array[String] {
  expand_globs(patterns, list_candidates())
}
