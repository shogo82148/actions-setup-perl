import * as core from '@actions/core';
import * as installer from './installer';
import * as path from 'path';
import * as strawberry from './strawberry';

async function run() {
  try {
    const dist = core.getInput('distribution');
    const version = core.getInput('perl-version');
    if (version) {
      switch (dist) {
        case 'strawberry':
          await strawberry.getPerl(version);
          break;
        case 'default':
          await installer.getPerl(version);
          break;
        default:
          throw new Error(`unknown distribution: ${dist}`);
      }
    }

    const matchersPath = path.join(__dirname, '..', '.github');
    console.log(`##[add-matcher]${path.join(matchersPath, 'perl.json')}`);

    // for pre-installed scripts
    core.addPath(path.join(__dirname, '..', 'bin'));

    // for pre-installed modules
    core.exportVariable(
      'PERL5LIB',
      path.join(__dirname, '..', 'scripts', 'lib')
    );
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
