(module (tag $e) (func (export "main") (block (result exnref) (block (block nop) (try_table (catch_ref $e 1) (throw $e)) unreachable) unreachable) drop unreachable))
