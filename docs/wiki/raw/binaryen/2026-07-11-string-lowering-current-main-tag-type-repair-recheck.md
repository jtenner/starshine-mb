# Binaryen `string-lowering` current-main tag-type repair recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable current-main primary-source bridge for `docs/wiki/binaryen/passes/string-lowering/`

## Scope

This focused reread refreshes the upstream freshness claim made by the 2026-04-26 port-readiness bridge. It compares the official Binaryen `main` owner, public registration, and focused string-lowering test surfaces with the `version_130` public-release baseline and the older `version_129` dossier contract.

It does not claim that Starshine implements `string-lowering`, and it does not replace the older captures. The 2026-04-24 manifest remains the tagged `version_129` provenance; the 2026-04-26 bridge remains historical evidence for the first port-readiness map.

## Primary sources reread

### Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
- Raw owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StringLowering.cpp>
- Registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Automatic shape oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-gathering.wast>
- Manual JSON/magic-import oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lowering.wast>
- JSON consumer: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lowering.js>

### Release and historical comparison anchors

- `version_130` owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/StringLowering.cpp>
- `version_130` registration: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `version_129` owner: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- 2026-04-24 tagged-source capture: [`2026-04-24-string-lowering-primary-sources.md`](2026-04-24-string-lowering-primary-sources.md)
- 2026-04-26 port-readiness bridge: [`2026-04-26-string-lowering-port-readiness-primary-sources.md`](2026-04-26-string-lowering-port-readiness-primary-sources.md)

## Durable observations

The core lowering contract remains stable on the reviewed surfaces:

- public registration still exposes `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert` beside `string-gathering` and `string-lifting`;
- the pass still runs inherited `StringGathering` first, remaps supported string heap types to extern heap types, lowers defining string globals to numbered or magic imports, rewrites the same narrow helper-call opcode set, refinalizes, and disables `FeatureSet::Strings`;
- default `string.consts` JSON, magic-import fallback, assert-mode failure, and the `wasm:js-string` helper roster remain on the reviewed owner/test surface.

There is one behavior-bearing current-main expansion in `updateTypes`:

- the older `version_129` / `version_130` code manually repaired public singleton-rec-group **function** types containing string references before `TypeMapper` ran;
- current `main` factors that repair into a shared `fixType` helper and applies it to both `module->functions` and `module->tags`;
- current `main` also passes the pass runner's world mode to `TypeMapper`. This capture does not infer a broader world-mode semantic beyond the source-level call change.

The important practical correction is therefore: a future port must not treat exception tags as outside string ABI lowering. A tag payload type containing `stringref` or `(ref null string)` needs the same string-to-extern repair as an affected function signature, while the existing source TODO for broader public-type cases remains in force.

## Test and porting consequence

The reviewed dedicated string fixtures remain the main proof surfaces for gathering, JSON/magic imports, and helper rewrites. This reread is a source-level freshness check, not evidence of a new completed tag-specific parity fixture.

A future Starshine port should add an explicit tag-payload case to its type-rewrite tests before it removes the Strings feature, alongside the existing function/global/import and helper-call cases. It must preserve tag payload validity and keep the broader public-type TODO boundary explicit rather than assuming a general type-rewrite solution.

## Local-status boundary

Local source inspection still finds no Starshine `string-lowering` owner or pass spelling in `src/`; this is still upstream-only work. The current local `string-gathering` implementation is a related prerequisite, not evidence that the broader type/import/helper lowering exists.

## Scope and uncertainty

This is a narrow owner/registration/fixture reread, not a full upstream commit-history audit, a direct Binaryen run, or a Starshine parity run. It supersedes the older **current-main freshness claim** only. Reopen the living contract if later upstream source, a new official release, or a focused parity artifact changes the supported type or opcode surface.

## Consumability rule

Cite this capture for the 2026-07-11 current-main tag-type-repair and freshness claims. Use the living dossier for explanation, and retain the older raw captures as historical provenance.
