# Starshine for MoonBit

Starshine is a library for WebAssembly modules.
A library supplies functions that your program can call.
A module contains WebAssembly functions, data, and exports.
An export is a function or value that a host program can use.

Use this guide with `jtenner/starshine@0.2.1`.
This release adds the Mooncakes README. The library API is unchanged from `0.2.0`.

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
   moon version
   ```

3. Install Node.js 25 or newer for the WasmGC procedure.
4. Run this command to check Node.js:

   ```sh
   node --version
   ```

5. Install a C compiler for the native procedure.
6. Run this command to check the C compiler:

   ```sh
   cc --version
   ```

7. On Linux, set the stack limit for native debug compilation in this terminal:

   ```sh
   ulimit -s 65536
   ```

This limit applies to the current terminal and its child processes.
It does not change the system configuration.

The tested Moon version is `0.1.20260920`, with compiler `0.10.14+7d59c7ec9`.
The examples use Node.js 25.8.1 and the native target on Linux.

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
   moon add jtenner/starshine@0.2.1
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
  println(bytes.to_array().map(byte => byte.to_int()))
}
```

2. Run the WasmGC target:

   ```sh
   moon run cmd/main --target wasm-gc
   ```

3. Check that the program prints an array of bytes.

The encoded module exports `answer`. That function returns `42` when a WebAssembly host calls it.
The MoonBit program prints the bytes. It does not call the exported WebAssembly function.

4. Run the native target:

   ```sh
   moon run cmd/main --target native
   ```

Both targets run the same library calls.
A WasmGC target uses WebAssembly garbage collection and Node.js.
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
The [binary API](https://mooncakes.io/docs/jtenner/starshine@0.2.1/binary) lists these functions.

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

## Use the command tool

The npm package supplies a command-line interface, or **CLI**.
A CLI accepts commands in a terminal.
This procedure uses the existing npm release `starshine@0.2.0`.
It needs Node.js 25 or newer. It does not need MoonBit or a C compiler.

1. Create a separate directory:

   ```sh
   mkdir starshine-cli-demo
   ```

2. Open that directory:

   ```sh
   cd starshine-cli-demo
   ```

3. Create an npm project:

   ```sh
   npm init -y
   ```

4. Install the command tool:

   ```sh
   npm install starshine@0.2.0
   ```

5. Create `input.wat` with the WAT text from the file procedure.
6. Show the command help:

   ```sh
   npx --no-install starshine --help
   ```

7. Check the command version:

   ```sh
   npx --no-install starshine --version
   ```

8. Write the optimized module:

   ```sh
   npx --no-install starshine --precompute --vacuum --validate input.wat --out answer.wasm
   ```

The version command prints `v0.2.0`.
The validation flag checks the module at that point in the command sequence.
The tool returns a nonzero exit status if a command fails.
Node.js can print an experimental WASI warning. This warning is not a failed command.

## More information

Use the [package API](https://mooncakes.io/docs/jtenner/starshine@0.2.1) for function signatures.
Use the [source API reference](https://github.com/jtenner/starshine-mb/blob/master/README.mbt.md) for the full package map.
Use the [JavaScript guide](https://www.npmjs.com/package/starshine) for npm library calls.
Use the [component guide](https://github.com/jtenner/starshine-mb/blob/master/component/README.md) for the separate Component Model interface.

The module metadata retains Apache-2.0.
`LICENSE` grants MIT rights only for Joshua Tenner's original portions.
`NOTICE` and `licenses/` retain upstream licenses and attribution.
Known optimizer parity gaps and memory costs remain open.
