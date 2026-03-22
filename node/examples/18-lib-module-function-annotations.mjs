import { lib, validate } from '../index.js';

const typeSec = lib.TypeSec.new([
  lib.RecType.new(lib.compTypeSubType(lib.CompType.func([], []))),
]);
const funcSec = lib.FuncSec.new([lib.TypeIdx.new(0)]);
const codeSec = lib.CodeSec.new([
  lib.Func.new(lib.Locals.new([]), lib.Expr.new([])),
]);
const funcAnnotationSec = lib.FuncAnnotationSec.new([
  lib.FuncAnnotationAssoc.new(0, [
    lib.FuncAnnotation.new('binaryen.idempotent'),
    lib.FuncAnnotation.new('metadata.code.inline', ['"\\00"']),
  ]),
]);

const mod = lib.Module.new(
  [],
  typeSec,
  null,
  funcAnnotationSec,
  funcSec,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  codeSec,
  null,
);

if (!validate.validateModule(mod).ok) {
  throw new Error('validate.validateModule failed');
}

console.log(lib.Module.show(mod));
