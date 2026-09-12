(module (tag $e) (func (export "main") (block (block (block nop) (try_table (catch_all 1) (throw $e)))) unreachable))
