# RemoveUnusedBrs dedicated runtime substitute and blocker

Date: 2026-06-29

## Scope

Continuation of `[O4Z-AUDIT-RUB-Q]` after note `1390`. This slice tests whether the current side-effect-free Starshine-win candidate classification can be strengthened into an approved substitute for a full normalized-green `remove-unused-brs-all` dedicated closeout.

## Current-binary runtime probe

Command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass remove-unused-brs \
  --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-runtime-max20 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile remove-unused-brs-all \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --normalize local-cleanup-debris \
  --runtime-execution node \
  --max-failures 20
```

Result:

- requested: `1000`
- compared before mismatch cap: `35`
- selected leaves: `remove-unused-brs-control=14`, `remove-unused-brs-switch=16`, `remove-unused-brs-cleanup=5`
- normalized matches: `0`
- cleanup-normalized matches: `0`
- mismatches: `35`
- Starshine validation failures: `0`
- generator/property/command failures: `0`
- cache: Binaryen `35` hits / `0` misses
- runtime execution: `35/35` checked, `0` unsupported, `0` failed
- runtime matrix: all-equal; `27` equal results, `8` equal traps, `0` semantic mismatches

The run intentionally used a small mismatch cap; because jobs run in parallel, the harness reported `35` mismatches before stopping. This is still not full `1000/1000` closeout evidence.

## Effect and size check

The runtime sample preserves the side-effect-free envelope from note `1390`: all 35 sampled inputs report no calls, memory/table/global mutation, exceptions, or atomics; all have `hasUnreachable=true` and `mayTrap=true`.

Size summary over `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-runtime-max20/failures`:

| Group | Cases | Runtime equal results | Runtime equal traps | Semantic mismatches | Raw Starshine <= Binaryen | Normalized Starshine <= Binaryen | Raw byte delta | Normalized byte delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| all | 35 | 27 | 8 | 0 | 13 | 35 | `+428` | `-3832` |
| control | 14 | 11 | 3 | 0 | 6 | 14 | `+179` | `-1445` |
| switch | 16 | 11 | 5 | 0 | 5 | 16 | `+171` | `-1728` |
| cleanup | 5 | 5 | 0 | 0 | 2 | 5 | `+78` | `-659` |

The deterministic seed overlaps the earlier capped `115`-mismatch sample rather than proving a statistically independent family, but it extends direct Node runtime evidence from the prior `20/20` smoke to `35/35` checked mismatches with no semantic mismatch.

## Classification and substitute decision

Agent classification remains: **side-effect-free Starshine-win candidate**, not a known semantic mismatch and not a Starshine validation failure, under the exact profile/effect envelope.

Additional evidence since note `1390`:

1. Current-binary runtime execution checks `35/35` sampled mismatches as all-equal.
2. Runtime outcomes cover both equal normal results and equal traps.
3. The same sample keeps the no-call/no-memory/no-table/no-global/no-exception/no-atomic envelope.
4. Normalized size still favors Starshine in every sampled mismatch.

This slice did **not by itself** close `[O4Z-AUDIT-RUB-Q]` because the completion contract requires full current-binary dedicated `1000` then `10000` closeout, or an approved substitute. Note `1392` supersedes the decision point in this note: the user explicitly accepted this side-effect-free dead-shell cleanup family as a Starshine win on 2026-06-29. Under repo rules, that acceptance is recorded as a project-approved substitute rather than relying on validation/size evidence alone.

Precise blocker if no substitute is approved:

- `remove-unused-brs-all` does not normalize green: the dedicated profile intentionally generates cases where Starshine deletes additional pure dead structured trap/control shells that Binaryen leaves, so every sampled current-binary case mismatches after the current normalizers.
- Full uncapped normalized-green `1000`/`10000` evidence is therefore unavailable without either changing Starshine to preserve Binaryen's dead shells or adding/approving a stronger normalizer/substitute policy.
- Current practical probes show `0` Starshine validation failures and `0` runtime semantic mismatches in checked samples, but not full closeout.
- Raw byte size is mixed (`+428` over the runtime sample, `+951` over the larger non-runtime sample), although normalized/canonical size wins in every sampled mismatch.

## Superseded next step

This note originally recommended asking for explicit approval of the substitute package before claiming closure. That approval is now recorded in note `1392`, which closes `[O4Z-AUDIT-RUB-Q]` under the approved-substitute clause for this exact mismatch family. Future larger capped dedicated probes may still be useful regression evidence, but they are no longer required to accept the documented side-effect-free dead-shell cleanup drift.
