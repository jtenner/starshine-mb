(module (tag $e) (func (export "main") (block (result exnref) (try_table (catch_ref $e 0) (throw $e)) unreachable) drop unreachable))
