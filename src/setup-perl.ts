import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as installer from "./installer";
import * as path from "path";
import * as crypto from "crypto";
import * as fs from "fs/promises";
import * as strawberry from "./strawberry";
import * as cpan from "./cpan-installer";
import { getPackagePath, parseBoolean } from "./utils";

async function run() {
  try {
    const platform = process.platform;
    let dist = core.getInput("distribution");
    const multiThread = core.getInput("multi-thread");
    const version = await resolveVersionInput();

    let result: installer.Result;
    let perlHash: string;
    await core.group("install perl", async () => {
      let thread: boolean;
      if (platform === "win32") {
        thread = parseBoolean(multiThread || "true");
        if (dist === "strawberry" && !thread) {
          core.warning("non-thread Strawberry Perl is not provided.");
        }
      } else {
        if (dist === "strawberry") {
          core.warning(
            "The strawberry distribution is not available on this platform. fallback to the default distribution."
          );
          dist = "default";
        }
        thread = parseBoolean(multiThread || "false");
      }

      switch (dist) {
        case "strawberry":
          result = await strawberry.getPerl(version);
          break;
        case "default":
          result = await installer.getPerl(version, thread);
          break;
        default:
          throw new Error(`unknown distribution: ${dist}`);
      }
      core.setOutput("perl-version", result.version);
      perlHash = await digestOfPerlVersion(result.path);
      core.setOutput("perl-hash", perlHash);

      const matchersPath = path.join(getPackagePath(), "scripts");
      console.log(`::add-matcher::${path.join(matchersPath, "perl.json")}`);

      // for pre-installed scripts
      core.addPath(path.join(getPackagePath(), "bin"));

      // for pre-installed modules
      core.exportVariable("PERL5LIB", path.join(getPackagePath(), "scripts", "lib"));
    });

    await core.group("install CPAN modules", async () => {
      await cpan.install({
        perlHash: perlHash,
        toolPath: result.path,
        install_modules_with: core.getInput("install-modules-with"),
        install_modules_args: core.getInput("install-modules-args"),
        install_modules: core.getInput("install-modules"),
        enable_modules_cache: parseBoolean(core.getInput("enable-modules-cache")),
        working_directory: core.getInput("working-directory"),
      });
    });
  } catch (error) {
    if (error instanceof Error) {
      core.setFailed(error);
    } else {
      core.setFailed(`${error}`);
    }
  }
}

// we use `perl -V` to the cache key.
// it contains useful information to use as the cache key,
// e.g. the platform, the version of perl, the compiler option for building perl
async function digestOfPerlVersion(toolPath: string): Promise<string> {
  const perl = path.join(toolPath, "bin", "perl");
  const hash = crypto.createHash("sha256");
  await exec.exec(perl, ["-V"], {
    listeners: {
      stdout: (data: Buffer) => {
        hash.update(data);
      },
    },
    env: {},
  });
  hash.end();
  return hash.digest("hex");
}

async function resolveVersionInput(): Promise<string> {
  let version = core.getInput("perl-version");
  const versionFile = core.getInput("perl-version-file");
  if (version && versionFile) {
    core.warning("Both perl-version and perl-version-file inputs are specified, only perl-version will be used");
  }
  if (version) {
    return version;
  }

  const versionFilePath = path.join(process.env.GITHUB_WORKSPACE || "", versionFile || ".perl-version");
  version = await fs.readFile(versionFilePath, "utf8");
  core.info(`Resolved ${versionFile} as ${version}`);
  return version;
}

run();
