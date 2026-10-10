// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// Private query owner for one immutable environment. Query stacks are owned;
// the all-initialized local facts can be borrowed by the typechecker.
priv struct SlStatementTypeSeed {
  state : @validate.TcState
}

///|
fn SlStatementTypeSeed::new(env : @validate.Env) -> SlStatementTypeSeed {
  { state: @validate.make_state_owned(env, []), }
}

///|
fn SlStatementTypeSeed::fresh_state(
  self : SlStatementTypeSeed,
) -> @validate.TcState {
  // The seed starts with every bit true. Initialization only changes false
  // bits, and control forks borrow or copy before changing initialization.
  // Fresh owned stacks and immutable escape fields isolate each query.
  @validate.tc_state_with_owned_stack(self.state, [])
}
