import * as core from "@actions/core";
import * as tc from "@actions/tool-cache";
import * as os from "os";
import { readFile } from "fs/promises";
import * as path from "path";
import * as semver from "semver";
import * as tcp from "./tool-cache-port";

const osPlat = os.platform();
const osArch = os.arch();

export interface Result {
  // the perl version actually installed.
  version: string;

  // installed path
  path: string;
}

async function readJSON<T>(path: string): Promise<T> {
  const data = await readFile(path, "utf8");
  return JSON.parse(data) as T;
}
async function getAvailableVersions(): Promise<string[]> {
  const filename = path.join(__dirname, "..", "versions", `${osPlat}.json`);
  return readJSON<string[]>(filename);
}

async function determineVersion(version: string): Promise<string> {
  const availableVersions = await getAvailableVersions();

  // stable latest version
  if (version === "latest") {
    return availableVersions[0];
  }

  for (let v of availableVersions) {
    if (semver.satisfies(v, version)) {
      return v;
    }
  }
  throw new Error("unable to get latest version");
}

export async function getPerl(version: string, thread: boolean): Promise<Result> {
  const selected = await determineVersion(version);

  // check cache
  let toolPath: string;
  toolPath = tcp.find("perl", selected);

  if (!toolPath) {
    // download, extract, cache
    toolPath = await acquirePerl(selected, thread);
    core.debug("Perl tool is cached under " + toolPath);
  }

  const bin = path.join(toolPath, "bin");
  //
  // prepend the tools path. instructs the agent to prepend for future tasks
  //
  core.addPath(bin);

  return {
    version: selected,
    path: toolPath,
  };
}

async function acquirePerl(version: string, thread: boolean): Promise<string> {
  //
  // Download - a tool installer intimately knows how to get the tool (and construct urls)
  //
  const fileName = getFileName(version, thread);
  const downloadUrl = await getDownloadUrl(fileName);
  let downloadPath: string | null = null;
  try {
    downloadPath = await tc.downloadTool(downloadUrl);
  } catch (error) {
    if (error instanceof Error) {
      core.debug(error.message);
    } else {
      core.debug(`${error}`);
    }

    throw new Error(`Failed to download version ${version}: ${error}`);
  }

  //
  // Extract compressed archive
  //
  const extPath = downloadUrl.endsWith(".zip")
    ? await tc.extractZip(downloadPath)
    : await tc.extractTar(downloadPath, "", ["--use-compress-program", "zstd -d --long=30", "-x"]);
  return await tcp.cacheDir(extPath, "perl", version + (thread ? "-thr" : ""));
}

function getFileName(version: string, thread: boolean): string {
  const suffix = thread ? "-multi-thread" : "";
  const ext = osPlat === "win32" ? "zip" : "tar.zstd";
  return `perl-${version}-${osPlat}-${osArch}${suffix}.${ext}`;
}

interface PackageVersion {
  version: string;
}

async function getDownloadUrl(filename: string): Promise<string> {
  const pkg = path.join(__dirname, "..", "package.json");
  const info = await readJSON<PackageVersion>(pkg);
  const actionsVersion = info.version;
  return `https://github.com/shogo82148/actions-setup-perl/releases/download/v${actionsVersion}/${filename}`;
}
