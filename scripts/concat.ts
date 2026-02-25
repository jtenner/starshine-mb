for await (const file of new Bun.Glob("src/**/*.mbt").scan()) {
  const text = await Bun.file(file).text()
  console.log(`// ${file}`);
  console.log(text);
  console.log("");
}

export {}