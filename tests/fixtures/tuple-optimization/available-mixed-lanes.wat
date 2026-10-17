;; Distinct effectful lanes preserve i32/i64 and exact float bits through stores.
(module (import "env" "mark" (func $mark (param i32) (result i32)))
(func (export "run") (param i32) (result i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 ) (local i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64)
loop block (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 f32 f64)
local.get 0 i32.const 1 i32.add call $mark

local.get 0 i32.const 2 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 3 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 4 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 5 i32.add call $mark

local.get 0 i32.const 6 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 7 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 8 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 9 i32.add call $mark

local.get 0 i32.const 10 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 11 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 12 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 13 i32.add call $mark

local.get 0 i32.const 14 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 15 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 16 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 17 i32.add call $mark

local.get 0 i32.const 18 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 19 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 20 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 21 i32.add call $mark

local.get 0 i32.const 22 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 23 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 24 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 25 i32.add call $mark

local.get 0 i32.const 26 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 27 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 28 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 29 i32.add call $mark

local.get 0 i32.const 30 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 31 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 32 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 33 i32.add call $mark

local.get 0 i32.const 34 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 35 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 36 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 37 i32.add call $mark

local.get 0 i32.const 38 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 39 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 40 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 41 i32.add call $mark

local.get 0 i32.const 42 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 43 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 44 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 45 i32.add call $mark

local.get 0 i32.const 46 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 47 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 48 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 49 i32.add call $mark

local.get 0 i32.const 50 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 51 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 52 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 53 i32.add call $mark

local.get 0 i32.const 54 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 55 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 56 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 57 i32.add call $mark

local.get 0 i32.const 58 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 59 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 60 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
local.get 0 i32.const 61 i32.add call $mark

local.get 0 i32.const 62 i32.add call $mark
i64.extend_i32_s
local.get 0 i32.const 63 i32.add call $mark
f32.reinterpret_i32
local.get 0 i32.const 64 i32.add call $mark
i64.extend_i32_s f64.reinterpret_i64
end
local.set 64
local.set 63
local.set 62
local.set 61
local.set 60
local.set 59
local.set 58
local.set 57
local.set 56
local.set 55
local.set 54
local.set 53
local.set 52
local.set 51
local.set 50
local.set 49
local.set 48
local.set 47
local.set 46
local.set 45
local.set 44
local.set 43
local.set 42
local.set 41
local.set 40
local.set 39
local.set 38
local.set 37
local.set 36
local.set 35
local.set 34
local.set 33
local.set 32
local.set 31
local.set 30
local.set 29
local.set 28
local.set 27
local.set 26
local.set 25
local.set 24
local.set 23
local.set 22
local.set 21
local.set 20
local.set 19
local.set 18
local.set 17
local.set 16
local.set 15
local.set 14
local.set 13
local.set 12
local.set 11
local.set 10
local.set 9
local.set 8
local.set 7
local.set 6
local.set 5
local.set 4
local.set 3
local.set 2
local.set 1
block (result i32)
local.get 2 local.set 66
local.get 3 local.set 67
local.get 4 local.set 68
local.get 5 local.set 69
local.get 6 local.set 70
local.get 7 local.set 71
local.get 8 local.set 72
local.get 9 local.set 73
local.get 10 local.set 74
local.get 11 local.set 75
local.get 12 local.set 76
local.get 13 local.set 77
local.get 14 local.set 78
local.get 15 local.set 79
local.get 16 local.set 80
local.get 17 local.set 81
local.get 18 local.set 82
local.get 19 local.set 83
local.get 20 local.set 84
local.get 21 local.set 85
local.get 22 local.set 86
local.get 23 local.set 87
local.get 24 local.set 88
local.get 25 local.set 89
local.get 26 local.set 90
local.get 27 local.set 91
local.get 28 local.set 92
local.get 29 local.set 93
local.get 30 local.set 94
local.get 31 local.set 95
local.get 32 local.set 96
local.get 33 local.set 97
local.get 34 local.set 98
local.get 35 local.set 99
local.get 36 local.set 100
local.get 37 local.set 101
local.get 38 local.set 102
local.get 39 local.set 103
local.get 40 local.set 104
local.get 41 local.set 105
local.get 42 local.set 106
local.get 43 local.set 107
local.get 44 local.set 108
local.get 45 local.set 109
local.get 46 local.set 110
local.get 47 local.set 111
local.get 48 local.set 112
local.get 49 local.set 113
local.get 50 local.set 114
local.get 51 local.set 115
local.get 52 local.set 116
local.get 53 local.set 117
local.get 54 local.set 118
local.get 55 local.set 119
local.get 56 local.set 120
local.get 57 local.set 121
local.get 58 local.set 122
local.get 59 local.set 123
local.get 60 local.set 124
local.get 61 local.set 125
local.get 62 local.set 126
local.get 63 local.set 127
local.get 64 local.set 128
local.get 1 end local.set 65
end
local.get 65

local.get 66
i32.wrap_i64
local.get 67
i32.reinterpret_f32
local.get 68
i64.reinterpret_f64 i32.wrap_i64
local.get 69

local.get 70
i32.wrap_i64
local.get 71
i32.reinterpret_f32
local.get 72
i64.reinterpret_f64 i32.wrap_i64
local.get 73

local.get 74
i32.wrap_i64
local.get 75
i32.reinterpret_f32
local.get 76
i64.reinterpret_f64 i32.wrap_i64
local.get 77

local.get 78
i32.wrap_i64
local.get 79
i32.reinterpret_f32
local.get 80
i64.reinterpret_f64 i32.wrap_i64
local.get 81

local.get 82
i32.wrap_i64
local.get 83
i32.reinterpret_f32
local.get 84
i64.reinterpret_f64 i32.wrap_i64
local.get 85

local.get 86
i32.wrap_i64
local.get 87
i32.reinterpret_f32
local.get 88
i64.reinterpret_f64 i32.wrap_i64
local.get 89

local.get 90
i32.wrap_i64
local.get 91
i32.reinterpret_f32
local.get 92
i64.reinterpret_f64 i32.wrap_i64
local.get 93

local.get 94
i32.wrap_i64
local.get 95
i32.reinterpret_f32
local.get 96
i64.reinterpret_f64 i32.wrap_i64
local.get 97

local.get 98
i32.wrap_i64
local.get 99
i32.reinterpret_f32
local.get 100
i64.reinterpret_f64 i32.wrap_i64
local.get 101

local.get 102
i32.wrap_i64
local.get 103
i32.reinterpret_f32
local.get 104
i64.reinterpret_f64 i32.wrap_i64
local.get 105

local.get 106
i32.wrap_i64
local.get 107
i32.reinterpret_f32
local.get 108
i64.reinterpret_f64 i32.wrap_i64
local.get 109

local.get 110
i32.wrap_i64
local.get 111
i32.reinterpret_f32
local.get 112
i64.reinterpret_f64 i32.wrap_i64
local.get 113

local.get 114
i32.wrap_i64
local.get 115
i32.reinterpret_f32
local.get 116
i64.reinterpret_f64 i32.wrap_i64
local.get 117

local.get 118
i32.wrap_i64
local.get 119
i32.reinterpret_f32
local.get 120
i64.reinterpret_f64 i32.wrap_i64
local.get 121

local.get 122
i32.wrap_i64
local.get 123
i32.reinterpret_f32
local.get 124
i64.reinterpret_f64 i32.wrap_i64
local.get 125

local.get 126
i32.wrap_i64
local.get 127
i32.reinterpret_f32
local.get 128
i64.reinterpret_f64 i32.wrap_i64
))
