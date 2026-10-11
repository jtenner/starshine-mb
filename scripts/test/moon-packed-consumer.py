"""Validate the exact Mooncakes archive, then run an independent source consumer.

Build/package/check: python3 scripts/test/moon-packed-consumer.py
Check an existing archive: python3 scripts/test/moon-packed-consumer.py ARCHIVE.zip
After publication: python3 scripts/test/moon-packed-consumer.py --registry
"""
import hashlib
import json
import pathlib
import re
import os
import subprocess
import signal
import sys
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
VERSION = re.search(r'^version = "([^"\n]+)"$', (ROOT / "moon.mod").read_text(), re.M)[1]
assert VERSION == json.loads((ROOT / "node/package.json").read_text())["version"]
LEGAL = ["LICENSE", "NOTICE", "licenses/Apache-2.0.txt",
         "licenses/Binaryen-LICENSE.txt", "licenses/moonbit-core-NOTICE.txt",
         "src/passes/LICENSE", "src/passes/NOTICE", "tests/spec/LICENSE"]


def run(args, cwd):
    child = subprocess.Popen(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, start_new_session=True,
                             env={**os.environ, "RUST_LOG": "error"})
    try:
        stdout, stderr = child.communicate(timeout=900)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.communicate(timeout=5)
        raise RuntimeError(f"{args}: 900-second deadline; process group terminated")
    if child.returncode:
        raise RuntimeError(f"{args}: exit {child.returncode}\n{stdout[-2000:]}\n{stderr[-6000:]}")
    return stdout


with tempfile.TemporaryDirectory(prefix="starshine-moon-consumer-", dir=ROOT.parent) as scratch:
    base = pathlib.Path(scratch)
    consumer = base / "consumer"
    consumer.mkdir()
    report = {"version": VERSION, "registry": sys.argv[1:] == ["--registry"]}
    if not report["registry"]:
        if len(sys.argv) == 1:
            run(["moon", "package", "--frozen"], ROOT)
            archive = ROOT / f"_build/publish/jtenner-starshine-{VERSION}.zip"
        else:
            archive = pathlib.Path(sys.argv[1]).resolve()
        with zipfile.ZipFile(archive) as z:
            files = z.namelist()
            assert len(files) == len(set(files)), "duplicate archive members"
            for file in files:
                p = pathlib.PurePosixPath(file)
                assert not p.is_absolute() and ".." not in p.parts, file
                assert file in ["moon.mod", "README.md", "README.mooncakes.md", "LICENSE", "NOTICE"] or file.startswith(("src/", "licenses/", "tests/spec/")), f"unexpected archive member: {file}"
                assert z.read(file) == (ROOT / file).read_bytes(), f"packed source drift: {file}"
            for required in ["moon.mod", "README.mooncakes.md", *LEGAL]:
                assert required in files, f"missing distribution/legal file: {required}"
            # Mooncakes renders root README.md, even when metadata names another
            # README. A valid library archive must also have its landing guide.
            assert "README.md" in files, "missing Mooncakes README: README.md"
            for tree in ["src", "tests/spec"]:
                for source in (ROOT / tree).rglob("*"):
                    if source.is_file() and not any(p.startswith(".") for p in source.relative_to(ROOT).parts):
                        assert source.relative_to(ROOT).as_posix() in files, f"missing source/fixture: {source}"
            metadata = z.read("moon.mod").decode()
            assert 'name = "jtenner/starshine"' in metadata
            assert f'version = "{VERSION}"' in metadata
            assert 'repository = "https://github.com/jtenner/starshine-mb"' in metadata
            assert 'license = "Apache-2.0"' in metadata
            assert 'readme = "README.md"' in metadata, "Mooncakes README metadata must name README.md"
            dependency = base / "distribution"
            z.extractall(dependency)
        (base / "moon.work").write_text('members = ["consumer", "distribution"]\n')
        report.update(archive=str(archive), sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), files=len(files), packedBytes=archive.stat().st_size)
    (consumer / "moon.mod").write_text(f'name = "release/consumer"\nversion = "0.0.0"\nimport {{ "jtenner/starshine@{VERSION}", }}\n')
    (consumer / "moon.pkg").write_text('import { "jtenner/starshine/wast", "jtenner/starshine/binary", "jtenner/starshine/validate", "jtenner/starshine/passes", }\npkgtype(kind: "executable")\n')
    (consumer / "main.mbt").write_text('''fn main {
  let input = @wast.wast_to_binary_module("(module (func (export \\\"answer\\\") (result i32) i32.const 40 i32.const 2 i32.add))").unwrap()
  @validate.validate_module(input).unwrap()
  let optimized = @passes.run_hot_pipeline(input, @passes.HotPipelineOptions::new(), ["precompute", "vacuum"]).unwrap()
  @validate.validate_module(optimized).unwrap()
  let bytes = @binary.encode_module(optimized).unwrap()
  let decoded = @binary.decode_module(bytes).unwrap()
  @validate.validate_module(decoded).unwrap()
  try! assert_true(bytes.length() > 8)
  try! assert_true(@wast.wast_to_binary_module("(module (func i32.this_is_invalid))") is Err(_))
  try! assert_true(@binary.decode_module(b"bad") is Err(_))
  println(bytes.to_array().map(byte => byte.to_int()))
  println("Mooncakes consumer: parse/validate/optimize/encode/decode/errors passed")
}
''')
    run(["moon", "update"], consumer)
    output = run(["moon", "run", ".", "--target", "wasm-gc"], consumer)
    assert "errors passed" in output
    wasm = bytes(json.loads(output.splitlines()[0]))
    (consumer / "answer.wasm").write_bytes(wasm)
    runtime = run(["node", "--input-type=module", "-e", "import fs from 'node:fs'; import assert from 'node:assert/strict'; const b = fs.readFileSync('answer.wasm'); assert(WebAssembly.validate(b)); const {instance}=await WebAssembly.instantiate(b); assert.equal(instance.exports.answer(),42); console.log('independent Wasm answer=42');"], consumer)
    report.update(wasmRuntime=runtime.strip())
    report.update(consumer="parse/validate/optimize/encode/decode/errors", output=output.strip())
    print(json.dumps(report, indent=2))
