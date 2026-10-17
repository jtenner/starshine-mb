# Starshine MoonBit library tutorial

Starshine is a library for WebAssembly modules.
A library supplies functions that your program can call.
A module contains WebAssembly functions, data, and exports.
An export is a function or value that a host program can use.

Use this guide with `jtenner/starshine@0.3.0`.
This minor release adds optimizer repairs, diagnostics, and public helper functions.
See the [0.3.0 release notes](https://github.com/jtenner/starshine-mb/releases/tag/v0.3.0) for the full change list.

## Terms

- **WAT** is the text format for a WebAssembly module.
- **Wasm** is the binary format for a WebAssembly module.
- **Parse** means to convert text to a module value.
- **Validate** means to check a module against WebAssembly rules.
- **Optimize** means to change a module while it keeps the same behavior.
- **Encode** means to convert a module value to binary bytes.
- **Alias** means a short name for an imported package.
- **Result** is a value that contains `Ok(value)` or `Err(error)`.

Optimization does not always make a module smaller or faster.

## Prepare your computer

1. Install [MoonBit](https://www.moonbitlang.com/download/).
2. Run this command to check the installation:

   ```sh
   moon version --all
   ```

3. Install a C compiler for the native procedure.
4. Run this command to check the C compiler:

   ```sh
   cc --version
   ```

5. On Linux, set the stack limit for native debug compilation in this terminal:

   ```sh
   ulimit -s 65536
   ```

This limit applies to the current terminal and its child processes.
It does not change the system configuration.

The tested Moon version is `0.1.20260920`, with compiler `0.10.14+7d59c7ec9`.
The tested `moonrun` version is `0.1.20260920`.
The WasmGC procedure uses `moonrun`, which is included in the MoonBit toolchain.
It does not require Node.js. The native procedure was tested on Linux.

## Create a program

1. Create an empty project:

   ```sh
   moon new answer-tool
   ```

2. Open its directory:

   ```sh
   cd answer-tool
   ```

3. Add the library dependency:

   ```sh
   moon add jtenner/starshine@0.3.0
   ```

4. Replace `cmd/main/moon.pkg` with this configuration:

<!-- STARSHINE_TUTORIAL package -->
```moon
import {
  "jtenner/starshine/wast" @wast,
  "jtenner/starshine/validate" @validate,
  "jtenner/starshine/passes" @passes,
  "jtenner/starshine/binary" @binary,
  "jtenner/starshine/fs" @fs,
}
pkgtype(kind: "executable")
```

The prefix `@wast` refers to the text parser.
The other aliases refer to validation, optimization, binary conversion, and file functions.

## Add the library function

1. Create `cmd/main/optimizer.mbt`.
2. Copy this code into the file:

<!-- STARSHINE_TUTORIAL optimizer -->
```mbt
fn optimize_wat(text : String) -> Result[Bytes, String] {
  let input = match @wast.wast_to_binary_module(text) {
    Ok(value) => value
    Err(error) => return Err("Cannot parse WAT: \{error}")
  }
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(error) => return Err("Cannot validate input: \{error}")
  }
  let optimized = match @passes.run_hot_pipeline(
    input,
    @passes.HotPipelineOptions::new(),
    ["precompute", "vacuum"],
  ) {
    Ok(value) => value
    Err(error) => return Err("Cannot optimize module: \{error}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(error) => return Err("Cannot validate output: \{error}")
  }
  match @binary.encode_module(optimized) {
    Ok(bytes) => Ok(bytes)
    Err(error) => Err("Cannot encode module: \{error}")
  }
}
```

The function checks each result before it uses the value.
It returns bytes on success. It returns an error message on failure.
The `precompute` pass calculates constant expressions.
The `vacuum` pass removes unnecessary instructions.
The function validates the module before and after optimization.

## Run a complete example

1. Replace `cmd/main/main.mbt` with this code:

<!-- STARSHINE_TUTORIAL text -->
```mbt
fn main {
  let text = "(module (func (export \"answer\") (result i32) i32.const 40 i32.const 2 i32.add))"
  let bytes = match optimize_wat(text) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let numbers = bytes.to_array().map(byte => byte.to_int())
  let header = [0, 97, 115, 109, 1, 0, 0, 0]
  if numbers.length() < header.length() {
    abort("Wasm output has no header.")
  }
  for index = 0; index < header.length(); index = index + 1 {
    if numbers[index] != header[index] {
      abort("Wasm output has an invalid header.")
    }
  }
  println(numbers)
  println("Wasm header is valid.")
}
```

2. Resolve the project dependencies:

   ```sh
   moon update
   ```

3. Run the WasmGC target:

   ```sh
   moon run cmd/main --target wasm-gc
   ```

4. Check that the first eight numbers are `[0, 97, 115, 109, 1, 0, 0, 0]`.
5. Check that the last line is `Wasm header is valid.`.

These eight numbers are the Wasm file marker and version.

The encoded module exports `answer`. That function returns `42` when a WebAssembly host calls it.
The MoonBit program prints the bytes. It does not call the exported WebAssembly function.

6. Run the native target:

   ```sh
   moon run cmd/main --target native
   ```

Both targets run the same library calls.
The WasmGC target uses WebAssembly garbage collection and `moonrun`.
A native target compiles machine code for your computer.
These are the tested targets for this procedure.

## Read a file and write Wasm

Use the native target for this file procedure.
The `fs` package returns results for file operations.

1. Create `input.wat` in the project directory.
2. Copy this text into the file:

<!-- STARSHINE_TUTORIAL input -->
```wat
(module (func (export "answer") (result i32) i32.const 40 i32.const 2 i32.add))
```

3. Replace `cmd/main/main.mbt` with this code:

<!-- STARSHINE_TUTORIAL file -->
```mbt
fn main {
  let text = match @fs.read_file_sync("input.wat") {
    Ok(value) => value
    Err(error) => abort(error)
  }
  let bytes = match optimize_wat(text) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  match @fs.write_file_bytes("answer.wasm", bytes) {
    Ok(_) => println("Wrote answer.wasm")
    Err(error) => abort(error)
  }
}
```

4. Run the program:

   ```sh
   moon run cmd/main --target native
   ```

5. Check that `answer.wasm` exists in the project directory.

The output file contains the encoded module. It is not a text file.
Your program can also read binary input with `@fs.read_file_bytes`.
Use `@binary.decode_module` to convert those bytes to a module value.
Check its result before you validate or optimize the module.
The [binary API](https://mooncakes.io/docs/jtenner/starshine@0.3.0/binary) lists these functions.

## Handle errors

The library returns errors for invalid text, invalid modules, and failed file operations.
An unknown optimization pass also returns an error.
The example calls `abort(error)` to stop the program if an operation fails.
In your library code, return `Err(error)` so the caller can choose how to handle it.

1. Change `input.wat` to invalid text.
2. Run the file procedure again.
3. Check the error message.
4. Restore valid WAT before the next run.

If parsing, validation, or optimization fails, the program does not call the file writer.
An output file from an earlier run can still exist.
A failed write can leave a partial output file. Check the error before you use that file.
A valid module can still trap when a host runs its functions.
Validation checks types and structure. It does not guarantee successful execution for every input.

## More information

Use the [package API](https://mooncakes.io/docs/jtenner/starshine@0.3.0) for function signatures.
Use the [source API reference](https://github.com/jtenner/starshine-mb/blob/master/README.mbt.md) for the full package map.
Use the [JavaScript guide](https://www.npmjs.com/package/starshine) for npm library calls.
Use the [component guide](https://github.com/jtenner/starshine-mb/blob/master/component/README.md) for the separate Component Model interface.

The module metadata retains Apache-2.0.
`LICENSE` grants MIT rights only for Joshua Tenner's original portions.
`NOTICE` and `licenses/` retain upstream licenses and attribution.
Known optimizer parity gaps and memory costs remain open.
