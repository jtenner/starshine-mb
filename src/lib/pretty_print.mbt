///|
pub enum TabsOrSpaces {
  Tabs
  Spaces
} derive(Eq, Show, Debug)

///|
pub fn TabsOrSpaces::tabs() -> TabsOrSpaces {
  Tabs
}

///|
pub fn TabsOrSpaces::spaces() -> TabsOrSpaces {
  Spaces
}

///|
pub struct PrettyPrintContext {
  max_line_width : UInt
  tabs_or_spaces : TabsOrSpaces
  tab_width : UInt
  continuation_indent : UInt
  source_indent_width : UInt
} derive(Eq, Show, Debug)

///|
pub fn PrettyPrintContext::new(
  max_line_width? : UInt = 100U,
  tabs_or_spaces? : TabsOrSpaces = Spaces,
  tab_width? : UInt = 2U,
  continuation_indent? : UInt = 1U,
  source_indent_width? : UInt = 2U,
) -> PrettyPrintContext {
  PrettyPrintContext::{
    max_line_width,
    tabs_or_spaces,
    tab_width,
    continuation_indent,
    source_indent_width,
  }
}

///|
pub fn PrettyPrintContext::indent_unit(self : PrettyPrintContext) -> String {
  match self.tabs_or_spaces {
    Tabs => "\t"
    Spaces => {
      let width = if self.tab_width == 0U { 1U } else { self.tab_width }
      " ".repeat(width.reinterpret_as_int())
    }
  }
}

///|
pub fn PrettyPrintContext::indent(
  self : PrettyPrintContext,
  level : UInt,
) -> String {
  let out = StringBuilder::new()
  let unit = self.indent_unit()
  let mut i = 0
  while i < level.reinterpret_as_int() {
    out.write_string(unit)
    i += 1
  }
  out.to_string()
}

///|
fn wrap_line(line : String, ctx : PrettyPrintContext) -> String {
  let max_width = ctx.max_line_width.reinterpret_as_int()
  if max_width == 0 || line.length() <= max_width {
    return line
  }

  let mut leading = 0
  while leading < line.length() {
    let c = line[leading]
    if c == ' ' || c == '\t' {
      leading += 1
    } else {
      break
    }
  }
  let prefix = line.sub(end=leading).to_string() catch { _ => "" }
  let body = line.sub(start=leading).to_string() catch { _ => line }
  if body.length() == 0 {
    return line
  }

  let words = body.split(" ")
  let out = StringBuilder::new()
  let continuation_prefix = prefix + ctx.indent(ctx.continuation_indent)
  let mut current_prefix = prefix
  out.write_string(current_prefix)
  let mut current_width = current_prefix.length()
  let mut has_word = false

  for word_view in words {
    let word = word_view.to_string()
    if word.length() == 0 {
      continue
    }
    let word_width = word.length()
    let needs_space = has_word
    let mut next_width = current_width + word_width
    if needs_space {
      next_width += 1
    }
    if needs_space && next_width > max_width {
      out.write_char('\n')
      current_prefix = continuation_prefix
      out.write_string(current_prefix)
      current_width = current_prefix.length()
      has_word = false
    }
    if has_word {
      out.write_char(' ')
      current_width += 1
    }
    out.write_string(word)
    current_width += word_width
    has_word = true
  }

  out.to_string()
}

///|
fn normalize_indent(line : String, ctx : PrettyPrintContext) -> String {
  let mut leading = 0
  let mut spaces = 0
  let mut tabs = 0
  while leading < line.length() {
    let c = line[leading]
    if c == ' ' {
      spaces += 1
      leading += 1
    } else if c == '\t' {
      tabs += 1
      leading += 1
    } else {
      break
    }
  }
  if leading == 0 {
    return line
  }
  let source_unit = if ctx.source_indent_width == 0U {
    1
  } else {
    ctx.source_indent_width.reinterpret_as_int()
  }
  let levels = tabs + spaces / source_unit
  let content = line.sub(start=leading).to_string() catch { _ => line }
  ctx.indent(levels.reinterpret_as_uint()) + content
}

///|
pub fn apply_pretty_context(text : String, ctx : PrettyPrintContext) -> String {
  let out = StringBuilder::new()
  let mut first = true
  for line in text.split("\n") {
    if !first {
      out.write_char('\n')
    }
    out.write_string(wrap_line(normalize_indent(line.to_string(), ctx), ctx))
    first = false
  }
  out.to_string()
}

///|
pub(open) trait PrettyPrint {
  pretty_print(Self, PrettyPrintContext) -> String
}

///|
#callsite(autofill(args_loc, loc))
pub fn inspect_debug(
  obj : &Debug,
  content? : String = "",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise InspectError {
  debug_inspect(obj, content~, loc~, args_loc~)
}

///|
#callsite(autofill(args_loc, loc))
pub fn[T : PrettyPrint] inspect_pretty_print(
  obj : T,
  content? : String = "",
  ctx? : PrettyPrintContext = PrettyPrintContext::new(),
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise InspectError {
  inspect(obj.pretty_print(ctx), content~, loc~, args_loc~)
}
