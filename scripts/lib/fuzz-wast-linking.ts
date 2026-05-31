export function buildTypeMismatchImportUnlinkableWast(): string {
  return [
    `(module $provider`,
    `  (func $value (export "value") (result i32) i32.const 7)`,
    `)`,
    `(register "provider" $provider)`,
    `(assert_unlinkable`,
    `  (module $consumer`,
    `    (import "provider" "value" (func $value (param i32) (result i32)))`,
    `    (func (export "read") (result i32)`,
    `      i32.const 0`,
    `      call $value)`,
    `  )`,
    `  "incompatible import type")`,
    ``,
  ].join("\n");
}

export function buildMissingImportUnlinkableWast(): string {
  return [
    `(assert_unlinkable`,
    `  (module $consumer`,
    `    (import "missing" "value" (func $value (result i32)))`,
    `    (func (export "read") (result i32)`,
    `      call $value)`,
    `  )`,
    `  "unknown import")`,
    ``,
  ].join("\n");
}

export function buildValidImportExportWast(): string {
  return [
    `(module $provider`,
    `  (func $value (export "value") (result i32) i32.const 7)`,
    `  (memory $memory (export "memory") 1)`,
    `  (table $table (export "table") 1 funcref)`,
    `  (global $global (export "global") i32 (i32.const 3))`,
    `)`,
    `(register "provider" $provider)`,
    `(module $consumer`,
    `  (import "provider" "value" (func $value (result i32)))`,
    `  (import "provider" "memory" (memory $memory 1))`,
    `  (import "provider" "table" (table $table 1 funcref))`,
    `  (import "provider" "global" (global $global i32))`,
    `  (func (export "read") (result i32)`,
    `    call $value`,
    `    global.get $global`,
    `    i32.add)`,
    `)`,
    ``,
  ].join("\n");
}

export function buildNamedTwoModuleWast(): string {
  return [
    `(module $provider`,
    `  (func $value (export "value") (result i32)`,
    `    i32.const 7)`,
    `)`,
    `(register "provider" $provider)`,
    `(module $consumer`,
    `  (import "provider" "value" (func $value (result i32)))`,
    `  (func (export "read") (result i32)`,
    `    call $value)`,
    `)`,
    ``,
  ].join("\n");
}
