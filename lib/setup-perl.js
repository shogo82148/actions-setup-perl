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
    if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = __importStar(require("@actions/core"));
const installer = __importStar(require("./installer"));
const path = __importStar(require("path"));
const strawberry = __importStar(require("./strawberry"));
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
        // for cpanm and carton
        core.addPath(path.join(__dirname, '..', 'bin'));
    }
    catch (error) {
        core.setFailed(error.message);
    }
}
run();
