import { binary, lib, validate } from '../index.js';
import { expectOk } from './_shared.mjs';

function singleFunctionType(params, results) {
  return lib.TypeSec.new([
    lib.RecType.new(lib.compTypeSubType(lib.CompType.func(params, results))),
  ]);
}

const params = lib.resultType([lib.ValType.i32()]);
const results = lib.resultType([lib.ValType.i32()]);
const typeSec = singleFunctionType(params, results);
const funcSec = lib.FuncSec.new([lib.TypeIdx.new(0)]);
const codeSec = lib.CodeSec.new([
  lib.Func.new(
    [],
    lib.Expr.new([
      lib.Instruction.localGet(lib.LocalIdx.new(0)),
      lib.Instruction.i32Const(lib.I32.new(0)),
      lib.Instruction.i32GtS(),
      lib.Instruction.if(
        lib.BlockType.valType(lib.ValType.i32()),
        [lib.Instruction.localGet(lib.LocalIdx.new(0))],
        [lib.Instruction.i32Const(lib.I32.new(0))],
      ),
    ]),
  ),
]);
const exportSec = lib.ExportSec.new([
  lib.Export.new(
    lib.Name.fromString('clampNonNegative'),
    lib.ExternIdx.func(lib.FuncIdx.new(0)),
  ),
]);

let mod = lib.Module.new();
mod = lib.Module.withTypeSec(mod, typeSec);
mod = lib.Module.withFuncSec(mod, funcSec);
mod = lib.Module.withCodeSec(mod, codeSec);
mod = lib.Module.withExportSec(mod, exportSec);

expectOk(validate.validateModule(mod), 'validate.validateModule');
const bytes = expectOk(binary.encodeModule(mod), 'binary.encodeModule');
const decoded = expectOk(binary.decodeModule(bytes), 'binary.decodeModule');
expectOk(validate.validateModule(decoded), 'validate.validateModule(decoded)');

console.log(`module from scratch control flow: ${bytes.length} bytes, export=clampNonNegative`);
