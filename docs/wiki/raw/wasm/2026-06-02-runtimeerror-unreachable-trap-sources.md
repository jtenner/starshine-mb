# WebAssembly RuntimeError And Unreachable Trap Sources

- Capture date: 2026-06-02
- Source family: WebAssembly JavaScript interface docs plus WebAssembly core execution sources
- Primary sources checked:
  - MDN, `WebAssembly.RuntimeError`: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/RuntimeError>
  - MDN, `unreachable`: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Control_flow/unreachable>
  - WebAssembly Core Specification, `Execution / Instructions` — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/exec/instructions.html>
  - WebAssembly Core Specification, `Syntax / Instructions` — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/syntax/instructions.html>

## Durable takeaways

- `WebAssembly.RuntimeError` is the JavaScript-side error type WebAssembly uses whenever the spec specifies a trap. That makes it the generic host-facing wrapper for wasm traps, not a Node-specific error class.
- `unreachable` is an unconditional trap instruction. The execution rule maps it directly to a trap, and the syntax docs describe it as the instruction that causes an unconditional trap.
- A host message such as `RuntimeError: unreachable` is therefore the expected surface symptom of executing `unreachable`, not evidence of a separate JS or Node runtime bug by itself.
- Treat the exact message text as presentation detail. For diagnosis, classify the failure by the trapped instruction and surrounding execution path, then use the host error class to confirm that the failure is a wasm trap rather than an ordinary host exception.

## Related wiki pages

- [`../../tooling/o4z-debug-startup-trap.md`](../../tooling/o4z-debug-startup-trap.md) — living summary for the current `o4z` debug-startup trap.
- [`../../validate/stack-polymorphism-and-bottom.md`](../../validate/stack-polymorphism-and-bottom.md) — broader validation page that explains why `unreachable` changes control-flow reachability during validation.
