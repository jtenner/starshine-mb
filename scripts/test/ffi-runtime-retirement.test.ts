import { expect, test } from "bun:test";
import { readFile } from "node:fs/promises";

test("the removed Dew runtime builder is intentionally absent from the public FFI", async () => {
  const source = await readFile(
    new URL("../../src/ffi_bridge/pkg.generated.mbti", import.meta.url),
    "utf8",
  );
  expect(source).not.toContain("RuntimeFunctionBuilder");
  expect(source).not.toContain("runtime_function_builder_new");
  expect(source).not.toContain("funcs_push_runtime");
});
