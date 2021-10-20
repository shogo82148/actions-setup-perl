import * as core from "@actions/core";
import * as installer from "./installer";
import * as path from "path";
import * as strawberry from "./strawberry";
import * as utils from "./utils";
import * as cpan from "./cpan-installer";

async function run() {
  try {
    const platform = process.platform;
    let dist = core.getInput("distribution");
    const multiThread = core.getInput("multi-thread");
    const version = core.getInput("perl-version");

    let result: installer.Result;
    await core.group("install perl", async () => {
      let thread: boolean;
      if (platform === "win32") {
        thread = utils.parseBoolean(multiThread || "true");
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
        thread = utils.parseBoolean(multiThread || "false");
      }

      if (version) {
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
        core.setOutput("perl-hash", result.hash);
      }

      const matchersPath = path.join(__dirname, "..", ".github");
      console.log(`##[add-matcher]${path.join(matchersPath, "perl.json")}`);

      // for pre-installed scripts
      core.addPath(path.join(__dirname, "..", "bin"));

      // for pre-installed modules
      core.exportVariable("PERL5LIB", path.join(__dirname, "..", "scripts", "lib"));
    });

    await core.group("install CPAN modules", async () => {
      await cpan.install({
        perlHash: result.hash,
        toolPath: result.path,
        install_modules_with: core.getInput("install-modules-with"),
        install_modules_args: core.getInput("install-modules-args"),
        install_modules: core.getInput("install-modules"),
        enable_modules_cache: utils.parseBoolean(core.getInput("enable-modules-cache")),
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

run();
