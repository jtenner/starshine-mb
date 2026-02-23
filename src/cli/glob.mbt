///|
fn is_ascii_letter(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn split_normalized_path(path : String) -> (String, Bool, Array[String]) {
  let mut index = 0
  let mut prefix = ""
  if path.length() >= 2 && is_ascii_letter(path[0]) && path[1] == ':' {
    prefix = path.sub(end=2).to_string() catch { _ => "" }
    index = 2
  }
  let mut absolute = false
  while index < path.length() && path[index] == '/' {
    absolute = true
    index += 1
  }
  let tail = path.sub(start=index).to_string() catch { _ => "" }
  let segments = Array::new()
  for part in tail.split("/") {
    let segment = part.to_string()
    if segment.length() > 0 {
      segments.push(segment)
    }
  }
  (prefix, absolute, segments)
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
pub fn normalize_cli_path(path : String) -> String {
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
    prefix = unix_separators.sub(end=2).to_string() catch { _ => "" }
    index = 2
  }
  let mut absolute = false
  while index < unix_separators.length() && unix_separators[index] == '/' {
    absolute = true
    index += 1
  }
  let tail = unix_separators.sub(start=index).to_string() catch { _ => "" }
  let segments = Array::new()
  for part in tail.split("/") {
    let segment = part.to_string()
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
pub fn glob_match(pattern : String, candidate : String) -> Bool {
  let normalized_pattern = normalize_cli_path(pattern)
  let normalized_candidate = normalize_cli_path(candidate)
  let (pattern_prefix, pattern_absolute, pattern_segments) = split_normalized_path(
    normalized_pattern,
  )
  let (candidate_prefix, candidate_absolute, candidate_segments) = split_normalized_path(
    normalized_candidate,
  )
  if pattern_prefix.length() > 0 && pattern_prefix != candidate_prefix {
    return false
  }
  if pattern_absolute != candidate_absolute {
    return false
  }
  glob_match_segments(pattern_segments, 0, candidate_segments, 0)
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

  let out = Array::new()
  let seen_out : Set[String] = Set::new()
  for pattern in patterns {
    let normalized_pattern = normalize_cli_path(pattern)
    for candidate in normalized_candidates {
      if glob_match(normalized_pattern, candidate) &&
        !seen_out.contains(candidate) {
        seen_out.add(candidate)
        out.push(candidate)
      }
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
