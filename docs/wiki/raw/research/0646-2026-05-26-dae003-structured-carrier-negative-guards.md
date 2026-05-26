# DAE003 structured-carrier negative guards

Date: 2026-05-26

## Scope

This note advances `[DAE003-F]` by pinning additional conservative boundaries for non-adjacent structured constant carriers in `dae-optimizing`.

The previous structured-carrier slice (`0644`) allowed only a single-instruction typed `block` whose body is a materializable constant, plus a loop negative guard. This run adds focused pass tests for two remaining unsafe/unsupported families:

- multi-instruction `block` carrier: `block (result i32) { i32.const 40; i32.const 2; i32.add } ; local.set 0 ; local.get 0 ; call $target`
- value-producing `if` carrier with matching constants in both arms: `if (result i32) { i32.const 88 } else { i32.const 88 } ; local.set 0 ; local.get 0 ; call $target`

## Result

Both tests preserve the target parameter on current code. No optimizer behavior changed.

Agent classification: these are conservative guardrails, not semantic mismatches. The multi-instruction block is pure in the fixture, but accepting it would require a broader expression materialization proof than the current single-instruction carrier recognizer. The `if` fixture has equal branch constants, but the condition is a separate consumed operand in the linear instruction stream, so replacing the `if` with a literal without preserving the condition would be unsafe for trapping/effectful conditions. A future positive `if` carrier slice needs explicit condition preservation or a proof that the condition stack is pure and safely droppable.

## Validation

- `moon test src/passes` passed: `1404` tests.

## Next steps

`[DAE003-F]` remains open. Remaining structured-carrier work includes proven-safe positives for branchy/multi-instruction blocks, loop/if/try/try_table carriers, and additional trap/effect/control negative tests before any closeout artifact/fuzz evidence.
