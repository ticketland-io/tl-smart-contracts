module.exports = {
  env: {
    browser: true,
    es2021: true,
  },
  extends: [
    'plugin:react/recommended',
    'airbnb',
  ],
  overrides: [],
  parserOptions: {
    ecmaVersion: 12,
    sourceType: 'module',
  },
  plugins: [
    'react',
  ],
  rules: {
    'object-curly-spacing': ['error', 'never'],
    'arrow-parens': ['error', 'as-needed'],
    semi: ['error', 'never'],
    'react/function-component-definition': ['off'],
    'react/prop-types': ['off'],
    'jsx-quotes': ['error', 'prefer-single'],
    'no-return-await': ['off'],
    'jsx-a11y/alt-text': ['off'],
    'react/jsx-one-expression-per-line': ['off'],
    'react/jsx-props-no-spreading': ['off'],
    'react/no-array-index-key': ['off'],
    'jsx-a11y/no-noninteractive-element-interactions': ['off'],
    'jsx-a11y/click-events-have-key-events': ['off'],
    'no-confusing-arrow': [
      'error',
      {allowParens: true, onlyOneSimpleParam: true},
    ],
    'import/prefer-default-export': ['off'],
    'max-len': ['error', {code: 130}],
    'no-use-before-define': ['off'],
    'no-unused-vars': ['error', {
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^_',
      caughtErrorsIgnorePattern: '^_',
    }],
    camelcase: 'off',
  },
}
