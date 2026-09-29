# Installing in a Bitwild project

This guide sets up the shared presets and the `bitwild_lints` plugin in one of
our Dart or Flutter repositories. It takes about ten minutes per repository,
plus the time to fix whatever new diagnostics appear.

## 1. Check the SDK

```sh
dart --version    # or: fvm dart --version
```

| Dart | Flutter | Presets | Plugin |
|---|---|---|---|
| 3.13 or later | 3.47 or later | Yes | Yes, from Git (`plugin.yaml`) |
| 3.11 to 3.12 | 3.41 to 3.44 | Yes | Only from a local checkout (`path:`) |
| 3.10 or earlier | 3.38 or earlier | No | No |

Dart 3.12's analysis server ignores Git plugin sources without an error, so
on Flutter 3.44 the plugin silently does nothing unless you use a local path.
Upgrading to Flutter 3.47 is the simplest way to get the plugin everywhere,
including CI.

## 2. Add the presets

In the package's `pubspec.yaml` (in a pub workspace, the root `pubspec.yaml`):

```yaml
dev_dependencies:
  bitwild_analysis:
    git:
      url: https://github.com/btwld/lints.git
      path: packages/bitwild_analysis
      ref: v0.3.0
```

The presets depend only on `lints` and `flutter_lints`, so they don't
conflict with code generators. You can remove `lints` and `flutter_lints` from
your own dev dependencies unless something else imports them.

## 3. Include them

Replace the `include:` line in `analysis_options.yaml`.

Flutter app or package:

```yaml
include:
  - package:bitwild_analysis/flutter.yaml
  - package:bitwild_analysis/plugin.yaml
```

Pure Dart package:

```yaml
include:
  - package:bitwild_analysis/dart.yaml
  - package:bitwild_analysis/plugin.yaml
```

`plugin.yaml` turns on the recommended plugin rules: the bug checks and the
conventions that rarely fire on existing code. `plugin_all.yaml` also turns
on `blank_line_before_return`, `sort_class_members`, and
`sort_named_arguments`. On a codebase that doesn't follow those conventions
yet they report hundreds to thousands of issues, so start with `plugin.yaml`
and switch once the code is ready (see step 6). Include one or the other, not
both.

On Dart 3.11 or 3.12, drop the `plugin.yaml` line and, if you want the plugin
locally, add it by path to a checkout of this repository:

```yaml
plugins:
  bitwild_lints:
    path: /absolute/path/to/lints/packages/bitwild_lints
```

Keep that path out of shared branches: it only works on your machine.

### Pub workspaces

Configure the workspace once, at the root, and have every member include it:

```yaml
# analysis_options.yaml at the workspace root
include:
  - package:bitwild_analysis/flutter.yaml
  - package:bitwild_analysis/plugin.yaml
```

```yaml
# packages/<member>/analysis_options.yaml
include: ../../analysis_options.yaml
```

Add `bitwild_analysis` to the root `pubspec.yaml`'s dev dependencies so the root
options file resolves. Member options files can add their own rules and
excludes below the `include`.

Two things don't work in a workspace:

- A root options file alone does not reach a member that has its own
  `analysis_options.yaml`. The member must include the root file (or
  `plugin.yaml`).
- A literal `plugins:` block in a member's options file makes the analyzer
  warn `plugins_in_inner_options`. Put `plugins:` blocks, including rule
  overrides, in the root file only.

## 4. Remove what the presets already cover

Delete rules from your `linter: rules:` list that the presets already enable,
and delete the `strict-casts`, `strict-inference`, and `strict-raw-types`
settings. See [`dart.yaml`](../packages/bitwild_analysis/lib/dart.yaml) and
[`flutter.yaml`](../packages/bitwild_analysis/lib/flutter.yaml) for the list.

Keep everything project-specific: `analyzer: exclude:` globs for generated
code (add them if you don't have them; lint rules, including the plugin's,
report on generated files too), `errors:` overrides such as `invalid_annotation_target: ignore`, and
rules the presets don't choose for you, such as `public_member_api_docs`.

If the project configured equivalent checks in another analysis tool, remove
that configuration so the same issue isn't reported twice.

## 5. Restart and analyze

Restart the analysis server so it loads the plugin. In VS Code, run
**Dart: Restart Analysis Server**; in IntelliJ, use the **Dart Analysis**
tool window. Then:

```sh
dart analyze          # or: flutter analyze
```

The first run with the plugin takes longer: the analysis server downloads
the plugin, resolves its dependencies, and compiles it. Later runs reuse
that build.

Two quick fixes are available in the IDE: **Add a blank line before
'return'** and **Sort named arguments**. Plugin fixes are not applied by
`dart fix`; apply them from the IDE.

## 6. Adopt in steps

On an existing codebase, count first and fix second. As a reference, on five
large Bitwild repositories that had never enforced them, each of the ordering
and formatting rules in `plugin_all.yaml` reported between 80 and 4,700
issues; each recommended rule reported 50 at most, and
`unconditional_recursion` reported only a real bug.


```sh
dart analyze > before.txt   # with the old options
dart analyze > after.txt    # with the presets
```

Land the configuration change on its own, with any rules that produce too
many diagnostics turned off, then turn them back on in follow-up changes as
the code is fixed. That keeps each review small.

Changing a public API parameter from positional to named, as
`prefer_named_boolean_parameters` asks, breaks callers. In a published
package, do it in a major release or suppress the diagnostic with a comment.

## Turning things off

A preset rule, in `analysis_options.yaml`:

```yaml
linter:
  rules:
    prefer_single_quotes: false
```

A plugin rule, by repeating the plugin's source with a `diagnostics` entry
(in a workspace, in the root options file):

```yaml
plugins:
  bitwild_lints:
    git:
      url: https://github.com/btwld/lints.git
      path: packages/bitwild_lints
      ref: v0.3.0
    diagnostics:
      sort_class_members: false
```

The same `diagnostics` map changes a rule's severity instead: set it to
`info`, `warning`, or `error`.

## Configuring rules

Rules with options read them from a top-level `bitwild_lints:` section of
`analysis_options.yaml` (in a workspace, the root file). Today that is the
member order of `sort_class_members`; see
[its documentation](../packages/bitwild_lints/README.md#configuring-the-order).

One occurrence, with a comment that says why:

```dart
// ignore: bitwild_lints/prefer_named_boolean_parameters
void setVisible(bool visible, bool animated) {}
```

Or a whole file: `// ignore_for_file: bitwild_lints/sort_class_members`.

## CI

CI needs no extra step: `dart analyze` and `flutter analyze` run the plugin.
Use `--fatal-infos` if lint diagnostics should fail the build. On Dart 3.12,
CI runs the presets but not the plugin (see step 1).

## Updating

Bump `ref:` in the dev dependency. Each preset release pins the matching
plugin release in `plugin.yaml`, so one bump updates both. Read the
[changelog](../packages/bitwild_lints/CHANGELOG.md) for new rules first.

## Troubleshooting

- **No plugin diagnostics at all:** check the Dart version (step 1), check
  that `plugin.yaml` is included in the package's own options file (step 3),
  and restart the analysis server.
- **Plugin diagnostics in the IDE but not in CI, or the reverse:** the two
  are probably using different SDKs. Compare `dart --version` in both.
- **The plugin crashed:** open the analyzer diagnostics page (in VS Code,
  **Dart: Open Analyzer Diagnostics**) and look at the Plugins section.
