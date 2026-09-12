(module (tag $e) (func (export "main") (block (result exnref) (try_table (catch_all_ref 0) (throw $e)) unreachable) drop unreachable))
