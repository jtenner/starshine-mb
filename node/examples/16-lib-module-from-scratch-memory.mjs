import { binary, lib, validate } from '../index.js';
import { expectOk } from './_shared.mjs';

function singleFunctionType(params, results) {
  return lib.TypeSec.new([
    lib.RecType.new(lib.compTypeSubType(lib.CompType.func(params, results))),
  ]);
}

const typeSec = singleFunctionType([], lib.resultType([lib.ValType.i32()]));
const funcSec = lib.FuncSec.new([lib.TypeIdx.new(0)]);
const memSec = lib.MemSec.new([
  lib.MemType.new(lib.Limits.i32(1, null)),
]);
const dataSec = lib.DataSec.new([
  lib.Data.new(
    lib.DataMode.active(
      lib.MemIdx.new(0),
      lib.Expr.new([lib.Instruction.i32Const(lib.I32.new(0))]),
    ),
    new Uint8Array([65, 66, 67]),
  ),
]);
const codeSec = lib.CodeSec.new([
  lib.Func.new(
    [],
    lib.Expr.new([
      lib.Instruction.i32Const(lib.I32.new(0)),
      lib.Instruction.i32Load8u(
        lib.MemArg.new(lib.U32.new(0), null, lib.U64.new(1n)),
      ),
    ]),
  ),
]);
const exportSec = lib.ExportSec.new([
  lib.Export.new(
    lib.Name.fromString('loadSecondByte'),
    lib.ExternIdx.func(lib.FuncIdx.new(0)),
  ),
]);

let mod = lib.Module.new();
mod = lib.Module.withTypeSec(mod, typeSec);
mod = lib.Module.withFuncSec(mod, funcSec);
mod = lib.Module.withMemSec(mod, memSec);
mod = lib.Module.withCodeSec(mod, codeSec);
mod = lib.Module.withDataSec(mod, dataSec);
mod = lib.Module.withExportSec(mod, exportSec);

expectOk(validate.validateModule(mod), 'validate.validateModule');
const bytes = expectOk(binary.encodeModule(mod), 'binary.encodeModule');
const decoded = expectOk(binary.decodeModule(bytes), 'binary.decodeModule');
expectOk(validate.validateModule(decoded), 'validate.validateModule(decoded)');

console.log(`module from scratch memory: ${bytes.length} bytes, expectedByte=66`);
