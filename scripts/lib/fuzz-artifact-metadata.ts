import { createHash } from "node:crypto";

export type FuzzArtifactMetadataInput = {
  rawBytes?: Buffer | Uint8Array;
  rawText?: string;
  normalizedCanonicalBytes?: Buffer | Uint8Array;
  normalizedCanonicalText?: string;
};

export type FuzzArtifactMetadata = {
  schema: "starshine.fuzz.artifact-metadata.v1";
  rawByteLength?: number;
  rawBytesSha256?: string;
  rawTextLength?: number;
  rawTextSha256?: string;
  normalizedCanonicalByteLength?: number;
  normalizedCanonicalBytesSha256?: string;
  normalizedCanonicalTextLength?: number;
  normalizedCanonicalTextSha256?: string;
};

function sha256Hex(data: Buffer | Uint8Array | string): string {
  return createHash("sha256").update(data).digest("hex");
}

export function buildFuzzArtifactMetadata(input: FuzzArtifactMetadataInput): FuzzArtifactMetadata {
  const metadata: FuzzArtifactMetadata = { schema: "starshine.fuzz.artifact-metadata.v1" };
  if (input.rawBytes !== undefined) {
    metadata.rawByteLength = input.rawBytes.byteLength;
    metadata.rawBytesSha256 = sha256Hex(input.rawBytes);
  }
  if (input.rawText !== undefined) {
    metadata.rawTextLength = input.rawText.length;
    metadata.rawTextSha256 = sha256Hex(input.rawText);
  }
  if (input.normalizedCanonicalBytes !== undefined) {
    metadata.normalizedCanonicalByteLength = input.normalizedCanonicalBytes.byteLength;
    metadata.normalizedCanonicalBytesSha256 = sha256Hex(input.normalizedCanonicalBytes);
  }
  if (input.normalizedCanonicalText !== undefined) {
    metadata.normalizedCanonicalTextLength = input.normalizedCanonicalText.length;
    metadata.normalizedCanonicalTextSha256 = sha256Hex(input.normalizedCanonicalText);
  }
  return metadata;
}
