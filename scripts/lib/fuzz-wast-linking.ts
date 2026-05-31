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
