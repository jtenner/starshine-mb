///|
// This cache belongs to one pipeline invocation. Function analysis and pass
// timers remain in a fresh HotPipelineModuleState for each pass.
priv struct HotPipelineModuleCache {
  mut source : @lib.Module?
  mut context : @ir.HotModuleContext?
}

///|
fn HotPipelineModuleCache::new() -> HotPipelineModuleCache {
  { source: None, context: None, }
}

///|
fn HotPipelineModuleCache::clear(self : HotPipelineModuleCache) -> Unit {
  self.source = None
  self.context = None
}

///|
fn HotPipelineModuleCache::advance(
  self : HotPipelineModuleCache,
  mod_ : @lib.Module,
) -> Unit {
  // Do not keep replaced function bodies or old metadata alive between passes.
  // Compatible contexts now refer to the current module; incompatible ones
  // release both the previous source and the derived tables immediately.
  if self.find(mod_) is None {
    self.clear()
  }
}

///|
fn[T] hot_pipeline_same_section(left : T?, right : T?) -> Bool {
  match (left, right) {
    (Some(left), Some(right)) => physical_equal(left, right)
    (None, None) => true
    _ => false
  }
}

///|
fn hot_pipeline_context_sections_unchanged(
  left : @lib.Module,
  right : @lib.Module,
) -> Bool {
  hot_pipeline_same_section(left.type_sec, right.type_sec) &&
  hot_pipeline_same_section(left.import_sec, right.import_sec) &&
  hot_pipeline_same_section(left.func_sec, right.func_sec) &&
  hot_pipeline_same_section(left.func_annotation_sec, right.func_annotation_sec) &&
  hot_pipeline_same_section(left.table_sec, right.table_sec) &&
  hot_pipeline_same_section(left.mem_sec, right.mem_sec) &&
  hot_pipeline_same_section(left.global_sec, right.global_sec) &&
  hot_pipeline_same_section(left.tag_sec, right.tag_sec) &&
  hot_pipeline_same_section(left.elem_sec, right.elem_sec) &&
  hot_pipeline_same_section(left.data_sec, right.data_sec)
}

///|
fn hot_pipeline_context_descriptor_mode_unchanged(
  original : @lib.Module,
  candidate : @lib.Module,
  context : @ir.HotModuleContext,
) -> Bool {
  if hot_pipeline_same_section(original.code_sec, candidate.code_sec) {
    return true
  }
  if context.uses_custom_descriptors {
    // A changed body can remove the last exact-reference construct. Types and
    // initializers usually prove this mode before the body scan is reached.
    return @lib.module_uses_custom_descriptors(candidate)
  }
  let changed : Array[@lib.Func] = []
  match (original.code_sec, candidate.code_sec) {
    (Some(@lib.CodeSec(before)), Some(@lib.CodeSec(after))) => {
      if before.length() != after.length() {
        return false
      }
      for idx = 0; idx < after.length(); idx = idx + 1 {
        if !physical_equal(before[idx], after[idx]) {
          changed.push(after[idx])
        }
      }
    }
    _ => return false
  }
  // The non-code sections have the same identities, and the old mode was
  // false. Only replaced functions can introduce descriptor instructions or
  // exact local/reference annotations.
  !@lib.module_uses_custom_descriptors(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(changed)),
  )
}

///|
fn HotPipelineModuleCache::find(
  self : HotPipelineModuleCache,
  mod_ : @lib.Module,
) -> @ir.HotModuleContext? {
  match (self.source, self.context) {
    (Some(original), Some(context)) =>
      if hot_pipeline_context_sections_unchanged(original, mod_) &&
        hot_pipeline_context_descriptor_mode_unchanged(original, mod_, context) {
        self.source = Some(mod_)
        Some(context)
      } else {
        None
      }
    _ => None
  }
}

///|
fn run_hot_pipeline_cached_imported_func_count(
  mod_ : @lib.Module,
  state : HotPipelineModuleState,
) -> Int32 {
  match state.imported_func_count {
    Some(count) => count
    None => {
      let count = run_hot_pipeline_imported_func_count(mod_)
      state.imported_func_count = Some(count)
      count
    }
  }
}

///|
fn run_hot_pipeline_cached_offset_sensitive_metadata(
  mod_ : @lib.Module,
  state : HotPipelineModuleState,
) -> Bool {
  match state.offset_sensitive_metadata {
    Some(found) => found
    None => {
      let found = pass_module_has_offset_sensitive_metadata(mod_)
      state.offset_sensitive_metadata = Some(found)
      found
    }
  }
}

///|
fn run_hot_pipeline_cached_assemblyscript_startup(
  mod_ : @lib.Module,
  state : HotPipelineModuleState,
) -> Bool {
  match state.assemblyscript_startup {
    Some(found) => found
    None => {
      let found = run_hot_pipeline_module_has_assemblyscript_startup_exported_memory(
        mod_,
      )
      state.assemblyscript_startup = Some(found)
      found
    }
  }
}

///|
fn run_hot_pipeline_cached_assemblyscript_run(
  mod_ : @lib.Module,
  state : HotPipelineModuleState,
) -> Bool {
  match state.assemblyscript_run {
    Some(found) => found
    None => {
      let found = run_hot_pipeline_module_has_assemblyscript_run_exported_memory_runtime(
        mod_,
      )
      state.assemblyscript_run = Some(found)
      found
    }
  }
}
