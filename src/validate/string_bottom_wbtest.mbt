///|
test "string heap intentionally rejects internal none bottom in each shared domain" {
  let env = Env::new()
  for shared in [false, true] {
    let source = if shared {
      HeapType::shared_abs(AbsHeapType::none())
    } else {
      HeapType::abs(AbsHeapType::none())
    }
    let target = if shared {
      HeapType::shared_abs(AbsHeapType::string_())
    } else {
      HeapType::abs(AbsHeapType::string_())
    }
    assert_false(Match::matches(source, target, env))
  }
}

///|
test "string heap accepts noextern bottom in each shared domain" {
  let env = Env::new()
  for shared in [false, true] {
    let source = if shared {
      HeapType::shared_abs(AbsHeapType::no_extern())
    } else {
      HeapType::abs(AbsHeapType::no_extern())
    }
    let target = if shared {
      HeapType::shared_abs(AbsHeapType::string_())
    } else {
      HeapType::abs(AbsHeapType::string_())
    }
    assert_true(Match::matches(source, target, env))
  }
}
