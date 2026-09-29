# Adding a rule

Every rule in `bitwild_lints` follows the same shape. Copy an existing rule
that is close to what you need.

## 1. Decide what it is

- **Name:** snake_case, using the vocabulary of Dart's built-in lints:
  `avoid_`, `prefer_`, `sort_`, or a plain noun phrase for a bug
  (`unconditional_recursion`). Check that no built-in lint already does the
  job; `dart.dev/tools/linter-rules` lists them all.
- **Warning or lint:** a rule that finds bugs is a warning, registered with
  `registerWarningRule` and on by default. A style or convention rule is a
  lint, registered with `registerLintRule` and enabled in
  `packages/bitwild_analysis/lib/plugin.yaml`.
- **Options:** the plugin API passes rules only enabled and severity. A rule
  that needs options reads them with `RuleOptions.forRule` from the
  `bitwild_lints:` section of `analysis_options.yaml` (see
  `lib/src/config.dart`), and must behave well with none. Prefer a good
  built-in default over an option.

## 2. Write it

- The rule goes in `packages/bitwild_lints/lib/src/rules/<name>.dart`: a class
  extending `AnalysisRule` with a `static const LintCode code`, and a
  `SimpleAstVisitor` registered for the narrowest node types that work.
- A quick fix goes in `lib/src/fixes/<name>.dart`, as a
  `ResolvedCorrectionProducer`. Offer one only when the change is
  mechanical and safe. Share the detection logic between the rule and the
  fix instead of duplicating it.
- Register both in `lib/main.dart`.
- Prefer resolved elements over names: compare elements, not identifiers,
  so shadowing and prefixes are handled.
- Take declaration order from the declaring element, never from a
  `FunctionType`: function types list named parameters alphabetically.
- Keep false positives near zero. When unsure whether a case is a problem,
  don't report it.

## 3. Test it

Tests go in `test/rules/<name>_test.dart`, using `AnalysisRuleTest` from
`analyzer_testing`:

- One test per reported case and one per deliberately ignored case.
- Quick fixes: mix in `FixTestSupport` and assert the exact output of
  `applyFix`.
- The test SDK is minimal (no `StateError`, for example). Stub packages with
  `newPackage` in `setUp`.

## 4. Check it against this repository

This repository runs every rule on itself through `analysis_options.yaml` at
the root, with the member order configured to its style, and CI fails on any
diagnostic. A new rule that fires on this code base is either finding real
issues to fix here, or it is wrong.

## 5. Check it against real code

Before releasing, enable the plugin by `path:` in a throwaway worktree of a
few large Bitwild repositories and run `dart analyze`. Add a file with a
deliberate violation to each package first, and confirm each one is
reported. That proves the rule ran there, so an otherwise empty result
really means no false positives.

## 6. Document it

Add the rule to the table in the root `README.md`, add a section with a bad
and a good example to `packages/bitwild_lints/README.md`, and add a changelog
entry.

## Releasing

1. Bump `version` in both packages' `pubspec.yaml` and update both
   changelogs.
2. Update `ref:` in `packages/bitwild_analysis/lib/plugin.yaml` and in the docs
   to the new tag.
3. Merge, then tag `vX.Y.Z` on `main` and push the tag.
