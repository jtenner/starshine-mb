(module
(func $target (param i32 i32) (result i32) local.get 1)
(func $wrap (result i32) i32.const 31 i32.const 41 return_call $target)
(func (export "main") (result i32) call $wrap))
