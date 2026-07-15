///|
#skip("manual native-release sequenced-root lookup benchmark")
test "flatten long perf lane measures sequenced-root pair lookup" {
  for candidate_count in [256, 512] {
    let holders : Array[Int] = []
    let nodes : Array[Int] = []
    for candidate = 0; candidate < candidate_count; candidate = candidate + 1 {
      holders.push(candidate / 8)
      nodes.push(candidate * 2 + 1)
    }
    for sample = 0; sample < 15; sample = sample + 1 {
      let start = @lib.trace_now_us()
      let mut found = 0
      for query = 0; query < 1048576; query = query + 1 {
        let wanted = query % candidate_count
        for idx = 0; idx < nodes.length(); idx = idx + 1 {
          if holders[idx] == holders[wanted] && nodes[idx] == nodes[wanted] {
            found = found + 1
            break
          }
        }
      }
      assert_true(
        found == 1048576,
        msg="expected every sequenced-root pair lookup to resolve, got \{found}",
      )
      println(
        "pairs=\{candidate_count} sample=\{sample} us=\{@lib.trace_elapsed_us_since(start)} found=\{found}",
      )
    }
  }
}
