import globals from "globals";
import pluginJs from "@eslint/js";
import tseslint from "typescript-eslint";
import pluginReactConfig from "eslint-plugin-react/configs/recommended.js";


export default [
  {
    ignores: ["lib/**/*", "**/node_modules/", "**/*.config.js"]
  },
  {
    files: ["src/**/*.{js,mjs,cjs,ts,jsx,tsx}"]
  },
  { languageOptions: { parserOptions: { ecmaFeatures: { jsx: true } } } },
  {languageOptions: { globals: globals.browser }},
  pluginJs.configs.recommended,
  ...tseslint.configs.recommended,
  pluginReactConfig,
  {
    rules: {
      "@typescript-eslint/no-explicit-any": 'off',
      'react/react-in-jsx-scope': 'off'
    }
  }
];