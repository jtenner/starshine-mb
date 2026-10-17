;; Each captured/output local has one lexical write.
;; These pure loops must exercise the tuple alias-copy rewrite.
(module (type $pair (func (result i32 i32)))
(func (export "prefix") (param $limit i32) (param $capture i32) (result i32 i32)
(local $a i32) (local $b i32) (local $saved_a i32) (local $saved_b i32) (local $alias_a i32) (local $alias_b i32) (local $out_a i32) (local $out_b i32) (local $iteration i32)
local.get $limit i32.const 3 i32.and i32.const 1 i32.add local.set $limit
loop $again
block (type $pair)
local.get $iteration i32.const 11 i32.add
local.get $iteration i32.const 100 i32.add
end local.set $b local.set $a
local.get $iteration local.get $capture i32.eq if local.get $a local.set $saved_a local.get $b local.set $saved_b end block (result i32) local.get $saved_b local.set $out_b local.get $saved_a end local.set $out_a
local.get $iteration i32.const 1 i32.add local.tee $iteration local.get $limit i32.lt_s br_if $again
end local.get $out_a local.get $out_b)
(func (export "trailing") (param $limit i32) (param $capture i32) (result i32 i32)
(local $a i32) (local $b i32) (local $saved_a i32) (local $saved_b i32) (local $alias_a i32) (local $alias_b i32) (local $out_a i32) (local $out_b i32) (local $iteration i32)
local.get $limit i32.const 3 i32.and i32.const 1 i32.add local.set $limit
loop $again
block (type $pair)
local.get $iteration i32.const 11 i32.add
local.get $iteration i32.const 100 i32.add
end local.set $b local.set $a
local.get $iteration local.get $capture i32.eq if local.get $a local.set $saved_a local.get $b local.set $saved_b end block (result i32) local.get $saved_a local.get $saved_b local.set $out_b end local.set $out_a
local.get $iteration i32.const 1 i32.add local.tee $iteration local.get $limit i32.lt_s br_if $again
end local.get $out_a local.get $out_b)
(func (export "chain") (param $limit i32) (param $capture i32) (result i32 i32)
(local $a i32) (local $b i32) (local $saved_a i32) (local $saved_b i32) (local $alias_a i32) (local $alias_b i32) (local $out_a i32) (local $out_b i32) (local $iteration i32)
local.get $limit i32.const 3 i32.and i32.const 1 i32.add local.set $limit
loop $again
block (type $pair)
local.get $iteration i32.const 11 i32.add
local.get $iteration i32.const 100 i32.add
end local.set $b local.set $a
local.get $iteration local.get $capture i32.eq if local.get $a local.set $saved_a local.get $b local.set $saved_b local.get $saved_a local.set $alias_a local.get $saved_b local.set $alias_b end block (result i32) local.get $alias_b local.set $out_b local.get $alias_a end local.set $out_a
local.get $iteration i32.const 1 i32.add local.tee $iteration local.get $limit i32.lt_s br_if $again
end local.get $out_a local.get $out_b)
(func (export "delayed") (param $limit i32) (param $capture i32) (result i32 i32)
(local $a i32) (local $b i32) (local $saved_a i32) (local $saved_b i32) (local $alias_a i32) (local $alias_b i32) (local $out_a i32) (local $out_b i32) (local $iteration i32)
local.get $limit i32.const 3 i32.and i32.const 1 i32.add local.set $limit
loop $again
block (type $pair)
local.get $iteration i32.const 11 i32.add
local.get $iteration i32.const 100 i32.add
end local.set $b local.set $a
block (result i32) local.get $saved_b local.set $out_b local.get $saved_a end local.set $out_a local.get $a local.set $saved_a local.get $b local.set $saved_b
local.get $iteration i32.const 1 i32.add local.tee $iteration local.get $limit i32.lt_s br_if $again
end local.get $out_a local.get $out_b)
)
