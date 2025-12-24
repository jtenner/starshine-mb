pub trait ArbitraryWith : Validate {
  arbitrary_with(ctx: Env, fuel: UInt, state: @quickcheck/splitmix.RandomState) -> Result[Self, String]
}

