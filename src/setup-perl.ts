import * as core from '@actions/core';
import * as installer from './installer';
import * as path from 'path';
import * as strawberry from './strawberry';

async function run() {
  try {
    const platform = process.platform;
    let dist = core.getInput('distribution');
    const multiThread = core.getInput('multi-thread');
    const version = core.getInput('perl-version');

    let thread: boolean;
    if (platform === 'win32') {
      thread = parseBoolean(multiThread || 'true');
      if (dist === 'strawberry' && !thread) {
        core.warning('non-thread Strawberry Perl is not provided.');
      }
    } else {
      if (dist === 'strawberry') {
        core.warning(
          'The strawberry distribution is not available on this platform. fallback to the default distribution.'
        );
        dist = 'default';
      }
      thread = parseBoolean(multiThread || 'false');
    }

    if (version) {
      switch (dist) {
        case 'strawberry':
          await strawberry.getPerl(version);
          break;
        case 'default':
          await installer.getPerl(version, thread);
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
    core.exportVariable('PERL5LIB', path.join(__dirname, '..', 'scripts', 'lib'));
  } catch (error) {
    core.setFailed(error.message);
  }
}

function parseBoolean(s: string): boolean {
  // YAML 1.0 compatible boolean values
  switch (s) {
    case 'y':
    case 'Y':
    case 'yes':
    case 'Yes':
    case 'YES':
    case 'true':
    case 'True':
    case 'TRUE':
      return true;
    case 'n':
    case 'N':
    case 'no':
    case 'No':
    case 'NO':
    case 'false':
    case 'False':
    case 'FALSE':
      return false;
  }
  throw `invalid boolean value: ${s}`;
}

run();
