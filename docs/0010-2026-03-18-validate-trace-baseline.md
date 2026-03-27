# Validation Trace Benchmark Baseline

Recorded on 2026-03-18 with:

```sh
bun validate trace-benchmark --repeat 1
```

Default target: `wasm-gc`.

The corpora come from [`src/validate_trace/main.mbt`](../src/validate_trace/main.mbt). Wall-clock `elapsed_ms` will vary by machine and load, but the `phase_totals`, `helper_totals`, and `hotspots` lines below are the committed baseline snapshot for later validator performance work.

## deep-control

```text
corpus=deep-control repeats=1 elapsed_ms=55
phase_totals typesec_ms=1 typesec_calls=1 importsec_ms=0 importsec_calls=1 funcsec_ms=0 funcsec_calls=1 tablesec_ms=0 tablesec_calls=1 memsec_ms=0 memsec_calls=1 tagsec_ms=0 tagsec_calls=1 globalsec_ms=0 globalsec_calls=1 elemsec_ms=0 elemsec_calls=1 datasec_ms=0 datasec_calls=1 datacnt_ms=0 datacnt_calls=1 datacnt_requirement_ms=5 datacnt_requirement_calls=1 startsec_ms=0 startsec_calls=1 exportsec_ms=0 exportsec_calls=1 ref_func_declarations_ms=0 ref_func_declarations_calls=1 codesec_ms=49 codesec_calls=1
helper_totals body_ms=49 body_calls=1
hotspots f1:body=49000:locals=0:top=1
```

## wide-locals

```text
corpus=wide-locals repeats=1 elapsed_ms=2
phase_totals typesec_ms=0 typesec_calls=1 importsec_ms=0 importsec_calls=1 funcsec_ms=0 funcsec_calls=1 tablesec_ms=0 tablesec_calls=1 memsec_ms=0 memsec_calls=1 tagsec_ms=0 tagsec_calls=1 globalsec_ms=0 globalsec_calls=1 elemsec_ms=0 elemsec_calls=1 datasec_ms=0 datasec_calls=1 datacnt_ms=0 datacnt_calls=1 datacnt_requirement_ms=0 datacnt_requirement_calls=1 startsec_ms=0 startsec_calls=1 exportsec_ms=0 exportsec_calls=1 ref_func_declarations_ms=1 ref_func_declarations_calls=1 codesec_ms=1 codesec_calls=1
helper_totals body_ms=1 body_calls=1
hotspots f1:body=1000:locals=384:top=768
```

## large-codesec

```text
corpus=large-codesec repeats=1 elapsed_ms=3
phase_totals typesec_ms=0 typesec_calls=1 importsec_ms=0 importsec_calls=1 funcsec_ms=0 funcsec_calls=1 tablesec_ms=0 tablesec_calls=1 memsec_ms=0 memsec_calls=1 tagsec_ms=0 tagsec_calls=1 globalsec_ms=0 globalsec_calls=1 elemsec_ms=0 elemsec_calls=1 datasec_ms=0 datasec_calls=1 datacnt_ms=0 datacnt_calls=1 datacnt_requirement_ms=0 datacnt_requirement_calls=1 startsec_ms=0 startsec_calls=1 exportsec_ms=0 exportsec_calls=1 ref_func_declarations_ms=0 ref_func_declarations_calls=1 codesec_ms=2 codesec_calls=1
helper_totals body_ms=0 body_calls=160
hotspots f153:body=0:locals=0:top=2 f154:body=0:locals=0:top=2 f155:body=0:locals=0:top=2 f156:body=0:locals=0:top=2 f157:body=0:locals=0:top=2 f158:body=0:locals=0:top=2 f159:body=0:locals=0:top=2 f160:body=0:locals=0:top=2
```

## ref-func-heavy

```text
corpus=ref-func-heavy repeats=1 elapsed_ms=15
phase_totals typesec_ms=0 typesec_calls=1 importsec_ms=0 importsec_calls=1 funcsec_ms=0 funcsec_calls=1 tablesec_ms=12 tablesec_calls=1 memsec_ms=0 memsec_calls=1 tagsec_ms=0 tagsec_calls=1 globalsec_ms=0 globalsec_calls=1 elemsec_ms=0 elemsec_calls=1 datasec_ms=1 datasec_calls=1 datacnt_ms=0 datacnt_calls=1 datacnt_requirement_ms=0 datacnt_requirement_calls=1 startsec_ms=0 startsec_calls=1 exportsec_ms=0 exportsec_calls=1 ref_func_declarations_ms=0 ref_func_declarations_calls=1 codesec_ms=2 codesec_calls=1
helper_totals body_ms=1 body_calls=48
hotspots f46:body=1000:locals=0:top=12 f42:body=0:locals=0:top=12 f43:body=0:locals=0:top=12 f44:body=0:locals=0:top=12 f45:body=0:locals=0:top=12 f41:body=0:locals=0:top=12 f47:body=0:locals=0:top=12 f48:body=0:locals=0:top=12
```
