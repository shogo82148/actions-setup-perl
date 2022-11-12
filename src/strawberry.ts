import * as core from "@actions/core";
import * as tc from "@actions/tool-cache";
import * as path from "path";
import * as semver from "semver";
import * as fs from "fs";
import * as tcp from "./tool-cache-port";
import { getPackagePath } from "./utils";

interface PerlVersion {
  version: string;
  path: string;
}

export interface Result {
  // the perl version actually installed.
  version: string;

  // installed path
  path: string;
}

// NOTE:
// I don't know why, but 5.18.3 is missing.
// {
//   version: '5.18.3',
//   path: 'strawberry-perl-5.18.3.1-64bit-portable.zip'
// },
// I don't know why, but 5.14.1 and 5.14.0 are missing.
// {
//   version: '5.14.1',
//   path: 'strawberry-perl-5.14.1.1-64bit-portable.zip'
// },
// {
//   version: '5.14.0',
//   path: 'strawberry-perl-5.14.0.1-64bit-portable.zip'
// },
// 64 bit Portable binaries are not available with Perl 5.12.x and older.
async function getAvailableVersions(): Promise<PerlVersion[]> {
  return new Promise<PerlVersion[]>((resolve, reject) => {
    fs.readFile(path.join(getPackagePath(), "versions", `strawberry.json`), (err, data) => {
      if (err) {
        reject(err);
      }
      const info = JSON.parse(data.toString()) as PerlVersion[];
      resolve(info);
    });
  });
}

async function determineVersion(version: string): Promise<PerlVersion> {
  const availableVersions = await getAvailableVersions();
  // stable latest version
  if (version === "latest") {
    return availableVersions[0];
  }

  for (let v of availableVersions) {
    if (semver.satisfies(v.version, version)) {
      return v;
    }
  }
  throw new Error("unable to get latest version");
}

export async function getPerl(version: string): Promise<Result> {
  // check cache
  const selected = await determineVersion(version);
  let toolPath: string;
  toolPath = tcp.find("perl", selected.version);

  if (!toolPath) {
    // download, extract, cache
    toolPath = await acquirePerl(selected);
    core.debug("Perl tool is cached under " + toolPath);
  }

  // remove pre-installed Strawberry Perl and MinGW from Path
  let pathEnv = (process.env.PATH || "").split(path.delimiter);
  pathEnv = pathEnv.filter((p) => !p.match(/.*(?:Strawberry|mingw).*/i));

  // add our new Strawberry Portable Perl Paths
  // from portableshell.bat https://github.com/StrawberryPerl/Perl-Dist-Strawberry/blob/9fb00a653ce2e6ed336045dd0a180409b98a72a9/share/portable/portableshell.bat#L5
  pathEnv.unshift(path.join(toolPath, "c", "bin"));
  pathEnv.unshift(path.join(toolPath, "perl", "bin"));
  pathEnv.unshift(path.join(toolPath, "perl", "site", "bin"));
  core.exportVariable("PATH", pathEnv.join(path.delimiter));

  core.addPath(path.join(toolPath, "c", "bin"));
  core.addPath(path.join(toolPath, "perl", "bin"));
  core.addPath(path.join(toolPath, "perl", "site", "bin"));

  return {
    version: selected.version,
    path: path.join(toolPath, "perl"),
  };
}

async function acquirePerl(version: PerlVersion): Promise<string> {
  //
  // Download - a tool installer intimately knows how to get the tool (and construct urls)
  //

  // download from a mirror for actions-setup-perl
  const downloadUrl = `https://setupperl.blob.core.windows.net/actions-setup-perl/strawberry-perl/${version.path}`;
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

  const extPath = await tc.extractZip(downloadPath);
  return await tcp.cacheDir(extPath, "strawberry-perl", version.version);
}
