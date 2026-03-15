// See: https://rollupjs.org/introduction/

import commonjs from "@rollup/plugin-commonjs";
import json from "@rollup/plugin-json";
import nodeResolve from "@rollup/plugin-node-resolve";
import typescript from "@rollup/plugin-typescript";

const sharedPlugins = [typescript({ declaration: false }), json(), nodeResolve({ preferBuiltins: true }), commonjs()];

const config = [
  {
    input: "src/setup-perl.ts",
    output: {
      esModule: true,
      file: "dist/setup/index.js",
      format: "es",
      sourcemap: true,
    },
    plugins: sharedPlugins,
  },
  {
    input: "src/cache-save.ts",
    output: {
      esModule: true,
      file: "dist/cache-save/index.js",
      format: "es",
      sourcemap: true,
    },
    plugins: sharedPlugins,
  },
];

export default config;
