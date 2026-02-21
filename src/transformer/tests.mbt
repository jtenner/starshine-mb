///|
test "change and unchanged helpers return expected transformer results" {
  match (change(7, 9) : TransformerResult[Int, Int]) {
    Ok(Some((state, value))) => {
      assert_eq(state, 7)
      assert_eq(value, 9)
    }
    _ => fail("expected change to return Some result")
  }
  match (unchanged() : TransformerResult[Int, Int]) {
    Ok(None) => ()
    _ => fail("expected unchanged to return None")
  }
}

///|
test "walk_module applies on_tinstruction rewrite" {
  let transformer = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    match instr {
      TLocalGet(LocalIdx(i)) if i == 0U =>
        change((), TInstr::local_get(LocalIdx::new(1)))
      _ => self.walk_tinstruction_default((), instr)
    }
  })
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::local_get(LocalIdx::new(0))])),
    ]),
  )
  let rewritten = match transformer.walk_module((), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => fail("expected transformed module")
    Err(e) => fail("unexpected walk_module error: \{e}")
  }
  match rewritten.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalGet(LocalIdx(i))]))])) =>
      assert_eq(i, 1U)
    _ => fail("expected local.get index rewrite")
  }
}

///|
test "walk_module forwards event errors" {
  let transformer = ModuleTransformer::new().on_tinstruction_evt(fn(
    _,
    _,
    instr,
  ) {
    match instr {
      TNop => error("boom")
      _ => unchanged()
    }
  })
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
  )
  match transformer.walk_module((), mod) {
    Ok(_) => fail("expected walk_module to return Err")
    Err(msg) => assert_eq(msg, "boom")
  }
}

///|
test "walk_module propagates on_module errors before traversal" {
  let mut visited_tinstruction = false
  let transformer = ModuleTransformer::new()
    .on_module_evt(fn(_, _, _) { error("module boom") })
    .on_tinstruction_evt(fn(_, _, _) {
      visited_tinstruction = true
      unchanged()
    })
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
  )
  match transformer.walk_module((), mod) {
    Ok(_) => fail("expected walk_module to return Err")
    Err(msg) => assert_eq(msg, "module boom")
  }
  assert_false(visited_tinstruction)
}

///|
test "walk_module falls through on_module Ok(None) to default traversal" {
  let mut module_hook_called = false
  let transformer = ModuleTransformer::new()
    .on_module_evt(fn(_, _, _) {
      module_hook_called = true
      unchanged()
    })
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr {
        TLocalGet(LocalIdx(i)) if i == 0U =>
          change((), TInstr::local_get(LocalIdx::new(2)))
        _ => self.walk_tinstruction_default((), instr)
      }
    })
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::local_get(LocalIdx::new(0))])),
    ]),
  )
  let rewritten = match transformer.walk_module((), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => fail("expected transformed module from fallback traversal")
    Err(e) => fail("unexpected walk_module error: \{e}")
  }
  assert_true(module_hook_called)
  match rewritten.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalGet(LocalIdx(i))]))])) =>
      assert_eq(i, 2U)
    _ => fail("expected local.get index rewrite from fallback traversal")
  }
}

///|
test "walk_module invokes on_module event hook" {
  let transformer = ModuleTransformer::new().on_module_evt(fn(_, _, mod) {
    change(
      (),
      mod.with_code_sec(
        CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
      ),
    )
  })
  let mod = Module::new()
  let rewritten = match transformer.walk_module((), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => fail("expected on_module rewrite result")
    Err(e) => fail("unexpected walk_module error: \{e}")
  }
  match rewritten.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TNop]))])) => ()
    _ => fail("expected on_module to inject rewritten code section")
  }
}

///|
test "section walkers dispatch corresponding section hooks" {
  let mut hit_module = false
  let mut hit_typesec = false
  let mut hit_funcsec = false
  let mut hit_tablesec = false
  let mut hit_memsec = false
  let mut hit_tagsec = false
  let mut hit_globalsec = false
  let mut hit_exportsec = false
  let mut hit_importsec = false
  let mut hit_startsec = false
  let mut hit_elemsec = false
  let mut hit_elemkind = false
  let mut hit_datacntsec = false
  let mut hit_codesec = false
  let mut hit_datasec = false
  let transformer = ModuleTransformer::new()
    .on_module_evt(fn(_, _, _) {
      hit_module = true
      unchanged()
    })
    .on_typesec_evt(fn(_, _, _) {
      hit_typesec = true
      unchanged()
    })
    .on_funcsec_evt(fn(_, _, _) {
      hit_funcsec = true
      unchanged()
    })
    .on_tablesec_evt(fn(_, _, _) {
      hit_tablesec = true
      unchanged()
    })
    .on_memsec_evt(fn(_, _, _) {
      hit_memsec = true
      unchanged()
    })
    .on_tagsec_evt(fn(_, _, _) {
      hit_tagsec = true
      unchanged()
    })
    .on_globalsec_evt(fn(_, _, _) {
      hit_globalsec = true
      unchanged()
    })
    .on_exportsec_evt(fn(_, _, _) {
      hit_exportsec = true
      unchanged()
    })
    .on_importsec_evt(fn(_, _, _) {
      hit_importsec = true
      unchanged()
    })
    .on_startsec_evt(fn(_, _, _) {
      hit_startsec = true
      unchanged()
    })
    .on_elemsec_evt(fn(_, _, _) {
      hit_elemsec = true
      unchanged()
    })
    .on_elemkind_evt(fn(_, _, _) {
      hit_elemkind = true
      unchanged()
    })
    .on_datacntsec_evt(fn(_, _, _) {
      hit_datacntsec = true
      unchanged()
    })
    .on_codesec_evt(fn(_, _, _) {
      hit_codesec = true
      unchanged()
    })
    .on_datasec_evt(fn(_, _, _) {
      hit_datasec = true
      unchanged()
    })
  ignore(transformer.walk_module((), Module::new()))
  ignore(transformer.walk_typesec((), TypeSec::new([])))
  ignore(transformer.walk_funcsec((), FuncSec::new([])))
  ignore(transformer.walk_tablesec((), TableSec::new([])))
  ignore(transformer.walk_memsec((), MemSec::new([])))
  ignore(transformer.walk_tagsec((), TagSec::new([])))
  ignore(transformer.walk_globalsec((), GlobalSec::new([])))
  ignore(transformer.walk_exportsec((), ExportSec::new([])))
  ignore(transformer.walk_importsec((), ImportSec::new([])))
  ignore(transformer.walk_startsec((), StartSec::new(FuncIdx::new(0))))
  ignore(transformer.walk_elemsec((), ElemSec::new([])))
  ignore(transformer.walk_elemkind((), ElemKind::funcs([])))
  ignore(transformer.walk_datacntsec((), DataCntSec::new(0)))
  ignore(transformer.walk_codesec((), CodeSec::new([])))
  ignore(transformer.walk_datasec((), DataSec::new([])))
  assert_true(hit_module)
  assert_true(hit_typesec)
  assert_true(hit_funcsec)
  assert_true(hit_tablesec)
  assert_true(hit_memsec)
  assert_true(hit_tagsec)
  assert_true(hit_globalsec)
  assert_true(hit_exportsec)
  assert_true(hit_importsec)
  assert_true(hit_startsec)
  assert_true(hit_elemsec)
  assert_true(hit_elemkind)
  assert_true(hit_datacntsec)
  assert_true(hit_codesec)
  assert_true(hit_datasec)
}

///|
test "core walkers dispatch corresponding hooks" {
  let mut hit_name = false
  let mut hit_funcidx = false
  let mut hit_typeidx = false
  let mut hit_laneidx = false
  let mut hit_localidx = false
  let mut hit_globalidx = false
  let mut hit_tableidx = false
  let mut hit_memidx = false
  let mut hit_labelidx = false
  let mut hit_dataidx = false
  let mut hit_elemidx = false
  let mut hit_tagidx = false
  let mut hit_unaryop = false
  let mut hit_binaryop = false
  let mut hit_storeop = false
  let mut hit_loadop = false
  let mut hit_extractlaneop = false
  let mut hit_replacelaneop = false
  let mut hit_v128shiftop = false
  let mut hit_v128ternaryop = false
  let mut hit_v128loadlaneop = false
  let mut hit_v128storelaneop = false
  let mut hit_memarg = false
  let mut hit_numtype = false
  let mut hit_heaptype = false
  let mut hit_reftype = false
  let mut hit_valtype = false
  let mut hit_blocktype = false
  let mut hit_limits = false
  let mut hit_memtype = false
  let mut hit_tagtype = false
  let mut hit_externtype = false
  let mut hit_externidx = false
  let mut hit_globaltype = false
  let mut hit_global = false
  let mut hit_export = false
  let mut hit_table = false
  let mut hit_storagetype = false
  let mut hit_fieldtype = false
  let mut hit_comptype = false
  let mut hit_subtype = false
  let mut hit_rectype = false
  let mut hit_locals = false
  let mut hit_func = false
  let mut hit_instruction = false
  let mut hit_tinstruction = false
  let mut hit_expr = false
  let mut hit_texpr = false
  let transformer = ModuleTransformer::new()
    .on_name_evt(fn(_, _, _) {
      hit_name = true
      unchanged()
    })
    .on_funcidx_evt(fn(_, _, _) {
      hit_funcidx = true
      unchanged()
    })
    .on_typeidx_evt(fn(_, _, _) {
      hit_typeidx = true
      unchanged()
    })
    .on_laneidx_evt(fn(_, _, _) {
      hit_laneidx = true
      unchanged()
    })
    .on_localidx_evt(fn(_, _, _) {
      hit_localidx = true
      unchanged()
    })
    .on_globalidx_evt(fn(_, _, _) {
      hit_globalidx = true
      unchanged()
    })
    .on_tableidx_evt(fn(_, _, _) {
      hit_tableidx = true
      unchanged()
    })
    .on_memidx_evt(fn(_, _, _) {
      hit_memidx = true
      unchanged()
    })
    .on_labelidx_evt(fn(_, _, _) {
      hit_labelidx = true
      unchanged()
    })
    .on_dataidx_evt(fn(_, _, _) {
      hit_dataidx = true
      unchanged()
    })
    .on_elemidx_evt(fn(_, _, _) {
      hit_elemidx = true
      unchanged()
    })
    .on_tagidx_evt(fn(_, _, _) {
      hit_tagidx = true
      unchanged()
    })
    .on_unaryop_evt(fn(_, _, _) {
      hit_unaryop = true
      unchanged()
    })
    .on_binaryop_evt(fn(_, _, _) {
      hit_binaryop = true
      unchanged()
    })
    .on_storeop_evt(fn(_, _, _) {
      hit_storeop = true
      unchanged()
    })
    .on_loadop_evt(fn(_, _, _) {
      hit_loadop = true
      unchanged()
    })
    .on_extractlaneop_evt(fn(_, _, _) {
      hit_extractlaneop = true
      unchanged()
    })
    .on_replacelaneop_evt(fn(_, _, _) {
      hit_replacelaneop = true
      unchanged()
    })
    .on_v128shiftop_evt(fn(_, _, _) {
      hit_v128shiftop = true
      unchanged()
    })
    .on_v128ternaryop_evt(fn(_, _, _) {
      hit_v128ternaryop = true
      unchanged()
    })
    .on_v128loadlaneop_evt(fn(_, _, _) {
      hit_v128loadlaneop = true
      unchanged()
    })
    .on_v128storelaneop_evt(fn(_, _, _) {
      hit_v128storelaneop = true
      unchanged()
    })
    .on_memarg_evt(fn(_, _, _) {
      hit_memarg = true
      unchanged()
    })
    .on_numtype_evt(fn(_, _, _) {
      hit_numtype = true
      unchanged()
    })
    .on_heaptype_evt(fn(_, _, _) {
      hit_heaptype = true
      unchanged()
    })
    .on_reftype_evt(fn(_, _, _) {
      hit_reftype = true
      unchanged()
    })
    .on_valtype_evt(fn(_, _, _) {
      hit_valtype = true
      unchanged()
    })
    .on_blocktype_evt(fn(_, _, _) {
      hit_blocktype = true
      unchanged()
    })
    .on_limits_evt(fn(_, _, _) {
      hit_limits = true
      unchanged()
    })
    .on_memtype_evt(fn(_, _, _) {
      hit_memtype = true
      unchanged()
    })
    .on_tagtype_evt(fn(_, _, _) {
      hit_tagtype = true
      unchanged()
    })
    .on_externtype_evt(fn(_, _, _) {
      hit_externtype = true
      unchanged()
    })
    .on_externidx_evt(fn(_, _, _) {
      hit_externidx = true
      unchanged()
    })
    .on_globaltype_evt(fn(_, _, _) {
      hit_globaltype = true
      unchanged()
    })
    .on_global_evt(fn(_, _, _) {
      hit_global = true
      unchanged()
    })
    .on_export_evt(fn(_, _, _) {
      hit_export = true
      unchanged()
    })
    .on_table_evt(fn(_, _, _) {
      hit_table = true
      unchanged()
    })
    .on_storagetype_evt(fn(_, _, _) {
      hit_storagetype = true
      unchanged()
    })
    .on_fieldtype_evt(fn(_, _, _) {
      hit_fieldtype = true
      unchanged()
    })
    .on_comptype_evt(fn(_, _, _) {
      hit_comptype = true
      unchanged()
    })
    .on_subtype_evt(fn(_, _, _) {
      hit_subtype = true
      unchanged()
    })
    .on_rectype_evt(fn(_, _, _) {
      hit_rectype = true
      unchanged()
    })
    .on_locals_evt(fn(_, _, _) {
      hit_locals = true
      unchanged()
    })
    .on_func_evt(fn(_, _, _) {
      hit_func = true
      unchanged()
    })
    .on_instruction_evt(fn(_, _, _) {
      hit_instruction = true
      unchanged()
    })
    .on_tinstruction_evt(fn(_, _, _) {
      hit_tinstruction = true
      unchanged()
    })
    .on_expr_evt(fn(_, _, _) {
      hit_expr = true
      unchanged()
    })
    .on_texpr_evt(fn(_, _, _) {
      hit_texpr = true
      unchanged()
    })
  let memarg = MemArg::new(0, None, 0)
  let heap_type = HeapType::new(TypeIdx::new(0))
  let ref_type = RefType::new(true, heap_type)
  let limits = Limits::i32(0, None)
  let global_type = GlobalType::new(ValType::i32(), true)
  ignore(transformer.walk_name((), Name::new("x")))
  ignore(transformer.walk_funcidx((), FuncIdx::new(0)))
  ignore(transformer.walk_typeidx((), TypeIdx::new(0)))
  ignore(transformer.walk_laneidx((), LaneIdx::new(0)))
  ignore(transformer.walk_localidx((), LocalIdx::new(0)))
  ignore(transformer.walk_globalidx((), GlobalIdx::new(0)))
  ignore(transformer.walk_tableidx((), TableIdx::new(0)))
  ignore(transformer.walk_memidx((), MemIdx::new(0)))
  ignore(transformer.walk_labelidx((), LabelIdx::new(0)))
  ignore(transformer.walk_dataidx((), DataIdx::new(0)))
  ignore(transformer.walk_elemidx((), ElemIdx::new(0)))
  ignore(transformer.walk_tagidx((), TagIdx::new(0)))
  ignore(transformer.walk_unaryop((), UnaryOp::i32_eqz()))
  ignore(transformer.walk_binaryop((), BinaryOp::i32_add()))
  ignore(transformer.walk_storeop((), StoreOp::i32_store()))
  ignore(transformer.walk_loadop((), LoadOp::i32_load()))
  ignore(
    transformer.walk_extractlaneop((), ExtractLaneOp::i8x16_extract_lane_s()),
  )
  ignore(
    transformer.walk_replacelaneop((), ReplaceLaneOp::i8x16_replace_lane()),
  )
  ignore(transformer.walk_v128shiftop((), V128ShiftOp::i8x16_shl()))
  ignore(transformer.walk_v128ternaryop((), V128TernaryOp::v128_bitselect()))
  ignore(transformer.walk_v128loadlaneop((), V128LoadLaneOp::v128_load8_lane()))
  ignore(
    transformer.walk_v128storelaneop((), V128StoreLaneOp::v128_store8_lane()),
  )
  ignore(transformer.walk_memarg((), memarg))
  ignore(transformer.walk_numtype((), NumType::i32()))
  ignore(transformer.walk_heaptype((), heap_type))
  ignore(transformer.walk_reftype((), ref_type))
  ignore(transformer.walk_valtype((), ValType::i32()))
  ignore(transformer.walk_blocktype((), BlockType::void_()))
  ignore(transformer.walk_limits((), limits))
  ignore(transformer.walk_memtype((), MemType::new(limits)))
  ignore(transformer.walk_tagtype((), TagType::new(TypeIdx::new(0))))
  ignore(transformer.walk_externtype((), ExternType::func(TypeIdx::new(0))))
  ignore(transformer.walk_externidx((), ExternIdx::func(FuncIdx::new(0))))
  ignore(transformer.walk_globaltype((), global_type))
  ignore(
    transformer.walk_global(
      (),
      Global::new(global_type, Expr::new([Instruction::nop()])),
    ),
  )
  ignore(
    transformer.walk_export(
      (),
      Export::new(Name::new("e"), ExternIdx::func(FuncIdx::new(0))),
    ),
  )
  ignore(
    transformer.walk_table(
      (),
      Table::new(TableType::new(ref_type, limits), None),
    ),
  )
  ignore(
    transformer.walk_storagetype((), StorageType::val_type(ValType::i32())),
  )
  ignore(
    transformer.walk_fieldtype(
      (),
      FieldType::new(StorageType::val_type(ValType::i32()), Const),
    ),
  )
  ignore(transformer.walk_comptype((), CompType::func([], [])))
  ignore(
    transformer.walk_subtype((), SubType::comp_type(CompType::func([], []))),
  )
  ignore(
    transformer.walk_rectype(
      (),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ),
  )
  ignore(transformer.walk_locals((), [Locals::new(1, ValType::i32())]))
  ignore(
    transformer.walk_func((), Func::t_func([], TExpr::new([TInstr::nop()]))),
  )
  ignore(transformer.walk_instruction((), Instruction::nop()))
  ignore(transformer.walk_tinstruction((), TInstr::nop()))
  ignore(transformer.walk_expr((), Expr::new([Instruction::nop()])))
  ignore(transformer.walk_texpr((), TExpr::new([TInstr::nop()])))
  assert_true(hit_name)
  assert_true(hit_funcidx)
  assert_true(hit_typeidx)
  assert_true(hit_laneidx)
  assert_true(hit_localidx)
  assert_true(hit_globalidx)
  assert_true(hit_tableidx)
  assert_true(hit_memidx)
  assert_true(hit_labelidx)
  assert_true(hit_dataidx)
  assert_true(hit_elemidx)
  assert_true(hit_tagidx)
  assert_true(hit_unaryop)
  assert_true(hit_binaryop)
  assert_true(hit_storeop)
  assert_true(hit_loadop)
  assert_true(hit_extractlaneop)
  assert_true(hit_replacelaneop)
  assert_true(hit_v128shiftop)
  assert_true(hit_v128ternaryop)
  assert_true(hit_v128loadlaneop)
  assert_true(hit_v128storelaneop)
  assert_true(hit_memarg)
  assert_true(hit_numtype)
  assert_true(hit_heaptype)
  assert_true(hit_reftype)
  assert_true(hit_valtype)
  assert_true(hit_blocktype)
  assert_true(hit_limits)
  assert_true(hit_memtype)
  assert_true(hit_tagtype)
  assert_true(hit_externtype)
  assert_true(hit_externidx)
  assert_true(hit_globaltype)
  assert_true(hit_global)
  assert_true(hit_export)
  assert_true(hit_table)
  assert_true(hit_storagetype)
  assert_true(hit_fieldtype)
  assert_true(hit_comptype)
  assert_true(hit_subtype)
  assert_true(hit_rectype)
  assert_true(hit_locals)
  assert_true(hit_func)
  assert_true(hit_instruction)
  assert_true(hit_tinstruction)
  assert_true(hit_expr)
  assert_true(hit_texpr)
}

///|
test "walk_tinstruction dispatches less-used variant callbacks" {
  let mut memarg_hits = 0
  let mut heaptype_hits = 0
  let mut labelidx_hits = 0
  let mut typeidx_hits = 0
  let mut elemidx_hits = 0
  let mut laneidx_hits = 0
  let transformer = ModuleTransformer::new()
    .on_memarg_evt(fn(_, _, _) {
      memarg_hits += 1
      unchanged()
    })
    .on_heaptype_evt(fn(_, _, _) {
      heaptype_hits += 1
      unchanged()
    })
    .on_labelidx_evt(fn(_, _, _) {
      labelidx_hits += 1
      unchanged()
    })
    .on_typeidx_evt(fn(_, _, _) {
      typeidx_hits += 1
      unchanged()
    })
    .on_elemidx_evt(fn(_, _, _) {
      elemidx_hits += 1
      unchanged()
    })
    .on_laneidx_evt(fn(_, _, _) {
      laneidx_hits += 1
      unchanged()
    })
  let memarg = MemArg::new(0, None, 0)
  let ht0 = HeapType::new(TypeIdx::new(0))
  let ht1 = HeapType::new(TypeIdx::new(1))
  let i0 = TInstr::i32_const(I32(10))
  let i1 = TInstr::i32_const(I32(11))
  let i2 = TInstr::i32_const(I32(12))
  let i3 = TInstr::i32_const(I32(13))
  let i4 = TInstr::i32_const(I32(14))
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::memory_atomic_wait64(memarg, i0, i1, i2),
    ),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::atomic_cmpxchg(AtomicCmpxchgOp::i32(), memarg, i0, i1, i2),
    ),
  )
  ignore(
    transformer.walk_tinstruction((), TInstr::ref_cast_desc_eq(true, ht0, i0)),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::br_on_cast_fail(
        LabelIdx::new(0),
        false,
        ht0,
        true,
        ht1,
        TInstr::local_get(LocalIdx::new(0)),
        [TInstr::i32_const(I32(1))],
      ),
    ),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::array_copy(TypeIdx::new(0), TypeIdx::new(1), i0, i1, i2, i3, i4),
    ),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::array_init_elem(TypeIdx::new(0), ElemIdx::new(0), i0, i1, i2, i3),
    ),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::v128_load_lane(
        V128LoadLaneOp::v128_load8_lane(),
        memarg,
        LaneIdx::new(0),
        i0,
        i1,
      ),
    ),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::v128_store_lane(
        V128StoreLaneOp::v128_store8_lane(),
        memarg,
        LaneIdx::new(1),
        i0,
        i1,
      ),
    ),
  )
  ignore(
    transformer.walk_tinstruction(
      (),
      TInstr::i8x16_shuffle(
        LaneIdx::new(0),
        LaneIdx::new(1),
        LaneIdx::new(2),
        LaneIdx::new(3),
        LaneIdx::new(4),
        LaneIdx::new(5),
        LaneIdx::new(6),
        LaneIdx::new(7),
        LaneIdx::new(8),
        LaneIdx::new(9),
        LaneIdx::new(10),
        LaneIdx::new(11),
        LaneIdx::new(12),
        LaneIdx::new(13),
        LaneIdx::new(14),
        LaneIdx::new(15),
        i0,
        i1,
      ),
    ),
  )
  assert_true(memarg_hits >= 4)
  assert_true(heaptype_hits >= 3)
  assert_true(labelidx_hits >= 1)
  assert_true(typeidx_hits >= 4)
  assert_true(elemidx_hits >= 1)
  assert_true(laneidx_hits >= 18)
}

///|
test "walk_tinstruction forwards callback errors for less-used variants" {
  let memarg_error = ModuleTransformer::new().on_memarg_evt(fn(_, _, _) {
    error("memarg boom")
  })
  match
    memarg_error.walk_tinstruction(
      (),
      TInstr::memory_atomic_wait64(
        MemArg::new(0, None, 0),
        TInstr::i32_const(I32(1)),
        TInstr::i64_const(I64(2)),
        TInstr::i64_const(I64(3)),
      ),
    ) {
    Err(msg) => assert_eq(msg, "memarg boom")
    _ => fail("expected memarg hook error to propagate")
  }

  let label_error = ModuleTransformer::new().on_labelidx_evt(fn(_, _, _) {
    error("label boom")
  })
  match
    label_error.walk_tinstruction(
      (),
      TInstr::br_on_cast_fail(
        LabelIdx::new(0),
        false,
        HeapType::new(TypeIdx::new(0)),
        true,
        HeapType::new(TypeIdx::new(1)),
        TInstr::local_get(LocalIdx::new(0)),
        [TInstr::i32_const(I32(1))],
      ),
    ) {
    Err(msg) => assert_eq(msg, "label boom")
    _ => fail("expected label hook error to propagate")
  }

  let lane_error = ModuleTransformer::new().on_laneidx_evt(fn(_, _, _) {
    error("lane boom")
  })
  match
    lane_error.walk_tinstruction(
      (),
      TInstr::i8x16_shuffle(
        LaneIdx::new(0),
        LaneIdx::new(1),
        LaneIdx::new(2),
        LaneIdx::new(3),
        LaneIdx::new(4),
        LaneIdx::new(5),
        LaneIdx::new(6),
        LaneIdx::new(7),
        LaneIdx::new(8),
        LaneIdx::new(9),
        LaneIdx::new(10),
        LaneIdx::new(11),
        LaneIdx::new(12),
        LaneIdx::new(13),
        LaneIdx::new(14),
        LaneIdx::new(15),
        TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        TInstr::v128_const(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
      ),
    ) {
    Err(msg) => assert_eq(msg, "lane boom")
    _ => fail("expected lane hook error to propagate")
  }
}

///|
test "walk_tinstruction preserves array_copy final operand when unchanged" {
  let transformer = ModuleTransformer::new()
  let i0 = TInstr::i32_const(I32(10))
  let i1 = TInstr::i32_const(I32(11))
  let i2 = TInstr::i32_const(I32(12))
  let i3 = TInstr::i32_const(I32(13))
  let i4 = TInstr::i32_const(I32(14))
  let instr = TInstr::array_copy(
    TypeIdx::new(0),
    TypeIdx::new(1),
    i0,
    i1,
    i2,
    i3,
    i4,
  )
  let rewritten = match transformer.walk_tinstruction((), instr) {
    Ok(Some((_, out))) => out
    Ok(None) => fail("expected walk_tinstruction to rebuild array_copy")
    Err(e) => fail("unexpected walk_tinstruction error: \{e}")
  }
  match rewritten {
    TArrayCopy(_, _, _, _, _, _, got_i4) =>
      assert_eq(got_i4, TInstr::i32_const(I32(14)))
    _ => fail("expected rewritten array_copy")
  }
}
