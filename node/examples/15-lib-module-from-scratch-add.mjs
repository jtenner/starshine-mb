import { binary, lib, validate } from '../index.js';
import { expectOk } from './_shared.mjs';

const textEncoder = new TextEncoder();

function singleFunctionType(params, results) {
  return lib.TypeSec.new([
    lib.RecType.new(lib.compTypeSubType(lib.CompType.func(params, results))),
  ]);
}

const params = lib.resultType([lib.ValType.i32(), lib.ValType.i32()]);
const results = lib.resultType([lib.ValType.i32()]);
const typeSec = singleFunctionType(params, results);
const funcSec = lib.FuncSec.new([lib.TypeIdx.new(0)]);
const codeSec = lib.CodeSec.new([
  lib.Func.new(
    [],
    lib.Expr.new([
      lib.Instruction.localGet(lib.LocalIdx.new(0)),
      lib.Instruction.localGet(lib.LocalIdx.new(1)),
      lib.Instruction.i32Add(),
    ]),
  ),
]);
const exportSec = lib.ExportSec.new([
  lib.Export.new(
    lib.Name.fromString('add'),
    lib.ExternIdx.func(lib.FuncIdx.new(0)),
  ),
]);
const customSecs = [
  lib.CustomSec.new(
    lib.Name.fromString('built-by'),
    textEncoder.encode('starshine-node-example'),
  ),
];

let mod = lib.Module.new();
mod = lib.Module.withCustomSecs(mod, customSecs);
mod = lib.Module.withTypeSec(mod, typeSec);
mod = lib.Module.withFuncSec(mod, funcSec);
mod = lib.Module.withCodeSec(mod, codeSec);
mod = lib.Module.withExportSec(mod, exportSec);

expectOk(validate.validateModule(mod), 'validate.validateModule');
const bytes = expectOk(binary.encodeModule(mod), 'binary.encodeModule');
const decoded = expectOk(binary.decodeModule(bytes), 'binary.decodeModule');
expectOk(validate.validateModule(decoded), 'validate.validateModule(decoded)');

console.log(`module from scratch add: ${bytes.length} bytes, export=add`);
