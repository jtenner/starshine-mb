"""Run only the legacy spec runner's argument tests, without changing its code."""

from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    source_path = root / "src/spec_runner/spec_runner.mbt"
    source = source_path.read_text()
    start = source.index("fn spec_runner_normalize_args(")
    end = source.find("\n///|", start)
    if end == -1:
        end = len(source)
    # Compile the actual function verbatim. Do not copy its implementation into
    # a test double or repair the unrelated legacy imports and executable target.
    function = source[start:end]
    with tempfile.TemporaryDirectory(prefix="starshine-f14-") as directory:
        module = Path(directory)
        package = module / "src/args"
        package.mkdir(parents=True)
        (module / "moon.mod").write_text(
            'name = "verification/spec-runner-paths"\nsource = "src"\n'
        )
        (package / "moon.pkg").write_text("")
        (package / "normalize.mbt").write_text("///|\n" + function)
        shutil.copyfile(
            Path(__file__).with_name("path_args_wbtest.mbt"),
            package / "path_args_wbtest.mbt",
        )
        command = ["moon", "test", "--target", "native", "src/args"]
        print(f"Source: {source_path.relative_to(root)} (verbatim function)", flush=True)
        print("Temporary package command: " + " ".join(command), flush=True)
        return subprocess.run(command, cwd=module, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
