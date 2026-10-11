"""Run every tutorial example from an exact Mooncakes archive.

Before publication: python3 scripts/test/moon-readme-consumer.py ARCHIVE.zip
After moon-packed-consumer.py: python3 scripts/test/moon-readme-consumer.py
After publication: python3 scripts/test/moon-readme-consumer.py --registry
The registry mode executes the documented moon add command without overrides.
"""
import hashlib
import json
import os
import pathlib
import re
import resource
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
VERSION = re.search(r'^version = "([^"\n]+)"$', (ROOT / "moon.mod").read_text(), re.M)[1]
REGISTRY = sys.argv[1:] == ["--registry"]
REPORT = {"version": VERSION, "registry": REGISTRY, "commands": []}


def run(command, cwd, expect_error=None, env_override=None):
    args = shlex.split(command) if isinstance(command, str) else command
    child = subprocess.Popen(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, start_new_session=True,
                             env={**os.environ, "RUST_LOG": "error", **(env_override or {})})
    try:
        out, err = child.communicate(timeout=900)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.communicate(timeout=5)
        raise RuntimeError(f"{args}: 900-second deadline; process group terminated")
    REPORT["commands"].append({"args": args, "exit": child.returncode, **({"envOverride": env_override} if env_override else {})})
    if expect_error is None:
        assert child.returncode == 0, f"{args}: {out[-2000:]}\n{err[-6000:]}"
    else:
        assert child.returncode != 0, f"invalid operation succeeded: {args}"
        assert expect_error in out + err, f"missing error {expect_error}: {out[-2000:]}\n{err[-3000:]}"
    return out


def execute_wasm(path, cwd):
    return run(["node", "--input-type=module", "-e",
                "import fs from 'node:fs'; import assert from 'node:assert/strict'; "
                "const bytes=fs.readFileSync(process.argv[1]); assert(WebAssembly.validate(bytes)); "
                "const {instance}=await WebAssembly.instantiate(bytes); "
                "assert.equal(instance.exports.answer(),42); console.log('answer=42');", str(path)], cwd).strip()


# Native compilation on the pinned compiler needs this per-process limit.
# This does not change the user's shell or system limits.
soft, hard = resource.getrlimit(resource.RLIMIT_STACK)
resource.setrlimit(resource.RLIMIT_STACK, (min(64 * 1024 * 1024, hard) if hard != resource.RLIM_INFINITY else 64 * 1024 * 1024, hard))

with tempfile.TemporaryDirectory(prefix="starshine-readme-consumer-", dir=ROOT.parent) as scratch:
    base = pathlib.Path(scratch)
    os.environ["TMPDIR"] = str(base / "compiler-tmp")
    pathlib.Path(os.environ["TMPDIR"]).mkdir()
    if REGISTRY:
        archive = base / f"starshine-{VERSION}.zip"
        urllib.request.urlretrieve(f"https://download.mooncakes.io/user/jtenner/starshine/{VERSION}.zip", archive)
    else:
        assert len(sys.argv) <= 2, __doc__
        archive = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else ROOT / f"_build/publish/jtenner-starshine-{VERSION}.zip"
    with zipfile.ZipFile(archive) as z:
        readme = z.read("README.md").decode()
        metadata = z.read("moon.mod").decode()
        assert f'version = "{VERSION}"' in metadata
        if not REGISTRY:
            for name in z.namelist():
                p = pathlib.PurePosixPath(name)
                assert not p.is_absolute() and ".." not in p.parts, name
            z.extractall(base / "distribution")
    REPORT.update(archiveSha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                  readmeSha256=hashlib.sha256(readme.encode()).hexdigest())
    marked = re.findall(r'<!-- STARSHINE_TUTORIAL (\w+) -->\s*```(\w+)\n(.*?)\n```', readme, re.S)
    assert len(marked) == 5 and {item[0] for item in marked} == {"package", "optimizer", "text", "input", "file"}, "missing/duplicate tutorial examples"
    blocks = {name: content + "\n" for name, language, content in marked}
    assert len(re.findall(r'```(?:moon|mbt|wat)\n', readme)) == len(marked), "unqualified code example"
    commands = [block.strip() for block in re.findall(r'```sh\n(.*?)\n\s*```', readme, re.S)]
    # This ordered inventory fails if a new command is added without execution.
    expected = ["moon version --all", "cc --version", "ulimit -s 65536", "moon new answer-tool", "cd answer-tool",
                f"moon add jtenner/starshine@{VERSION}", "moon update", "moon run cmd/main --target wasm-gc",
                "moon run cmd/main --target native", "moon run cmd/main --target native"]
    assert commands == expected, f"tutorial command inventory changed: {commands}"
    REPORT["toolchains"] = {command: run(command, base).strip() for command in commands[:2]}
    REPORT["independentWasmHost"] = run("node --version", base).strip()
    assert resource.getrlimit(resource.RLIMIT_STACK)[0] >= 64 * 1024 * 1024
    REPORT["nativeStackBytes"] = resource.getrlimit(resource.RLIMIT_STACK)[0]
    commands.pop(2)  # ulimit is a shell builtin; its documented effect is applied above.
    run(commands[2], base)
    consumer = base / "answer-tool"
    assert consumer.is_dir()  # documented cd target
    if REGISTRY:
        run(commands[4], consumer)
    else:
        with (consumer / "moon.mod").open("a") as f:
            f.write(f'\nimport {{ "jtenner/starshine@{VERSION}", }}\n')
        (base / "moon.work").write_text('members = ["answer-tool", "distribution"]\n')
        REPORT["installOverride"] = "prepublication exact-archive workspace; moon add is tested after publication"
    main = consumer / "cmd/main"
    (main / "moon.pkg").write_text(blocks["package"])
    (main / "optimizer.mbt").write_text(blocks["optimizer"])
    (main / "main.mbt").write_text(blocks["text"])
    run(commands[5], consumer)
    for command in commands[6:8]:
        if "wasm-gc" in command:
            # MoonBit's WasmGC runtime must work without Node in PATH.
            moon_only_path = str(pathlib.Path(shutil.which("moon")).parent)
            assert shutil.which("node", path=moon_only_path) is None
            out = run(command, consumer, env_override={"PATH": moon_only_path})
            REPORT["wasmGcRuntime"] = "bundled moonrun; Node absent from process PATH"
        else:
            out = run(command, consumer)
        assert "Wasm header is valid." in out, "missing beginner success check in actual MoonBit example"
        encoded = bytes(json.loads(out.strip().splitlines()[0]))
        artifact = consumer / "printed.wasm"
        artifact.write_bytes(encoded)
        assert execute_wasm(artifact, consumer) == "answer=42"
    (consumer / "input.wat").write_text(blocks["input"])
    (main / "main.mbt").write_text(blocks["file"])
    assert "Wrote answer.wasm" in run(commands[8], consumer)
    answer = consumer / "answer.wasm"
    assert execute_wasm(answer, consumer) == "answer=42"
    good = answer.read_bytes()
    (consumer / "input.wat").write_text("(module (func i32.this_is_invalid))")
    run(commands[8], consumer, "Cannot parse WAT:")
    assert answer.read_bytes() == good, "parse failure called the writer"
    (consumer / "input.wat").write_text('(module (func (result i32) f64.const 0))')
    run(commands[8], consumer, "Cannot validate input:")
    assert answer.read_bytes() == good, "validation failure called the writer"
    (consumer / "input.wat").unlink()
    run(commands[8], consumer, "input.wat")
    assert answer.read_bytes() == good
    (consumer / "input.wat").write_text(blocks["input"])
    answer.unlink()
    answer.mkdir()  # unsupported output path: writer must return an error
    run(commands[8], consumer, "answer.wasm")
    answer.rmdir()
    run(commands[8], consumer)
    assert execute_wasm(answer, consumer) == "answer=42"
    REPORT["library"] = {"targets": ["wasm-gc", "native"], "textAndFileAnswer": 42,
                          "errors": ["parse", "validation", "missing-input", "output-is-directory"],
                          "prewriteFailurePreservesExistingOutput": True}
    REPORT["tutorial"] = "actual archived MoonBit library examples; no JavaScript or npm CLI example substitution"
    print(json.dumps(REPORT, indent=2))
