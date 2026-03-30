import * as path from "path";
import { fileURLToPath } from "url";
import * as fs from "fs";
import * as crypto from "crypto";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export function parseBoolean(s: string): boolean {
  // YAML 1.0 compatible boolean values
  switch (s) {
    case "y":
    case "Y":
    case "yes":
    case "Yes":
    case "YES":
    case "true":
    case "True":
    case "TRUE":
      return true;
    case "n":
    case "N":
    case "no":
    case "No":
    case "NO":
    case "false":
    case "False":
    case "FALSE":
      return false;
  }
  throw `invalid boolean value: ${s}`;
}

export function getPackagePath(): string {
  if (process.env["ACTIONS_SETUP_PERL_TESTING"]) {
    return path.join(__dirname, "..");
  }
  return path.join(__dirname, "..", "..");
}

export async function calculateDigest(filename: string, algorithm: string): Promise<string> {
  const hash = await new Promise<string>((resolve, reject) => {
    const hash = crypto.createHash(algorithm);
    const stream = fs.createReadStream(filename);
    stream.on("data", (data) => hash.update(data));
    stream.on("end", () => resolve(hash.digest("hex")));
    stream.on("error", (err) => reject(err));
  });
  return hash;
}
