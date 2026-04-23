# Reference

## Dependency categories
1. **In-process** — pure computation or in-memory state.
2. **Local-substitutable** — can use a local stand-in like an in-memory db or fs.
3. **Remote but owned** — use ports/adapters so behavior can be tested at the boundary.
4. **True external** — mock only at the module boundary.

## Testing strategy
- replace shallow-module tests with boundary tests on the deepened module
- test observable behavior, not internal structure
- prefer tests that survive internal refactors

## RFC issue shape
- problem
- proposed interface
- dependency strategy
- testing strategy
- durable implementation recommendations
