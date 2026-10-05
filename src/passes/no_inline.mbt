///|
fn no_inline_no_full_annotation_name() -> String {
  "starshine.no-full-inline"
}

///|
fn no_inline_no_partial_annotation_name() -> String {
  "starshine.no-partial-inline"
}

///|
pub fn no_inline_summary() -> String {
  "Mark named functions as unavailable for full and partial inlining."
}

///|
pub fn no_full_inline_summary() -> String {
  "Mark named functions as unavailable for full inlining."
}

///|
pub fn no_partial_inline_summary() -> String {
  "Mark named functions as unavailable for partial inlining."
}

///|
pub fn no_inline_pass_pattern(flag : String) -> (String, String)? {
  match no_inline_pass_pattern_base(flag) {
    Some(name) => {
      let pattern = flag.sub(start=name.length() + 1).to_owned()
      if pattern.length() > 0 {
        Some((name, pattern))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn no_inline_pass_pattern_base(flag : String) -> String? {
  if no_inline_pass_pattern_has_base(flag, "no-inline") {
    return Some("no-inline")
  }
  if no_inline_pass_pattern_has_base(flag, "no-full-inline") {
    return Some("no-full-inline")
  }
  if no_inline_pass_pattern_has_base(flag, "no-partial-inline") {
    return Some("no-partial-inline")
  }
  None
}

///|
fn no_inline_pass_pattern_has_base(flag : String, name : String) -> Bool {
  flag.length() > name.length() &&
  flag[name.length()] == '=' &&
  flag.has_prefix(name)
}

///|
fn no_inline_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn no_inline_defined_func_count(mod_ : @lib.Module) -> Int {
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn no_inline_name_to_string(name : @lib.Name) -> String {
  let @lib.Name(text) = name
  text.to_owned()
}

///|
fn no_inline_func_names(mod_ : @lib.Module, total : Int) -> Array[String?] {
  let names : Array[String?] = Array::make(total, None)
  match mod_.name_sec {
    Some(name_sec) =>
      match name_sec.func_names {
        Some(@lib.NameMap(entries)) =>
          for entry in entries {
            let @lib.NameAssoc(raw_idx, name) = entry
            let idx = raw_idx.reinterpret_as_int()
            if idx >= 0 && idx < names.length() {
              names[idx] = Some(no_inline_name_to_string(name))
            }
          }
        None => ()
      }
    None => ()
  }
  names
}

///|
priv struct NoInlineWildcardProgram {
  pattern_length : Int
  word_count : Int
  literal_masks : Array[UInt64]
  question_masks : Array[UInt64]
  star_masks : Array[UInt64]
}

///|
fn no_inline_wildcard_set_bit(words : Array[UInt64], index : Int) -> Unit {
  let word_idx = index / 64
  words[word_idx] = words[word_idx] | (1UL << (index % 64))
}

///|
fn no_inline_wildcard_compile(pattern : String) -> NoInlineWildcardProgram {
  // Collapsing adjacent stars makes every epsilon closure one step while
  // preserving glob semantics.
  let mut pattern_length = 0
  let mut previous_star = false
  for pattern_idx = 0
      pattern_idx < pattern.length()
      pattern_idx = pattern_idx + 1 {
    let is_star = pattern[pattern_idx] == '*'
    if !is_star || !previous_star {
      pattern_length += 1
    }
    previous_star = is_star
  }
  let word_count = (pattern_length + 64) / 64
  let literal_masks = Array::make(256 * word_count, 0UL)
  let question_masks = Array::make(word_count, 0UL)
  let star_masks = Array::make(word_count, 0UL)
  let mut normalized_idx = 0
  previous_star = false
  for pattern_idx = 0
      pattern_idx < pattern.length()
      pattern_idx = pattern_idx + 1 {
    let pattern_byte = pattern[pattern_idx]
    let is_star = pattern_byte == '*'
    if !is_star || !previous_star {
      let word_idx = normalized_idx / 64
      let bit = 1UL << (normalized_idx % 64)
      if is_star {
        star_masks[word_idx] = star_masks[word_idx] | bit
      } else if pattern_byte == '?' {
        question_masks[word_idx] = question_masks[word_idx] | bit
      } else {
        let offset = pattern_byte.to_int() * word_count + word_idx
        literal_masks[offset] = literal_masks[offset] | bit
      }
      normalized_idx += 1
    }
    previous_star = is_star
  }
  { pattern_length, word_count, literal_masks, question_masks, star_masks, }
}

///|
fn no_inline_wildcard_match_compiled(
  program : NoInlineWildcardProgram,
  text : String,
  visits : Array[Int],
  first : Array[UInt64],
  second : Array[UInt64],
) -> Bool {
  for word_idx = 0; word_idx < program.word_count; word_idx = word_idx + 1 {
    first[word_idx] = 0UL
    second[word_idx] = 0UL
  }
  no_inline_wildcard_set_bit(first, 0)
  if (program.star_masks[0] & 1UL) != 0UL {
    no_inline_wildcard_set_bit(first, 1)
  }
  let mut current = first
  let mut next = second
  for text_idx = 0; text_idx < text.length(); text_idx = text_idx + 1 {
    // Advance every reachable NFA state in machine-word batches. Star states
    // consume in place; literal and question states advance by one bit.
    let literal_base = text[text_idx].to_int() * program.word_count
    let mut carry = 0UL
    for word_idx = 0; word_idx < program.word_count; word_idx = word_idx + 1 {
      visits[0] += 1
      let matched = current[word_idx] &
        (
          program.question_masks[word_idx] |
          program.literal_masks[literal_base + word_idx]
        )
      next[word_idx] = (current[word_idx] & program.star_masks[word_idx]) |
        (matched << 1) |
        carry
      carry = matched >> 63
    }
    carry = 0UL
    let mut any_reachable = false
    for word_idx = 0; word_idx < program.word_count; word_idx = word_idx + 1 {
      let stars = next[word_idx] & program.star_masks[word_idx]
      next[word_idx] = next[word_idx] | (stars << 1) | carry
      carry = stars >> 63
      any_reachable = any_reachable || next[word_idx] != 0UL
    }
    if !any_reachable {
      return false
    }
    let old = current
    current = next
    next = old
  }
  let accept_word = program.pattern_length / 64
  let accept_bit = 1UL << (program.pattern_length % 64)
  (current[accept_word] & accept_bit) != 0UL
}

///|
fn no_inline_wildcard_match_with_visits(
  pattern : String,
  text : String,
  visits : Array[Int],
) -> Bool {
  let program = no_inline_wildcard_compile(pattern)
  no_inline_wildcard_match_compiled(
    program,
    text,
    visits,
    Array::make(program.word_count, 0UL),
    Array::make(program.word_count, 0UL),
  )
}

///|
fn no_inline_wildcard_match(pattern : String, text : String) -> Bool {
  no_inline_wildcard_match_with_visits(pattern, text, [0])
}

///|
fn no_inline_annotation_present(
  annotations : Array[@lib.FuncAnnotation],
  name : String,
) -> Bool {
  for annotation in annotations {
    if annotation.name == name {
      return true
    }
  }
  false
}

///|
fn no_inline_append_annotation_once(
  annotations : Array[@lib.FuncAnnotation],
  name : String,
) -> Array[@lib.FuncAnnotation] {
  let out = annotations.copy()
  if !no_inline_annotation_present(out, name) {
    out.push(@lib.FuncAnnotation::new(name))
  }
  out
}

///|
fn no_inline_policy_annotations(
  annotations : Array[@lib.FuncAnnotation],
  mark_full : Bool,
  mark_partial : Bool,
) -> Array[@lib.FuncAnnotation] {
  let mut out = annotations
  if mark_full {
    out = no_inline_append_annotation_once(
      out,
      no_inline_no_full_annotation_name(),
    )
  }
  if mark_partial {
    out = no_inline_append_annotation_once(
      out,
      no_inline_no_partial_annotation_name(),
    )
  }
  out
}

///|
fn no_inline_existing_annotation_map(
  mod_ : @lib.Module,
  total : Int,
) -> Array[Array[@lib.FuncAnnotation]] {
  let by_func : Array[Array[@lib.FuncAnnotation]] = []
  let mut idx = 0
  while idx < total {
    by_func.push([])
    idx += 1
  }
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let slot = raw_idx.reinterpret_as_int()
        if slot >= 0 && slot < by_func.length() {
          let merged = by_func[slot].copy()
          for annotation in annotations {
            if !merged.contains(annotation) {
              merged.push(annotation)
            }
          }
          by_func[slot] = merged
        }
      }
    None => ()
  }
  by_func
}

///|
fn no_inline_build_annotation_sec(
  by_func : Array[Array[@lib.FuncAnnotation]],
) -> @lib.FuncAnnotationSec? {
  let entries : Array[@lib.FuncAnnotationAssoc] = []
  let mut idx = 0
  while idx < by_func.length() {
    if by_func[idx].length() > 0 {
      entries.push(
        @lib.FuncAnnotationAssoc::new(idx.reinterpret_as_uint(), by_func[idx]),
      )
    }
    idx += 1
  }
  if entries.length() == 0 {
    None
  } else {
    Some(@lib.FuncAnnotationSec::new(entries))
  }
}

///|
fn no_inline_run_module_pass(
  mod_ : @lib.Module,
  pattern : String,
  mark_full~ : Bool,
  mark_partial~ : Bool,
) -> @lib.Module {
  let total = no_inline_imported_func_count(mod_) +
    no_inline_defined_func_count(mod_)
  let names = no_inline_func_names(mod_, total)
  let by_func = no_inline_existing_annotation_map(mod_, total)
  let wildcard = no_inline_wildcard_compile(pattern)
  let wildcard_visits = [0]
  let wildcard_first = Array::make(wildcard.word_count, 0UL)
  let wildcard_second = Array::make(wildcard.word_count, 0UL)
  let mut changed = false
  let mut idx = 0
  while idx < total {
    // Binaryen assigns every function an internal name. Format the numeric
    // fallback only when no name-section entry exists for this function.
    let name = match names[idx] {
      Some(name) => name
      None => idx.to_string()
    }
    wildcard_visits[0] = 0
    if no_inline_wildcard_match_compiled(
        wildcard, name, wildcard_visits, wildcard_first, wildcard_second,
      ) {
      let next = no_inline_policy_annotations(
        by_func[idx],
        mark_full,
        mark_partial,
      )
      if next != by_func[idx] {
        by_func[idx] = next
        changed = true
      }
    }
    idx += 1
  }
  if !changed {
    return mod_
  }
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    compiler_fact_custom_section=mod_.compiler_fact_custom_section,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=no_inline_build_annotation_sec(by_func),
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=mod_.code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

///|

///|
fn no_inline_policy_annotation_name(annotation : @lib.FuncAnnotation) -> Bool {
  annotation.name == no_inline_no_full_annotation_name() ||
  annotation.name == no_inline_no_partial_annotation_name()
}

///|
pub fn no_inline_copy_policy_annotations(
  mod_ : @lib.Module,
  source_idx : UInt,
  target_idx : UInt,
) -> @lib.Module {
  let total = no_inline_imported_func_count(mod_) +
    no_inline_defined_func_count(mod_)
  let source = source_idx.reinterpret_as_int()
  let target = target_idx.reinterpret_as_int()
  if source < 0 || source >= total || target < 0 || target >= total {
    return mod_
  }
  let by_func = no_inline_existing_annotation_map(mod_, total)
  let mut changed = false
  for annotation in by_func[source] {
    if no_inline_policy_annotation_name(annotation) &&
      !no_inline_annotation_present(by_func[target], annotation.name) {
      by_func[target].push(annotation)
      changed = true
    }
  }
  if !changed {
    return mod_
  }
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    compiler_fact_custom_section=mod_.compiler_fact_custom_section,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=no_inline_build_annotation_sec(by_func),
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=mod_.code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

///|
fn no_inline_policy_flags(mod_ : @lib.Module) -> (Array[Bool], Array[Bool]) {
  let total = no_inline_imported_func_count(mod_) +
    no_inline_defined_func_count(mod_)
  let no_full = Array::make(total, false)
  let no_partial = Array::make(total, false)
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let slot = raw_idx.reinterpret_as_int()
        if slot >= 0 && slot < total {
          for annotation in annotations {
            if annotation.name == no_inline_no_full_annotation_name() {
              no_full[slot] = true
            } else if annotation.name == no_inline_no_partial_annotation_name() {
              no_partial[slot] = true
            }
          }
        }
      }
    None => ()
  }
  (no_full, no_partial)
}
