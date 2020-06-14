"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPerl = void 0;
// Load tempDirectory before it gets wiped by tool-cache
let tempDirectory = process.env['RUNNER_TEMPDIRECTORY'] || '';
const core = __importStar(require("@actions/core"));
const tc = __importStar(require("@actions/tool-cache"));
const path = __importStar(require("path"));
const semver = __importStar(require("semver"));
const installer = __importStar(require("./installer"));
if (!tempDirectory) {
    let baseLocation;
    if (process.platform === 'win32') {
        // On windows use the USERPROFILE env variable
        baseLocation = process.env['USERPROFILE'] || 'C:\\';
    }
    else if (process.platform === 'darwin') {
        baseLocation = '/Users';
    }
    else {
        baseLocation = '/home';
    }
    tempDirectory = path.join(baseLocation, 'actions', 'temp');
}
// availableVersions must be sorted in descending order by the version.
const availableVersions = [
    {
        version: '5.30.2',
        path: 'strawberry-perl-5.30.2.1-64bit-portable.zip'
    },
    {
        version: '5.30.1',
        path: 'strawberry-perl-5.30.1.1-64bit-portable.zip'
    },
    {
        version: '5.30.0',
        path: 'strawberry-perl-5.30.0.1-64bit-portable.zip'
    },
    {
        version: '5.28.2',
        path: 'strawberry-perl-5.28.2.1-64bit-portable.zip'
    },
    {
        version: '5.28.1',
        path: 'strawberry-perl-5.28.1.1-64bit-portable.zip'
    },
    {
        version: '5.28.0',
        path: 'strawberry-perl-5.28.0.1-64bit-portable.zip'
    },
    {
        version: '5.26.3',
        path: 'strawberry-perl-5.26.3.1-64bit-portable.zip'
    },
    {
        version: '5.26.2',
        path: 'strawberry-perl-5.26.2.1-64bit-portable.zip'
    },
    {
        version: '5.26.1',
        path: 'strawberry-perl-5.26.1.1-64bit-portable.zip'
    },
    {
        version: '5.26.0',
        path: 'strawberry-perl-5.26.0.2-64bit-portable.zip'
    },
    {
        version: '5.24.4',
        path: 'strawberry-perl-5.24.4.1-64bit-portable.zip'
    },
    {
        version: '5.24.3',
        path: 'strawberry-perl-5.24.3.1-64bit-portable.zip'
    },
    {
        version: '5.24.2',
        path: 'strawberry-perl-5.24.2.1-64bit-portable.zip'
    },
    {
        version: '5.24.1',
        path: 'strawberry-perl-5.24.1.1-64bit-portable.zip'
    },
    {
        version: '5.24.0',
        path: 'strawberry-perl-5.24.0.1-64bit-portable.zip'
    },
    {
        version: '5.22.3',
        path: 'strawberry-perl-5.22.3.1-64bit-portable.zip'
    },
    {
        version: '5.22.2',
        path: 'strawberry-perl-5.22.2.1-64bit-portable.zip'
    },
    {
        version: '5.22.1',
        path: 'strawberry-perl-5.22.1.3-64bit-portable.zip'
    },
    {
        version: '5.22.0',
        path: 'strawberry-perl-5.22.0.1-64bit-portable.zip'
    },
    {
        version: '5.20.3',
        path: 'strawberry-perl-5.20.3.3-64bit-portable.zip'
    },
    {
        version: '5.20.2',
        path: 'strawberry-perl-5.20.2.1-64bit-portable.zip'
    },
    {
        version: '5.20.1',
        path: 'strawberry-perl-5.20.1.1-64bit-portable.zip'
    },
    {
        version: '5.20.0',
        path: 'strawberry-perl-5.20.0.1-64bit-portable.zip'
    },
    {
        version: '5.18.4',
        path: 'strawberry-perl-5.18.4.1-64bit-portable.zip'
    },
    // I don't know why, but 5.18.3 is missing.
    // {
    //   version: '5.18.3',
    //   path: 'strawberry-perl-5.18.3.1-64bit-portable.zip'
    // },
    {
        version: '5.18.2',
        path: 'strawberry-perl-5.18.2.2-64bit-portable.zip'
    },
    {
        version: '5.18.1',
        path: 'strawberry-perl-5.18.1.1-64bit-portable.zip'
    },
    {
        version: '5.18.0',
        path: 'strawberry-perl-5.18.0.1-64bit-portable.zip'
    },
    {
        version: '5.16.2',
        path: 'strawberry-perl-5.16.2.2-64bit-portable.zip'
    },
    {
        version: '5.16.1',
        path: 'strawberry-perl-5.16.1.1-64bit-portable.zip'
    },
    {
        version: '5.16.0',
        path: 'strawberry-perl-5.16.0.1-64bit-portable.zip'
    },
    {
        version: '5.14.4',
        path: 'strawberry-perl-5.14.4.1-64bit-portable.zip'
    },
    {
        version: '5.14.3',
        path: 'strawberry-perl-5.14.3.1-64bit-portable.zip'
    },
    {
        version: '5.14.2',
        path: 'strawberry-perl-5.14.2.1-64bit-portable.zip'
    }
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
];
function determineVersion(version) {
    for (let v of availableVersions) {
        if (semver.satisfies(v.version, version)) {
            return v;
        }
    }
    throw new Error('unable to get latest version');
}
async function getPerl(version) {
    if (process.platform !== 'win32') {
        core.info('The strawberry distribution is not available on this platform');
        core.info('fallback to the default distribution');
        installer.getPerl(version);
        return;
    }
    // check cache
    const selected = determineVersion(version);
    let toolPath;
    toolPath = tc.find('perl', selected.version);
    if (!toolPath) {
        // download, extract, cache
        toolPath = await acquirePerl(selected);
        core.debug('Perl tool is cached under ' + toolPath);
    }
    const perlPath = path.join(toolPath, 'perl', 'bin');
    const cPath = path.join(toolPath, 'c', 'bin');
    core.addPath(perlPath);
    core.addPath(cPath); // for gcc-mingw bundled with strawberry perl
}
exports.getPerl = getPerl;
async function acquirePerl(version) {
    //
    // Download - a tool installer intimately knows how to get the tool (and construct urls)
    //
    // download from a mirror for actions-setup-perl
    const downloadUrl = `https://shogo82148-actions-setup-perl.s3.amazonaws.com/strawberry-perl/${version.path}`;
    let downloadPath = null;
    try {
        downloadPath = await tc.downloadTool(downloadUrl);
    }
    catch (error) {
        core.debug(error);
        throw `Failed to download version ${version.version}: ${error}`;
    }
    //
    // Extract
    //
    let extPath = tempDirectory;
    if (!extPath) {
        throw new Error('Temp directory not set');
    }
    extPath = await tc.extractZip(downloadPath);
    return await tc.cacheDir(extPath, 'perl', version.version);
}
