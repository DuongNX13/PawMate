module.exports = {
  root: true,
  ignorePatterns: ['dist'],
  env: {
    node: true,
    es2022: true,
  },
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: ['./tsconfig.json', './tsconfig.eslint.json'],
    tsconfigRootDir: process.cwd(),
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint', 'import'],
  extends: ['airbnb-base', 'plugin:@typescript-eslint/recommended', 'prettier'],
  settings: {
    'import/parsers': { '@typescript-eslint/parser': ['.ts', '.tsx', '.d.ts'] },
    'import/resolver': {
      node: { extensions: ['.mjs', '.js', '.json', '.ts', '.d.ts'] },
    },
    'import/extensions': ['.js', '.mjs', '.jsx', '.ts', '.tsx', '.d.ts'],
    'import/external-module-folders': ['node_modules', 'node_modules/@types'],
  },
  rules: {
    'import/prefer-default-export': 'off',
    'no-class-assign': 'error',
    'no-with': 'error',
    // Preserve the previous resolved semantic rules without Airbnb TS's v7 peer.
    // v8 removed formatting rules; Prettier remains the existing formatter.
    camelcase: 'off',
    'default-param-last': 'off',
    'dot-notation': 'off',
    'no-empty-function': 'off',
    'no-implied-eval': 'off',
    'no-new-func': 'off',
    'no-loop-func': 'off',
    'no-redeclare': 'off',
    'no-shadow': 'off',
    'no-throw-literal': 'off',
    'no-unused-expressions': 'off',
    'no-use-before-define': 'off',
    'no-useless-constructor': 'off',
    'no-return-await': 'off',
    '@typescript-eslint/naming-convention': [
      'error',
      {
        selector: 'variable',
        format: ['camelCase', 'PascalCase', 'UPPER_CASE'],
      },
      { selector: 'function', format: ['camelCase', 'PascalCase'] },
      { selector: 'typeLike', format: ['PascalCase'] },
    ],
    '@typescript-eslint/default-param-last': 'error',
    '@typescript-eslint/dot-notation': [
      'error',
      {
        allowKeywords: true,
        allowPattern: '',
        allowPrivateClassPropertyAccess: false,
        allowProtectedClassPropertyAccess: false,
        allowIndexSignaturePropertyAccess: false,
      },
    ],
    // Core rule replaces the removed TS formatting extension, not an off switch.
    'lines-between-class-members': [
      'error',
      'always',
      { exceptAfterSingleLine: false },
    ],
    '@typescript-eslint/no-dupe-class-members': 'error',
    '@typescript-eslint/no-empty-function': [
      'error',
      { allow: ['arrowFunctions', 'functions', 'methods'] },
    ],
    '@typescript-eslint/no-implied-eval': 'error',
    'no-loss-of-precision': 'error',
    '@typescript-eslint/no-loop-func': 'error',
    '@typescript-eslint/no-redeclare': 'error',
    '@typescript-eslint/no-shadow': 'error',
    // Renamed in v8; retain the previous throw-error protection.
    '@typescript-eslint/only-throw-error': 'error',
    '@typescript-eslint/no-unused-expressions': [
      'error',
      {
        allowShortCircuit: false,
        allowTernary: false,
        allowTaggedTemplates: false,
        enforceForJSX: false,
      },
    ],
    '@typescript-eslint/no-unused-vars': [
      'error',
      { vars: 'all', args: 'after-used', ignoreRestSiblings: true },
    ],
    '@typescript-eslint/no-use-before-define': [
      'error',
      { functions: true, classes: true, variables: true },
    ],
    '@typescript-eslint/no-useless-constructor': 'error',
    '@typescript-eslint/return-await': ['error', 'in-try-catch'],
    'import/extensions': [
      'error',
      'ignorePackages',
      { js: 'never', mjs: 'never', jsx: 'never', ts: 'never', tsx: 'never' },
    ],
  },
  overrides: [
    {
      files: ['*.ts', '*.tsx'],
      // Compiler-owned checks are disabled exactly as in the old TS config.
      rules: {
        'constructor-super': 'off',
        'getter-return': 'off',
        'no-const-assign': 'off',
        'no-dupe-args': 'off',
        'no-dupe-class-members': 'off',
        'no-dupe-keys': 'off',
        'no-func-assign': 'off',
        'no-import-assign': 'off',
        'no-new-symbol': 'off',
        'no-obj-calls': 'off',
        'no-redeclare': 'off',
        'no-setter-return': 'off',
        'no-this-before-super': 'off',
        'no-undef': 'off',
        'no-unreachable': 'off',
        'no-unsafe-negation': 'off',
        'valid-typeof': 'off',
        'import/named': 'off',
        'import/no-named-as-default-member': 'off',
        'import/no-unresolved': 'off',
      },
    },
    {
      files: ['tests/**/*.ts', 'jest.config.cjs'],
      env: {
        jest: true,
      },
      rules: {
        'import/no-extraneous-dependencies': [
          'error',
          { devDependencies: true },
        ],
      },
    },
  ],
};
