# WebAssembly Spec Tests

This directory is a vendored mirror of upstream WebAssembly spec corpora used by the local spec harness and related regression tests.

It includes:

- upstream core suite
- proposal repos and forked proposal fixtures

## Update Process
- Weekly updates can arrive via upstream workflow or mirror bots.
- Manual contributor updates should run from the repo root via `python3 tests/spec/update-testsuite.py`.
- Keep local edits minimal and prefer upstream PRs when possible; this mirror is intended to track source updates rather than become a divergent fork.
