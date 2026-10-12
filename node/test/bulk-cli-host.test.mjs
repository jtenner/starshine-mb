import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { createBulkCliHost } from '../internal/bulk-cli-host.js';
import { runBulkCli } from '../internal/bulk-cli-runner.js';
import { fileURLToPath } from 'node:url';

// A binary response has one status byte followed by the complete payload.
test('bulk host reads and writes binary files with two calls each', () => {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'starshine-bulk-'));
 try {
  const memory=new WebAssembly.Memory({initial:32});
  const host=createBulkCliHost({memory:()=>memory,cwd:dir,args:['λ.wasm','-O4z'],env:{STARSHINE_TEST:'λ'}});
  const api=host.imports.__starshine_cli_v1;
  const input=Uint8Array.from({length:1<<20},(_,i)=>i&255);
  fs.writeFileSync(path.join(dir,'λ.wasm'),input);
  function request(op,bytes){new Uint8Array(memory.buffer).set(bytes,0);const len=api.request(op,0,bytes.length);assert.ok(len>0);assert.equal(api.response(0,len),len);return Uint8Array.from(new Uint8Array(memory.buffer,0,len));}
  const encode=s=>new TextEncoder().encode(s);
  assert.deepEqual(request(4,encode('λ.wasm')),new Uint8Array(Buffer.concat([Buffer.from([0]),input])));
  const name=encode('copy.wasm'); const packet=new Uint8Array(4+name.length+input.length);new DataView(packet.buffer).setUint32(0,name.length,true);packet.set(name,4);packet.set(input,4+name.length);
  assert.deepEqual(request(5,packet),new Uint8Array([0]));
  assert.deepEqual(fs.readFileSync(path.join(dir,'copy.wasm')),Buffer.from(input));
  assert.equal(host.calls.request,2);assert.equal(host.calls.response,2);
  assert.deepEqual(JSON.parse(new TextDecoder().decode(request(1,new Uint8Array()).subarray(1))),['λ.wasm','-O4z']);
  assert.equal(new TextDecoder().decode(request(2,encode('STARSHINE_TEST')).subarray(1)),'λ');
  assert.equal(request(4,encode('missing.wasm'))[0],1);
  assert.throws(()=>api.response(0,1),/pending/);
  assert.throws(()=>api.request(4,-1,2),/bounds/);
  const size=api.request(4,0,0);assert.throws(()=>api.response(0,size-1),/capacity/);assert.equal(api.response(0,size),size);
 } finally {fs.rmSync(dir,{recursive:true,force:true});}
});

// This separate lane uses the real command artifact and rejects every call to
// the old byte-at-a-time filesystem interface.
test('bulk GC command transforms a binary fixture and reports errors', { skip: !process.env.STARSHINE_BULK_WASM }, async () => {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'starshine-bulk-command-'));
 try {
  const input=Uint8Array.from([0,97,115,109,1,0,0,0,1,5,1,96,0,1,127,3,2,1,0,7,7,1,3,114,117,110,0,0,10,9,1,7,0,65,40,65,2,106,11]);
  fs.writeFileSync(path.join(dir,'λ.wasm'),input);
  const wasmPath=fileURLToPath(new URL(process.env.STARSHINE_BULK_WASM,`file://${process.cwd()}/`));
  const fd=fs.openSync(path.join(dir,'stderr'),'w');
  try {
   const result=await runBulkCli({wasmPath,cwd:dir,args:['λ.wasm','--precompute','--out','result.wasm'],stderrFd:fd});
   assert.equal(result.exitCode,0,fs.readFileSync(path.join(dir,'stderr'),'utf8'));
   const output=fs.readFileSync(path.join(dir,'result.wasm'));
   assert.notDeepEqual(output,Buffer.from(input));
   const {instance}=await WebAssembly.instantiate(output);assert.equal(instance.exports.run(),42);
   assert.ok(result.hostCalls.request<40,JSON.stringify(result.hostCalls));
   const failure=await runBulkCli({wasmPath,cwd:dir,args:['missing.wasm','--out','missing-result.wasm'],stderrFd:fd});
   assert.equal(failure.exitCode,1);assert.equal(fs.existsSync(path.join(dir,'missing-result.wasm')),false);
  } finally {fs.closeSync(fd);}
 } finally {fs.rmSync(dir,{recursive:true,force:true});}
});
