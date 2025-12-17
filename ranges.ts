function isPrintable(codePoint: number) {
  // Exclude surrogates explicitly
  if (codePoint >= 0xD800 && codePoint <= 0xDFFF) {
    return false;
  }

  const ch = String.fromCodePoint(codePoint);

  // Unicode "Other" categories (C*)
  return !(
    /\p{Cc}/u.test(ch) || // Control
    /\p{Cf}/u.test(ch) || // Format
    /\p{Cs}/u.test(ch) || // Surrogate (defensive)
    /\p{Co}/u.test(ch) || // Private Use
    /\p{Cn}/u.test(ch)    // Unassigned
  );
}

function generatePrintableRanges() {
  const ranges = [] as [number, number][];

  let rangeStart = null;
  let prev = null;

  for (let cp = 0x0000; cp <= 0x10FFFF; cp++) {
    const printable = isPrintable(cp);

    if (printable) {
      if (rangeStart === null) {
        rangeStart = cp;
      } else if (cp !== prev! + 1) {
        ranges.push([rangeStart, prev!]);
        rangeStart = cp;
      }
      prev = cp;
    } else {
      if (rangeStart !== null) {
        ranges.push([rangeStart, prev!]);
        rangeStart = null;
        prev = null;
      }
    }
  }

  if (rangeStart !== null) {
    ranges.push([rangeStart, prev!]);
  }

  return ranges;
}

console.log(generatePrintableRanges().map(t => `[${t[0]}, ${t[1]}]`).join("\n"));