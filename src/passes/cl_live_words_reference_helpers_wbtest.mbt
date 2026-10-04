///|
fn cl_replace_live(live : Array[Bool], source : Array[Bool]) -> Unit {
  for idx = 0; idx < live.length(); idx = idx + 1 {
    live[idx] = idx < source.length() && source[idx]
  }
}

///|
fn cl_clear_live(live : Array[Bool]) -> Unit {
  for idx = 0; idx < live.length(); idx = idx + 1 {
    live[idx] = false
  }
}

///|
fn cl_union_live_in_place(live : Array[Bool], rhs : Array[Bool]) -> Unit {
  for idx = 0; idx < live.length(); idx = idx + 1 {
    if idx < rhs.length() {
      live[idx] = live[idx] || rhs[idx]
    }
  }
}

///|
fn cl_push_label_live(
  label_live : Array[Bool],
  label_lives : Array[Array[Bool]],
) -> Array[Array[Bool]] {
  let out : Array[Array[Bool]] = [label_live.copy()]
  for live in label_lives {
    out.push(live)
  }
  out
}

///|
fn cl_live_for_label(
  label_lives : Array[Array[Bool]],
  label_idx : @lib.LabelIdx,
  total_locals : Int,
) -> Array[Bool] {
  let depth = cl_label_idx_raw(label_idx)
  if depth >= 0 && depth < label_lives.length() {
    return label_lives[depth].copy()
  }
  Array::make(total_locals, false)
}

///|
fn cl_live_for_br_table(
  label_lives : Array[Array[Bool]],
  labels : Array[@lib.LabelIdx],
  default_label : @lib.LabelIdx,
  total_locals : Int,
) -> Array[Bool] {
  let out = cl_live_for_label(label_lives, default_label, total_locals)
  for label in labels {
    cl_union_live_in_place(
      out,
      cl_live_for_label(label_lives, label, total_locals),
    )
  }
  out
}

///|
fn cl_union_resume_handler_lives(
  live : Array[Bool],
  label_lives : Array[Array[Bool]],
  handlers : Array[@lib.ResumeHandler],
) -> Unit {
  for handler in handlers {
    match handler {
      @lib.ResumeOnLabel(_, label) =>
        cl_union_live_in_place(
          live,
          cl_live_for_label(label_lives, label, live.length()),
        )
      @lib.ResumeOnSwitch(_) => ()
    }
  }
}
