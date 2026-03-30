import * as core from "@actions/core";
import * as tc from "@actions/tool-cache";
import * as os from "os";
import * as path from "path";
import * as semver from "semver";
import * as tcp from "./tool-cache-port.js";
import versions from "./versions/perl.json" with { type: "json" };
import { calculateDigest } from "./utils.js";

const osPlat = os.platform();
const osArch = os.arch();

interface PerlVersion {
  arch: string;
  os: string;
  sha256: string;
  thread: boolean;
  url: string;
  version: string;
}

export interface Result {
  // the perl version actually installed.
  version: string;

  // installed path
  path: string;
}

function determineVersion(version: string, thread: boolean): PerlVersion {
  // stable latest version
  if (version === "latest") {
    for (let v of versions) {
      if (v.thread === thread && v.os === osPlat && v.arch === osArch) {
        return v;
      }
    }
    throw new Error(`unable to get the binary for ${version} with thread=${thread}`);
  }

  for (let v of versions) {
    if (semver.satisfies(v.version, version) && v.os === osPlat && v.arch === osArch && v.thread === thread) {
      return v;
    }
  }
  throw new Error(`unable to get the binary for ${version}`);
}

export async function getPerl(version: string, thread: boolean): Promise<Result> {
  const selected = determineVersion(version, thread);

  // check cache
  let toolPath: string;
  const versionSpec = selected.version + (thread ? "-thr" : "");
  toolPath = tcp.find("perl", versionSpec, selected.arch);

  if (!toolPath) {
    // download, extract, cache
    toolPath = await acquirePerl(selected);
    core.debug("Perl tool is cached under " + toolPath);
  }

  const bin = path.join(toolPath, "bin");
  //
  // prepend the tools path. instructs the agent to prepend for future tasks
  //
  core.addPath(bin);

  if (osPlat === "win32") {
    // on Windows, add the path to the Strawberry Perl's C compiler.
    core.addPath("C:\\strawberry\\c\\bin");
  }
  return {
    version: selected.version,
    path: toolPath,
  };
}

async function acquirePerl(version: PerlVersion): Promise<string> {
  //
  // Download - a tool installer intimately knows how to get the tool (and construct urls)
  //
  const downloadUrl = version.url;
  let downloadPath: string | null = null;
  try {
    core.info(`Downloading ${downloadUrl}`);
    downloadPath = await tc.downloadTool(downloadUrl);

    core.debug(`Verify download ${downloadPath}`);
    const actual = await calculateDigest(downloadPath, "sha256");
    if (actual.toLowerCase() !== version.sha256.toLowerCase()) {
      throw new Error(`checksum mismatch: expected ${version.sha256} but got ${actual}`);
    }
  } catch (error) {
    if (error instanceof Error) {
      core.debug(error.message);
    } else {
      core.debug(`${error}`);
    }

    throw new Error(`Failed to download version ${version.version}: ${error}`);
  }

  //
  // Extract compressed archive
  //
  const versionSpec = version.version + (version.thread ? "-thr" : "");
  const extPath = downloadUrl.endsWith(".zip")
    ? await tc.extractZip(downloadPath)
    : await tc.extractTar(downloadPath, "", ["--use-compress-program", "zstd -d --long=30", "-x"]);
  return await tcp.cacheDir(extPath, "perl", versionSpec, version.arch);
}
