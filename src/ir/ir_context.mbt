pub struct IRContext {
  mut mod_ : Module?
  mut body : TExpr
  mut locals : Array[ValType]
  mut type_ctx : Option[TypeContext]
  mut cfg : CFG?
  mut ssa : SSACFG?
  mut usedef : UseDefInfo?
  mut liveness : LivenessInfo?
  mut types : SSATypeInfo?
  mut gvn : SSACFG?
}

pub fn IRContext::new() -> Self {
  {
    mod_: None,
    body: TExpr::new([]),
    locals: [],
    type_ctx: None,
    cfg: None,
    ssa: None,
    usedef: None,
    liveness: None,
    types: None,
    gvn: None,
  }
}

pub fn IRContext::get_mod(self : Self) -> Module? {
  self.mod_
}

pub fn IRContext::set_body(self : Self, body : TExpr) -> Unit {
  self.body = body
  self.cfg_dirty()
}

pub fn IRContext::set_mod(self : Self, mod_ : @lib.Module) -> Unit {
  self.mod_ = Some(mod_)
  // Module change invalidates everything
  self.cfg_dirty()
}

// --------------- Lazy getters ---------------

pub fn IRContext::get_cfg(self : Self) -> CFG {
  match self.cfg {
    Some(val) => val
    None => {
      let cfg = build_cfg(self.body)
      self.cfg = Some(cfg)
      cfg
    }
  }
}

pub fn IRContext::get_ssa(self : Self) -> SSACFG {
  match self.ssa {
    Some(val) => val
    None => {
      let cfg = self.get_cfg()
      let doms = cfg.dominators()
      let df = cfg.dominance_frontier()
      let ssa = cfg_to_ssa(cfg, doms, df, self.locals.length())
      let ssa = split_critical_edges(ssa)
      self.ssa = Some(ssa)
      ssa
    }
  }
}

pub fn IRContext::get_usedef(self : Self) -> UseDefInfo {
  match self.usedef {
    Some(val) => val
    None => {
      let ssa = self.get_ssa()
      let ud = build_use_def(ssa)
      self.usedef = Some(ud)
      ud
    }
  }
}

pub fn IRContext::get_liveness(self : Self) -> LivenessInfo {
  match self.liveness {
    Some(val) => val
    None => {
      let ssa = self.get_ssa()
      let li = compute_liveness(ssa)
      self.liveness = Some(li)
      li
    }
  }
}

pub fn IRContext::get_types(self : Self) -> Option[SSATypeInfo] {
  match self.types {
    Some(val) => Some(val)
    None => {
      let ssa = self.get_ssa()
      let type_ctx = match self.type_ctx {
        Some(ctx) => ctx
        None => return None
      }
      let ti = infer_ssa_types(ssa, type_ctx)
      self.types = Some(ti)
      Some(ti)
    }
  }
}

pub fn IRContext::get_gvn(self : Self) -> SSACFG {
  match self.gvn {
    Some(val) => val
    None => {
      let ssa = self.get_ssa()
      let cfg = self.get_cfg()
      let doms = cfg.dominators()
      let optimized = run_gvn(ssa, doms)
      self.gvn = Some(optimized)
      optimized
    }
  }
}

// --------------- Cascading dirty flags ---------------

/// Invalidates CFG and everything downstream.
pub fn IRContext::cfg_dirty(self : Self) -> Unit {
  self.cfg = None
  self.ssa_dirty()
}

/// Invalidates SSA and everything that depends on it.
pub fn IRContext::ssa_dirty(self : Self) -> Unit {
  self.ssa = None
  self.usedef_dirty()
  self.liveness_dirty()
  self.types_dirty()
  self.gvn_dirty()
}

pub fn IRContext::usedef_dirty(self : Self) -> Unit {
  self.usedef = None
}

pub fn IRContext::liveness_dirty(self : Self) -> Unit {
  self.liveness = None
}

pub fn IRContext::types_dirty(self : Self) -> Unit {
  self.types = None
}

pub fn IRContext::gvn_dirty(self : Self) -> Unit {
  self.gvn = None
}

// --------------- Additional helpers ---------------

/// Lowers the (possibly GVN-optimized) SSA back to a CFG.
pub fn IRContext::lower_to_cfg(self : Self) -> CFG {
  let ssa = self.get_gvn()
  ssa_to_cfg(ssa, self.locals.length())
}

/// Applies GVN, replaces the cached SSA with the optimized version,
/// and invalidates downstream analyses so they're recomputed on demand.
pub fn IRContext::apply_gvn(self : Self) -> Unit {
  let optimized = self.get_gvn()
  self.ssa = Some(optimized)
  self.gvn = None
  // Downstream analyses were computed against the old SSA
  self.usedef = None
  self.liveness = None
  self.types = None
}

/// Validates the current CFG, returning an error string on failure.
pub fn IRContext::validate(self : Self) -> Result[Unit, String] {
  self.get_cfg().validate()
}

pub fn IRContext::set_locals(
  self : Self,
  locals : Array[ValType]
) -> Unit {
  self.locals = locals
  self.ssa_dirty()
}

fn extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

fn resolve_func_type(
  comp_types : Array[CompType],
  idx : TypeIdx
) -> FuncType {
  let i = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  match comp_types[i.reinterpret_as_int()] {
    FuncCompType(params, results) => FuncType::new(params, results)
    _ => abort("Expected func type at type index")
  }
}

pub fn TypeContext::from_module(
  mod_ : Module,
  locals : Array[ValType]
) -> TypeContext {
  // 1. Flatten type section into CompTypes indexed by type index
  let comp_types : Array[CompType] = []
  match mod_.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }

  // 2. Collect from imports first (imports precede locals in index space)
  let func_types : Array[FuncType] = []
  let global_types : Array[GlobalType] = []
  let table_types : Array[TableType] = []
  let tag_types : Array[TagType] = []
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          FuncExternType(type_idx) =>
            func_types.push(resolve_func_type(comp_types, type_idx))
          TableExternType(tt) => table_types.push(tt)
          GlobalExternType(gt) => global_types.push(gt)
          TagExternType(tt) => tag_types.push(tt)
          MemExternType(_) => ()
        }
      }
    None => ()
  }

  // 3. Local function types (func_sec maps func index -> type index)
  match mod_.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        func_types.push(resolve_func_type(comp_types, type_idx))
      }
    None => ()
  }

  // 4. Local globals
  match mod_.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(gt, _) = global
        global_types.push(gt)
      }
    None => ()
  }

  // 5. Local tables
  match mod_.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(tt, _) = table
        table_types.push(tt)
      }
    None => ()
  }

  // 6. Local tags
  match mod_.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        tag_types.push(tag)
      }
    None => ()
  }

  // 7. Extract struct and array types from the flattened type section
  let struct_types : Array[Array[FieldType]] = []
  let array_types : Array[FieldType] = []
  for comp_type in comp_types {
    match comp_type {
      StructCompType(fields) => struct_types.push(fields)
      ArrayCompType(field) => array_types.push(field)
      FuncCompType(_, _) => ()
    }
  }

  {
    func_types,
    global_types,
    table_types,
    struct_types,
    array_types,
    tag_types,
    local_types: locals,
  }
}

pub fn IRContext::get_type_ctx(self : Self) -> Result[TypeContext, String] {
  match self.type_ctx {
    Some(ctx) => Ok(ctx)
    None => {
      let mod_ = match self.get_mod() {
        None => return Err("No module set")
        Some(m) => m
      }
      let ctx = TypeContext::from_module(mod_, self.locals)
      self.type_ctx = Some(ctx)
      Ok(ctx)
    }
  }
}
