import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

const root = path.resolve(import.meta.dir, "../..");
const binary = path.resolve(process.argv[2] ?? "_build/native/release/build/cmd/cmd.exe");
const oracle = path.resolve(process.argv[3] ?? ".tmp/v133-signoff-oracles/binaryen-version_133/bin/wasm-opt");
const dir = fs.mkdtempSync(path.join(root, ".tmp/p00-runtime-"));
const commands: unknown[] = [];
const fixtureProducer = process.env.STARSHINE_P00_FIXTURE_PRODUCER ? path.resolve(process.env.STARSHINE_P00_FIXTURE_PRODUCER) : undefined;
const command = (bin: string, args: string[], timeout = 30000) => {
  commands.push({bin, args});
  if (bin === "moon") {
    const log = path.join(dir, "native-fixture-build.log");
    const fd = fs.openSync(log, "w");
    try {
      execFileSync(bin, args, {cwd:root, timeout, stdio:["ignore",fd,fd], env:process.env});
      return fs.readFileSync(log,"utf8");
    } catch(error:any) { throw new Error(`native fixture command exited ${error.status}; complete output: ${log}`); }
    finally { fs.closeSync(fd); }
  }
  try { return execFileSync(bin, args, { cwd: root, encoding: "utf8", timeout, maxBuffer: 64 * 1024 * 1024 }); }
  catch (error: any) {
    const log = path.join(dir, `command-failure-${commands.length}.log`);
    fs.writeFileSync(log, String(error.stdout ?? "") + String(error.stderr ?? ""));
    throw new Error(`${bin} exited ${error.status}; complete output: ${log}`);
  }
};
const sha = (file: string) => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const seal = () => fs.writeFileSync(path.join(dir, "manifest.json"), JSON.stringify({binary, binarySha256:sha(binary), oracle, oracleSha256:sha(oracle), head:command("git", ["rev-parse", "HEAD"]).trim(), fixtureProducer, fixtureProducerSha256:fixtureProducer ? sha(fixtureProducer) : undefined, sourceDiffSha256:createHash("sha256").update(command("git", ["diff", "HEAD"])).digest("hex"), commands}, null, 2));
process.on("exit", seal);
const fallbackDir = path.join(root, ".tmp/p00-hot-fallback-runtime");
fs.mkdirSync(fallbackDir, {recursive:true});
type RuntimeResult = number|string|Array<number|string>|undefined;
type Variant = (argument: number[]) => {result:RuntimeResult, events:number[], trap:boolean};
const liveVariant: Variant = argument => ({result:argument[1] ? 7 : 8, events:argument[1] ? [19] : [19,23], trap:false});
const fallbackChecks: Array<{name:string, args:number[][], result:RuntimeResult, events:number[], normalTrap:boolean, variant?:Variant}> = [];
assert.match(command(oracle, ["--version"]), /^wasm-opt version 133\b/);
const runner = path.join(dir, "observe.cjs");
fs.writeFileSync(runner, `
const fs = require("node:fs");
const events = [], stop = process.argv[3] === "trap-first";
const host = { log(x) { events.push(x); if (stop && events.length === 1) throw new WebAssembly.RuntimeError("first import"); },
  f(x) { events.push(x); if (stop && events.length === 1) throw new WebAssembly.RuntimeError("first import"); return x; },
  pair() { events.push(31); if (stop && events.length === 1) throw new WebAssembly.RuntimeError("first import"); return [19, 23n]; },
  triple() { events.push(32); if (stop && events.length === 1) throw new WebAssembly.RuntimeError("first import"); return [19, 23n, 5.25]; } };
const instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])), {env:host,host});
let result, trap = false;
try { result = (instance.exports.f ?? instance.exports.run)(...JSON.parse(process.argv[4] ?? "[1]")); }
catch(e) { if (!(e instanceof WebAssembly.RuntimeError)) throw e; trap = true; }
console.log(JSON.stringify({result, trap, events}, (_, value) => typeof value === "bigint" ? String(value) : value));
`);
const observations: unknown[] = [];
const selected = process.argv[4];
function check(name: string, wat: string, pass: string, result: RuntimeResult, events: number[], args: number[][] = [[1]], normalTrap = false, variant?: Variant): void {
  if (selected && !name.startsWith(selected)) return;
  const input = path.join(dir, name + ".wat"), wasm = input + ".wasm";
  fs.writeFileSync(input, wat);
  if (name === "oi-order") fs.writeFileSync(path.join(fallbackDir, name + ".wat"), wat);
  if (pass.startsWith("dae2") && !name.startsWith("mixed-suffix")) {
    fs.writeFileSync(path.join(fallbackDir, name + ".wat"), wat);
    fallbackChecks.push({name, args, result, events, normalTrap, variant});
  }
  command("wasm-tools", ["parse", input, "-o", wasm]);
  command("wasm-tools", ["validate", "--features", "all", wasm]);
  const outputs = { original: wasm, starshine: wasm + ".ss", binaryen: wasm + ".b133" };
  command(binary, [`--${pass}`, "--out", outputs.starshine, wasm]);
  command(oracle, ["--all-features", ...(pass === "dae2-optimizing" ? ["--dae2", "--simplify-locals", "--vacuum"] : [`--${pass}`]), wasm, "-o", outputs.binaryen]);
  for (const [side, output] of Object.entries(outputs)) {
    command("wasm-tools", ["validate", "--features", "all", output]);
    for (const argument of args) for (const mode of ["normal", "trap-first"]) {
      const observation = JSON.parse(command("node", [runner, output, mode, JSON.stringify(argument)]));
      const normal = variant ? variant(argument) : {result, trap:normalTrap, events};
      const expected = mode === "normal" ? normal : {trap:true, events:normal.events.slice(0,1)};
      observations.push({ name, pass, side, argument, mode, observation });
      fs.writeFileSync(path.join(dir, "observations.json"), JSON.stringify(observations, null, 2));
      assert.deepEqual(observation, JSON.parse(JSON.stringify(expected)), `${name}/${side}/${mode}/${argument}; artifacts ${dir}`);
    }
  }
}
if (!selected || "merge-blocks".startsWith(selected)) {
  const input = path.join(dir, "merge-blocks.wat"), wasm = input + ".wasm", output = wasm + ".ss";
  fs.writeFileSync(input, `(module (table 1 funcref) (func (export "f") i32.const 0 i32.const 0 table.get 0 i32.const 0 table.fill 0 block (result v128) unreachable end f32.const 2.5 block end drop drop block (result funcref) block ref.null func i32.const 0 br_table 1 1 end unreachable end drop))`);
  fs.copyFileSync(input, path.join(fallbackDir, "merge-blocks.wat"));
  command("wasm-tools", ["parse", input, "-o", wasm]);
  command("wasm-tools", ["validate", "--features", "all", wasm]);
  command(binary, ["--merge-blocks", "--out", output, wasm]);
  command("wasm-tools", ["validate", "--features", "all", output]);
}
const mixedSuffixWat = `(module (import "host" "pair" (func (result i32 i64)))
 (func (export "run") (result i32 i64 i32)
  call 0 i32.const 7 block (param i64 i32) (result i64 i32) end))`;
const mixedSuffixTripleWat = `(module (import "host" "triple" (func (result i32 i64 f32)))
 (func (export "run") (result i32 i64 f32 i32)
  call 0 i32.const 7 block (param i64 f32 i32) (result i64 f32 i32) end))`;
if (!selected) {
  fs.writeFileSync(path.join(fallbackDir, "typed-mixed-suffix.wat"), mixedSuffixWat);
  fs.writeFileSync(path.join(fallbackDir, "typed-mixed-suffix-triple.wat"), mixedSuffixTripleWat);
}
check("oi-order", `(module
 (import "env" "log" (func $log (param i32)))
 (func $se (param i32) (result i32) (call $log (local.get 0)) (i32.const 0))
 (func (export "f") (result i32) (local i32)
  i32.const 1 call $se i32.const 0 i32.and
  i32.const 5 i32.const 0 i32.const 2 call $se i32.const 0 select
  local.set 0 i32.add))`, "optimize-instructions", 5, [1, 2]);
for (const pass of ["dae2", "dae2-optimizing"]) {
  check(`mixed-suffix-${pass}`, mixedSuffixWat, pass, [19,"23",7], [31], [[]]);
  check(`mixed-suffix-triple-${pass}`, mixedSuffixTripleWat, pass, [19,"23",5.25,7], [32], [[]]);
  check(`typed-carried-argument-${pass}`, `(module
   (import "host" "f" (func (param i32) (result i32)))
   (global $g (mut i32) (i32.const 0))
   (func $h (param i32 i64) (result i32) local.get 0 global.get $g i32.add)
   (func (export "run") (result i32) global.get $g call 0 i32.const 5 global.set $g i64.const 99 call $h))`, pass, 5, [0], [[]]);
  check(`typed-discard-${pass}`, `(module
   (import "host" "f" (func (param i32) (result i32)))
   (func $h (param i32 i32 i64) (result i32)
    i32.const 19 call 0 local.get 0 block (param i32 i32) (result i32) i32.div_s end)
   (func (export "run") (param i32) local.get 0 i32.const 0 i64.const 99 call $h drop i32.const 23 call 0 drop))`, pass, undefined, [19, 23]);
  check(`typed-live-branch-${pass}`, `(module
   (import "env" "log" (func $log (param i32)))
   (func $callee (param i32 i32 i64) (result i32)
    i32.const 19 call $log local.get 0 block (param i32) (result i32) local.get 1 br_if 0 i32.const 23 call $log i32.const 1 i32.add end)
   (func (export "run") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 99 call $callee))`, pass, 7, [19], [[7,0],[7,1]], false, liveVariant);
  check(`typed-partial-tuple-${pass}`, `(module
   (import "host" "pair" (func (result i32 i64)))
   (func $callee (param i32 i64 i32) (result i64) local.get 1 block (param i64) (result i64) i64.const 1 i64.add end)
   (func (export "run") (result i64) call 0 i32.const 99 call $callee))`, pass, "24", [31]);
  check(`typed-mixed-prefix-${pass}`, `(module
   (import "host" "f" (func (param i32) (result i32)))
   (func $callee (param i64 i32) (result i64) (local i64)
    i32.const 19 call 0 local.get 0 block (param i32 i64) (result i64) local.set 2 drop local.get 2 end)
   (func (export "run") (result i64) i64.const 23 i32.const 99 call $callee))`, pass, "23", [19]);
  check(`typed-div-trap-${pass}`, `(module
   (import "host" "f" (func (param i32) (result i32)))
   (func $h (param i32 i32 i64) (result i32)
    i32.const 19 call 0 local.get 0 block (param i32 i32) (result i32) i32.div_s end)
   (func (export "run") (param i32) local.get 0 i32.const 0 i64.const 99 call $h drop i32.const 23 call 0 drop))`, pass, undefined, [19], [[0]], true);

}
if (!selected) {
  fs.writeFileSync(path.join(fallbackDir,"scratch-appended-block.wat"), `(module (memory 1) (data (i32.const 0) "\\07\\00\\00\\00")
   (func (export "f") (result i32) (local i32 i32)
    (local.set 1 (i32.const 1)) (block (local.set 1 (i32.load (i32.const 0)))) (local.get 1)))`);
  fs.writeFileSync(path.join(fallbackDir,"scratch-appended-loop.wat"), `(module (memory 1) (data (i32.const 0) "\\07\\00\\00\\00")
   (func (export "f") (result i32) (local $sum i32) (local $x i32) (local $i i32)
    (local.set $x (i32.const 1)) (loop $l
     (local.set $sum (i32.add (local.get $sum) (local.get $x)))
     (local.set $x (i32.load (i32.const 0)))
     (local.set $i (i32.add (local.get $i) (i32.const 1)))
     (br_if $l (i32.lt_u (local.get $i) (i32.const 2)))) (local.get $sum)))`);
  if (fixtureProducer) {
    const builtAt = fs.statSync(fixtureProducer).mtimeMs;
    const visit = (folder: string): void => {
      for (const entry of fs.readdirSync(folder, {withFileTypes:true})) {
        const file = path.join(folder,entry.name);
        if (entry.isDirectory()) visit(file);
        else if (entry.name.endsWith(".mbt") || entry.name === "moon.pkg") {
          assert.ok(fs.statSync(file).mtimeMs <= builtAt, `stale fixture producer: ${file}`);
        }
      }
    };
    visit(path.join(root,"src"));
    assert.ok(fs.statSync(path.join(root,"moon.mod")).mtimeMs <= builtAt, "stale fixture producer: moon.mod");
    const output = command(fixtureProducer,["p00_hot_runtime_wbtest.mbt:0-4"]);
    fs.writeFileSync(path.join(dir,"forced-hot-test.log"),output);
    const results = output.split("\n").filter(line => line.startsWith('{"type":"result"')).map(line => JSON.parse(line));
    assert.deepEqual(results.map(row => row.index),[0,1,2,3]);
    for (const row of results) assert.equal(row.message,"",`native fixture failed: ${row.message}`);
  } else {
    fs.writeFileSync(path.join(dir, "forced-hot-test.log"), command("moon", ["test", "--package", "jtenner/starshine/passes", "--target", "native", "--release", "--file", "p00_hot_runtime_wbtest.mbt", "--index", "0-4"], 900000));
  }
  for (const name of ["oi-order", "merge-blocks"]) for (const stage of ["before", "after"]) {
    const output = path.join(fallbackDir, name + "." + stage + ".wasm");
    command("wasm-tools", ["validate", "--features", "all", output]);
    fs.copyFileSync(output, path.join(dir, name + ".direct-" + stage + ".wasm"));
  }
  for (const stage of ["before", "after"]) {
    const output = path.join(fallbackDir, "ssa-branch-operand."+stage+".wasm");
    command("wasm-tools", ["validate", "--features", "all", output]);
    fs.copyFileSync(output, path.join(dir, "ssa-branch-operand."+stage+".wasm"));
    for (const [argument, result] of [[0,3],[1,1]]) {
      const observation = JSON.parse(command("node", [runner, output, "normal", JSON.stringify([argument])]));
      observations.push({name:"ssa-branch-operand", stage, argument, observation});
      fs.writeFileSync(path.join(dir,"observations.json"),JSON.stringify(observations,null,2));
      assert.deepEqual(observation, {result,trap:false,events:[]});
    }
  }
  for (const [name,result] of [["scratch-appended-block",7],["scratch-appended-loop",8]] as const) {
    const before = path.join(fallbackDir,name + ".before.wasm");
    const reference = path.join(dir,name + ".b133.wasm");
    command(oracle,["--all-features","--ssa-nomerge",before,"-o",reference]);
    for (const [side,output] of [["original",before],["starshine",path.join(fallbackDir,name + ".after.wasm")],["binaryen",reference]]) {
      command("wasm-tools",["validate","--features","all",output]);
      fs.copyFileSync(output,path.join(dir,name + "." + side + ".wasm"));
      const observation = JSON.parse(command("node",[runner,output,"normal","[]"]));
      observations.push({name,side,observation});
      fs.writeFileSync(path.join(dir,"observations.json"),JSON.stringify(observations,null,2));
      assert.deepEqual(observation,{result,trap:false,events:[]});
    }
  }
  const directChecks = [
    {name:"oi-order", output:path.join(fallbackDir, "oi-order.after.wasm"), args:[[]], result:5, events:[1,2], normalTrap:false},
    ...[false,true].map(captures => ({name:"mixed-suffix-direct-"+captures, output:path.join(fallbackDir, "typed-mixed-suffix.direct-"+captures+".wasm"), args:[[]], result:[19,"23",7], events:[31], normalTrap:false})),
    ...[false,true].map(captures => ({name:"mixed-suffix-triple-direct-"+captures, output:path.join(fallbackDir, "typed-mixed-suffix-triple.direct-"+captures+".wasm"), args:[[]], result:[19,"23",5.25,7], events:[32], normalTrap:false})),
    ...[false,true].map(captures => ({name:"typed-live-direct-"+captures, output:path.join(fallbackDir, "typed-live.direct-"+captures+".wasm"), args:[[7,0],[7,1]], result:7, events:[19], normalTrap:false, variant:liveVariant})),
  ];
  for (const {name, args, result, events, normalTrap, output, variant} of [...fallbackChecks.map(c => ({...c, output:path.join(fallbackDir,c.name+".wasm")})), ...directChecks]) {
    command("wasm-tools", ["validate", "--features", "all", output]);
    fs.copyFileSync(output, path.join(dir, name + ".forced-hot.wasm"));
    for (const argument of args) for (const mode of ["normal", "trap-first"]) {
      const observation = JSON.parse(command("node", [runner, output, mode, JSON.stringify(argument)]));
      const normal = variant ? variant(argument) : {result, trap:normalTrap, events};
      const expected = mode === "normal" ? normal : {trap:true, events:normal.events.slice(0,1)};
      observations.push({name, side:"forced-hot", argument, mode, observation});
      fs.writeFileSync(path.join(dir, "observations.json"), JSON.stringify(observations, null, 2));
      assert.deepEqual(observation, JSON.parse(JSON.stringify(expected)), `${name}/forced-hot/${mode}; artifacts ${dir}`);
    }
  }
}
if (!selected || "rethrow-identity".startsWith(selected)) {
  const input = path.join(dir, "rethrow-identity.wat"), wasm = input + ".wasm";
  fs.writeFileSync(input, `(module
   (import "host" "t" (tag $t (param i32)))
   (import "host" "raise" (func $raise)) (tag $u)
   (func (export "f") (param i32)
    (try (do call $raise)
     (catch $t drop (if (local.get 0) (then (rethrow 1))) (rethrow 0))
     (catch $u))))`);
  // Node does not yet accept compact imports. Keep this runtime input and
  // oracle output in the supported embedding profile; all bytes still validate.
  command(oracle, ["--all-features", "--disable-compact-imports", input, "-o", wasm]);
  const observe = path.join(dir, "observe-rethrow.cjs");
  fs.writeFileSync(observe, `
const fs = require("node:fs");
const tag = new WebAssembly.Tag({parameters:["i32"]});
const original = new WebAssembly.Exception(tag, [77]);
const instance = new WebAssembly.Instance(new WebAssembly.Module(fs.readFileSync(process.argv[2])),
 {host:{t:tag, raise(){throw original;}}});
let result = {exception:false};
try { instance.exports.f(Number(process.argv[3])); }
catch(e) {
 if (!(e instanceof WebAssembly.Exception)) throw e;
 result = {exception:true, identity:e === original, tag:e.is(tag), payload:e.is(tag) ? e.getArg(tag,0) : undefined};
}
console.log(JSON.stringify(result));
`);
  for (const pass of ["vacuum", "dae2", "dae2-optimizing"]) {
    const outputs = {original:wasm, starshine:wasm + "." + pass + ".ss", binaryen:wasm + "." + pass + ".b133"};
    command(binary, [`--${pass}`, "--out", outputs.starshine, wasm]);
    command(oracle, ["--all-features", "--disable-compact-imports", ...(pass === "dae2-optimizing" ? ["--dae2", "--simplify-locals", "--vacuum"] : [`--${pass}`]), wasm, "-o", outputs.binaryen]);
    for (const [side, output] of Object.entries(outputs)) {
      command("wasm-tools", ["validate", "--features", "all", output]);
      for (const argument of [0,1]) {
        const observation = JSON.parse(command("node", [observe, output, String(argument)]));
        observations.push({name:"rethrow-identity", pass, side, argument, observation});
        fs.writeFileSync(path.join(dir, "observations.json"), JSON.stringify(observations, null, 2));
        assert.deepEqual(observation, {exception:true, identity:true, tag:true, payload:77});
      }
    }
  }
}
console.log(`P00 runtime regressions passed; artifacts ${dir}`);
