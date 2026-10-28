---
kind: audit
status: supported
last_reviewed: 2026-10-28
related:
  - ./cli-command-and-dispatcher.md
  - ./node-package-surface.md
  - ./wasi-runner-and-preview-boundary.md
---

# Module input resource lifetime

## Repair status

The compatibility-host reader repair is complete on
`fix/starshine-input-resource-lifetime`. The native dependency repair remains
in progress in this checkpoint. The audit below records the original baseline,
not the repaired state.

Both Node hosts now remove byte readers at finish. String and string-array
readers also release their temporary external transfer handles. Active readers
keep their own snapshots; finishing one reader does not invalidate another
reader or a byte-array builder.

[`node/test/fs-resource-lifetime.test.mjs`](../../../node/test/fs-resource-lifetime.test.mjs)
observes each host's private Map through test-only instrumentation. On master
`3d1deec7cecf1caaf65b42799777ff52ef210245`, 32 completed input reads followed by
Starshine decode errors leave 1 through 32 handles in each reused host. After
the repair each leaves zero. Success, early finish, repeated I/O errors,
Unicode strings, array children and overlapping readers have coverage.
The original eight checks failed before implementation; all ten current
checks pass. Tests use a directly built, unoptimized FFI WasmGC artifact.

Success-path finish handling changes. This checkpoint is **READY TO MEASURE**,
not performance signoff. Proposed workloads compare baseline and repaired
long-lived hosts with successful and invalid 8-byte, 64-KiB and 8-MiB inputs,
repeated missing-file errors, and argument/directory string transfers. Record
wall time, heap/allocation samples and retained-handle counts under a quiet
measurement lease. Byte copying and per-byte loops are unchanged; finish adds
bounded Map lookups/deletions, and string readers store one source handle.
No decode or optimization code changes.

## Scope and result

Read-only source audit of `crosscheck/starshine-fd-leak`, based on master
`3d1deec7cecf1caaf65b42799777ff52ef210245`. No production code or tests were
changed. The supplied Slipstream finding is an audit lead, not independently
verified evidence about Slipstream.

**Verdict: PRESENT. Severity: medium (P2).** This verdict uses the requested
scope of file descriptors **or equivalent retained resources** on read,
validation, and processing failures. The confirmed Starshine-owned case is
retention of completed byte readers in the compatibility filesystem host.
The native shared filesystem dependency also has missing closes on I/O error
paths. These are source findings; no descriptor-limit or memory-exhaustion
experiment was run. The evidence and scope limits follow.

## Compatibility host: completed input readers remain in a strong table

The exact path is the Wasm command reader in
[`src/cmd/cmd.mbt:8209-8210`](../../../src/cmd/cmd.mbt#L8209), through
[`src/fs/fs.mbt:137-142`](../../../src/fs/fs.mbt#L137), to the pinned dependency's
`fs/fs_wasm.mbt:188-191`. That dependency reads a file through the host, obtains
its content, and converts it to MoonBit bytes. Its `byte_array_from_extern` at
lines 114-126 calls `begin_read_byte_array`, consumes the bytes, and calls
`finish_read_byte_array`. The dependency identity is recorded below.

In the shipped WASI host:

- [`node/internal/wasi-runner.js:22-32`](../../../node/internal/wasi-runner.js#L22)
  creates a strong `Map` and inserts each allocated handle.
- [Lines 184-200](../../../node/internal/wasi-runner.js#L184) copy input bytes
  into a new JavaScript array in that table. `finish_read_byte_array` is empty.
  Thus completed readers remain reachable while the host remains reachable.
- [Lines 201-210](../../../node/internal/wasi-runner.js#L201) read the file with
  `fs.readFileSync(path)`. The retained object is a byte array, not an OS file
  descriptor. `lastFileContent` is one replaceable slot; the accumulating
  objects are the table entries above.
- After that read returns, the command can return a decode error at
  [`src/cmd/cmd.mbt:5981-5985`](../../../src/cmd/cmd.mbt#L5981), a pass error at
  [lines 6223-6228](../../../src/cmd/cmd.mbt#L6223), or a validation error at
  [lines 6251-6254](../../../src/cmd/cmd.mbt#L6251). None of these paths releases
  the host reader. The read had already called the empty finish function.
- On an I/O error, [lines 121-122 and 143-159](../../../node/internal/wasi-runner.js#L121)
  also retain the error string and its reader. The dependency's
  `fs/fs_wasm.mbt:165-169,188-190` retrieves that error, and its lines 57-69 call
  the empty string-reader finish function.

The WasmGC host has the same byte-reader defect at
[`node/internal/runtime.js:22-32,171-198`](../../../node/internal/runtime.js#L171)
and string-reader defect at [lines 121-146](../../../node/internal/runtime.js#L121).
Its host is installed at [lines 300-305](../../../node/internal/runtime.js#L300).
The default exports promise is cached at
[lines 375-379](../../../node/internal/runtime.js#L375), so a live instance can
keep its imported host and table alive. The source also exports the shared
filesystem readers through
[`ffi/src/ffi/exports.generated.mbt:2449-2460`](../../../ffi/src/ffi/exports.generated.mbt#L2449).
This audit does not claim that every FFI export is exposed by the shipped npm
facade or present in an unbuilt artifact.

This is broader than failure-only retention: a successful read also leaves a
reader entry. For each completed input read, the table retains an array with
one element per input byte. This is a source-derived growth bound, not a
measured heap size. P2 reflects the resulting memory growth in a reused host;
no remote service, exact exhaustion threshold, or host-wide impact was proved.

## Native CLI and shared native filesystem have different ownership

The normal native command selects its own reader at
[`src/cmd/cmd.mbt:8011-8022`](../../../src/cmd/cmd.mbt#L8011).
That reader opens one file at [lines 7433-7439](../../../src/cmd/cmd.mbt#L7433).
It calls `fclose` before each recoverable seek, tell, size, or read error at
[lines 7440-7465](../../../src/cmd/cmd.mbt#L7440), and before returning bytes at
[lines 7467-7470](../../../src/cmd/cmd.mbt#L7467).
The downstream decode and validation paths therefore do not own an input FD.
The spec command also uses this adapter and stores strings rather than open
files ([lines 4132-4141](../../../src/cmd/cmd.mbt#L4132)).

The public shared filesystem is different. Both
[`read_file_bytes`, lines 137-142](../../../src/fs/fs.mbt#L137), and
[`read_file_sync`, lines 172-181](../../../src/fs/fs.mbt#L172), call
`moonbitlang/x/fs`. In its native implementation,
`fs/fs_native.mbt:97-108`, a successful open is followed by error guards for
seek, tell, rewind, and read at lines 100, 102, 103, and 106. Those guards raise
before the only close at line 107. The C bindings return a raw `FILE *`
(`fs/fs_native.c:41-49`) and close only on the explicit close call
(`fs/fs_native.c:80-82`). No managed finalizer owns that pointer.

The wrapper catches the error and returns only a string. It cannot close the
lost stream. This is a second source-confirmed resource leak, assigned P2 for
native callers that recover and continue after such I/O failures. It requires
an I/O failure after open; a normal file whose module bytes fail validation
does not take this path. Reachable shared-reader consumers include the public
API ([`src/fs/pkg.generated.mbti:9-11`](../../../src/fs/pkg.generated.mbti#L9)),
the native-capable module input at
[`src/hot_identity_trace/main.mbt:277-283`](../../../src/hot_identity_trace/main.mbt#L277),
and the WAST seed reader at
[`src/fuzz/invalid_text.mbt:2089-2104`](../../../src/fuzz/invalid_text.mbt#L2089),
imported from `@fs` at
[`src/fuzz/imports.mbt:64`](../../../src/fuzz/imports.mbt#L64).
The trace executable aborts on read failure; it does not demonstrate repeated
failures in one session.

The same dependency has a related output error path:
`fs/fs_native.mbt:125-136` raises on write or flush failure before close.
The normal native CLI reaches it through
[`src/cmd/cmd.mbt:7475-7476`](../../../src/cmd/cmd.mbt#L7475) and
[`src/fs/fs.mbt:128-133`](../../../src/fs/fs.mbt#L128).
This is an output I/O issue, not an unresolved-import issue. No failure was
injected into either dependency path in this audit.

## Command, host, and component lifetime boundaries

- The CLI processes bytes through an adapter, not a linking Store. Its
  [`CmdIO` fields, lines 56-66](../../../src/cmd/cmd.mbt#L56), contain callbacks;
  its [summary, lines 114-126](../../../src/cmd/cmd.mbt#L114), contains paths and
  options. The input loop reads bytes before decode
  ([lines 5909-5985](../../../src/cmd/cmd.mbt#L5909)). The first command error
  returns from that invocation. A later input in the same command can be
  skipped by this intended control flow without any descriptor exhaustion.
- The native and Wasm main functions run one command
  ([`src/cmd/cmd.mbt:8086-8113`](../../../src/cmd/cmd.mbt#L8086)). The shipped
  Node CLI calls `runWasmStart`
  ([`node/bin/starshine.js:5-7`](../../../node/bin/starshine.js#L5)), which
  creates a fresh compatibility host per invocation
  ([`node/internal/wasi-runner.js:323-335`](../../../node/internal/wasi-runner.js#L323)).
  Repeating that wrapper is not evidence of retention across separate hosts.
- The direct Node command adapter reads bytes with `fs.readFileSync(path)`
  ([`node/cmd.js:1104-1113`](../../../node/cmd.js#L1104)) before decode and pass
  processing ([lines 1390-1424](../../../node/cmd.js#L1390)). It does not pass
  module input through the compatibility byte-reader table.
- The bulk host also reads whole files
  ([`node/internal/bulk-cli-host.js:43`](../../../node/internal/bulk-cli-host.js#L43))
  and clears its single response slot after delivery
  ([lines 62-69](../../../node/internal/bulk-cli-host.js#L62)). The guest reuses
  a staging area ([`src/cmd_gc/main.mbt:27-54`](../../../src/cmd_gc/main.mbt#L27));
  retained staging capacity is not a table of failed inputs.
- Component byte APIs decode and validate local values
  ([`component/implementation/modules.mbt:15-27,102-120`](../../../component/implementation/modules.mbt#L15)).
  The Core IR resource API stores a module only on decode or parse success
  ([`component/implementation/core_ir.generated.mbt:10147-10159`](../../../component/implementation/core_ir.generated.mbt#L10147)).
  A caller-owned module remaining after validation failure is not a failed-read
  file descriptor ([lines 10171-10175](../../../component/implementation/core_ir.generated.mbt#L10171)).
- Pipeline module state and its cache are local to one optimizer call
  ([`src/passes/optimize.mbt:1460-1462`](../../../src/passes/optimize.mbt#L1460));
  pass errors return at [lines 1606-1631](../../../src/passes/optimize.mbt#L1606).
  Cache clearing removes both references
  ([`src/passes/hot_pipeline_module_cache.mbt:15-18`](../../../src/passes/hot_pipeline_module_cache.mbt#L15)).
- The generated component implementation also inserts only on decode/parse
  success ([lines 10402-10414](../../../component/gen/interface/jtenner/starshine-component/core-ir/implementation.mbt#L10402)).
  Validation and encoding borrow a caller-owned module
  ([`component/wit/core-ir.generated.wit:1137-1138`](../../../component/wit/core-ir.generated.wit#L1137)).
  Its destructor clears the stored module and makes the slot available for
  reuse ([generated implementation, lines 3450-3455](../../../component/gen/interface/jtenner/starshine-component/core-ir/implementation.mbt#L3450)).
- No built-in request server or linker session was found in the inspected CLI,
  Node, FFI, and component entry points. This is a source-search conclusion,
  not a claim about user-written hosts. The named `HotPerfSession` holds trace
  settings, counters, and timer maps
  ([`src/passes/perf.mbt:72-82`](../../../src/passes/perf.mbt#L72)); it is not a
  module file table.

## Separate, unverified component ABI risk

The source review also found a return-area ownership question. The generated
validation wrapper allocates a result area at
[`component/gen/interface/jtenner/starshine-component/modules/ffi.mbt:254`](../../../component/gen/interface/jtenner/starshine-component/modules/ffi.mbt#L254).
Its post-return function frees an error payload but does not explicitly free
that result area ([lines 279-285](../../../component/gen/interface/jtenner/starshine-component/modules/ffi.mbt#L279)).
The outer function only forwards the call
([`component/gen/ffi.mbt:6213-6214`](../../../component/gen/ffi.mbt#L6213)).
Allocator and compiled consumer ownership were not verified. This remains a
separate risk, not a confirmed leak or a basis for the verdict.

## Dependency identity and validation limits

[`moon.mod:5-7`](../../../moon.mod#L5) pins `moonbitlang/x@0.5.1`;
[`src/fs/moon.pkg:6`](../../../src/fs/moon.pkg#L6) imports its filesystem.
The audit read the local registry archive `moonbitlang/x/0.5.1.zip` directly,
without installing or editing it. Archive SHA-256:
`cdceed523974dbd2833930f70e7e7ee087b77220659c55f87ab678197976aeae`.
Dependency paths and line numbers above refer to files inside that archive.

| Archive member | SHA-256 |
| --- | --- |
| `fs/fs_native.mbt` | `df26bc2c619e75e35507e8633e86e95df04406579e04a19cde7a5ff26cffec8d` |
| `fs/fs_native.c` | `f10144a5cbd2a4fa36fa4f058b1461b6788ec43b9e4fd9bb0be3015e3aa272b0` |
| `fs/fs_wasm.mbt` | `01f3a91e96194a90497b8886b382740c86781fef89412c59efff613ab70924e4` |

The dependency selects native/LLVM, Wasm/WasmGC, and JS implementations in
`fs/moon.pkg:9-15`. Its JS reader uses Node's path-based `readFileSync`
(`fs/fs_js.mbt:83-98`). External Moon runtime hosts and custom `CmdIO`
callbacks were not audited. Fatal allocation failures and process termination
are outside the recoverable-error analysis.

Validation consisted of source and call-path review, an independent review
of session and component ownership, dependency identity checks, and
documentation link/diff checks. The main review traced compatibility reader
calls through the dependency and verified the relevant independent findings.
No build, runtime reproduction, performance measurement, Binaryen comparison,
or full test suite was run.
No behavior changed, so there is no changed performance path to measure.
The audit establishes ownership defects from source; it does not establish
Slipstream's twenty-failure threshold or any corresponding Starshine threshold.
