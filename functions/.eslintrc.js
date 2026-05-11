module.exports = {
  root: true,
  env: {
    es2020: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
    'google',
    'plugin:@typescript-eslint/recommended',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: ['tsconfig.json'],
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint'],
  rules: {
    'max-len': ['error', {code: 100, ignoreUrls: true}],
    'object-curly-spacing': ['error', 'never'],
    'require-jsdoc': 'off',
  },
};
