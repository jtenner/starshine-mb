///| Compact high-level bridge for Dewdrop's self-host compiler.

///|
/// It constructs typed Starshine facts and never exposes serialization.
pub fn module_with_dewdrop_compiler_facts(module_ : @lib.Module) -> @lib.Module {
  let builder = @representation.OptimizationFactsBuilder::new()
  builder.set_producer(@representation.ProducerInfo::new("dewdrop", "0.1.0"))
  let exported_functions : Map[UInt, Bool] = Map::default()
  let mut host_can_call_exports = false
  let mut host_can_mutate_exported_state = false
  match module_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_entry in exports {
        match export_entry {
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(function))) => {
            exported_functions[function] = true
            host_can_call_exports = true
          }
          @lib.Export(_, @lib.TableExternIdx(_))
          | @lib.Export(_, @lib.MemExternIdx(_))
          | @lib.Export(_, @lib.GlobalExternIdx(_)) =>
            host_can_mutate_exported_state = true
          _ => ()
        }
      }
    None => ()
  }
  builder.set_world(
    @representation.WorldFacts::closed_module(
      host_can_call_exports~,
      host_can_mutate_exported_state~,
    ),
  )
  let mut imported_functions = 0
  match module_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => imported_functions += 1
          _ => ()
        }
      }
    None => ()
  }
  let defined_functions = match module_.func_sec {
    Some(@lib.FuncSec(functions)) => functions.length()
    None => 0
  }
  let total_functions = imported_functions + defined_functions
  let broad_effects = @representation.EffectFacts::new(
    @representation.EffectMask::from_bits(0x7F_FFFFUL),
  )
  for function in 0..<total_functions {
    let host_callable = exported_functions.contains(
      function.reinterpret_as_uint(),
    )
    builder.add_function(
      @representation.FunctionFacts::new(
        function.reinterpret_as_uint(),
        effects=Some(broad_effects),
        boundary=Some(
          @representation.FunctionBoundaryFacts::new(
            false, false, host_callable,
          ),
        ),
      ),
    )
  }
  module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(builder.finish()),
  )
}
