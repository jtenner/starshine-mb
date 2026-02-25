///|
struct ReadmeApiVerifyBlock {
  interface_path : String
  signatures : Array[String]
} derive(Eq, Show, Debug)

///|
fn ReadmeApiVerifyBlock::new(
  interface_path : String,
  signatures : Array[String],
) -> ReadmeApiVerifyBlock {
  { interface_path, signatures }
}

///|
fn ras_has_prefix(text : String, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  let head = text.sub(end=prefix.length()).to_string() catch { _ => "" }
  head == prefix
}

///|
fn ras_has_suffix(text : String, suffix : String) -> Bool {
  if text.length() < suffix.length() {
    return false
  }
  let start = text.length() - suffix.length()
  let tail = text.sub(start~).to_string() catch { _ => "" }
  tail == suffix
}

///|
fn ras_extract_marker_path(line : String) -> String? {
  let marker = line.trim().to_string()
  let prefix = "<!-- README_API_VERIFY "
  let suffix = " -->"
  if !ras_has_prefix(marker, prefix) {
    return None
  }
  if !ras_has_suffix(marker, suffix) {
    return None
  }
  let start = prefix.length()
  let end = marker.length() - suffix.length()
  if end <= start {
    return None
  }
  let path = marker.sub(start~, end~).to_string() catch { _ => "" }
  let normalized = path.trim().to_string()
  if normalized.length() == 0 {
    None
  } else {
    Some(normalized)
  }
}

///|
fn ras_join_lines_impl(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < lines.length() {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
    i += 1
  }
  out.to_string()
}

///|
fn parse_readme_api_verify_blocks(
  readme_text : String,
) -> Result[Array[ReadmeApiVerifyBlock], String] {
  let lines : Array[String] = []
  for line in readme_text.split("\n") {
    lines.push(line.to_string())
  }
  let blocks : Array[ReadmeApiVerifyBlock] = []
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    match ras_extract_marker_path(line) {
      Some(interface_path) => {
        i += 1
        while i < lines.length() && lines[i].trim().to_string().length() == 0 {
          i += 1
        }
        if i >= lines.length() || lines[i].trim().to_string() != "```mbti" {
          return Err(
            "README_API_VERIFY marker for \{interface_path} must be followed by a ```mbti code block",
          )
        }
        i += 1
        let signatures : Array[String] = []
        while i < lines.length() {
          let sig = lines[i].trim().to_string()
          if sig == "```" {
            break
          }
          if sig.length() > 0 {
            signatures.push(sig)
          }
          i += 1
        }
        if i >= lines.length() {
          return Err(
            "README_API_VERIFY marker for \{interface_path} has an unterminated code block",
          )
        }
        if signatures.length() == 0 {
          return Err(
            "README_API_VERIFY marker for \{interface_path} has no signatures",
          )
        }
        blocks.push(ReadmeApiVerifyBlock::new(interface_path, signatures))
      }
      None => ()
    }
    i += 1
  }
  if blocks.length() == 0 {
    return Err("README contains no README_API_VERIFY blocks")
  }
  Ok(blocks)
}

///|
fn ras_find_interface_text(
  interface_text_by_path : Array[(String, String)],
  path : String,
) -> String? {
  for pair in interface_text_by_path {
    if pair.0 == path {
      return Some(pair.1)
    }
  }
  None
}

///|
pub fn verify_readme_api_signatures(
  readme_text : String,
  interface_text_by_path : Array[(String, String)],
) -> Result[Unit, String] {
  let blocks = match parse_readme_api_verify_blocks(readme_text) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let diagnostics : Array[String] = []
  for block in blocks {
    let interface_text = match
      ras_find_interface_text(interface_text_by_path, block.interface_path) {
      Some(v) => v
      None => {
        diagnostics.push(
          "missing interface file for README_API_VERIFY block: \{block.interface_path}",
        )
        continue
      }
    }
    for signature in block.signatures {
      if !interface_text.contains(signature) {
        diagnostics.push(
          "missing signature in \{block.interface_path}: \{signature}",
        )
      }
    }
  }
  if diagnostics.length() == 0 {
    Ok(())
  } else {
    Err(ras_join_lines_impl(diagnostics))
  }
}
