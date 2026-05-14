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
  let names = ["no-inline", "no-full-inline", "no-partial-inline"]
  for name in names {
    if flag.length() > name.length() &&
      flag.has_prefix(name) &&
      flag[name.length()] == '=' {
      let pattern = flag.sub(start=name.length() + 1).to_owned()
      if pattern.length() > 0 {
        return Some((name, pattern))
      }
    }
  }
  None
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
fn no_inline_wildcard_match(pattern : String, text : String) -> Bool {
  let width = text.length() + 1
  let cells = Array::make((pattern.length() + 1) * width, false)
  cells[0] = true
  let mut pi = 1
  while pi <= pattern.length() {
    let pc = pattern[pi - 1]
    let mut ti = 0
    while ti <= text.length() {
      let cell = pi * width + ti
      if pc == '*' {
        let zero = cells[(pi - 1) * width + ti]
        let more = ti > 0 && cells[pi * width + ti - 1]
        cells[cell] = zero || more
      } else if ti > 0 && (pc == '?' || pc == text[ti - 1]) {
        cells[cell] = cells[(pi - 1) * width + ti - 1]
      }
      ti += 1
    }
    pi += 1
  }
  cells[pattern.length() * width + text.length()]
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
          by_func[slot] = annotations
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
  let mut changed = false
  let mut idx = 0
  while idx < total {
    match names[idx] {
      Some(name) =>
        if no_inline_wildcard_match(pattern, name) {
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
      None => ()
    }
    idx += 1
  }
  if !changed {
    return mod_
  }
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
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
