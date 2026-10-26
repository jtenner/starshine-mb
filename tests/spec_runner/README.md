# Legacy spec runner argument verification

Run only this focused native package:

```sh
python3 tests/spec_runner/verify_path_args.py
```

The legacy `src/spec_runner` directory has no `moon.pkg`. The helper extracts
`spec_runner_normalize_args` verbatim from the current production source and
compiles it with `path_args_wbtest.mbt` in a temporary, dependency-free MoonBit
package. It runs `moon test --target native src/args` in that package and returns
the test exit status. The temporary package and its build files are removed on
exit. It does not build or run the repository suite.

The tests require valid path arguments to remain unchanged. On source commit
`6d020542e5c54e2d1ace8db7c52e4949ff8da5de`, the command exits **2**: **1 passed,
3 failed**. The ordinary-path control passes. A leading space and a trailing
space are removed; a name made only of spaces is discarded. This red evidence
is retained from verification commit `7e10d18d`; the source and tests matched
that commit exactly before the fix, so the red run was not repeated.

With F14 fixed, the command exits **0**: **4 passed, 0 failed**. The runner skips
only `argv[0]` and copies each later argument unchanged, in order. It does not
trim or filter path arguments.

This is executable evidence for argument normalization, not an end-to-end run
of the legacy executable or a file-read test. The latter is unavailable through
the legacy package topology and imports. The fix and verification limits are
recorded in
[`Spec Runner Flow`](../../docs/wiki/wast/static-assertion-harness.md#spec-runner-flow).
