# Bitwild lints

Shared static analysis for Bitwild Dart and Flutter projects.

| Package | What it is |
|---|---|
| [`bitwild_analysis`](packages/bitwild_analysis) | Analysis options presets: the Dart and Flutter lint rules our projects share. |
| [`bitwild_lints`](packages/bitwild_lints) | An [analyzer plugin](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/using_plugins.md) with custom rules and quick fixes that the built-in linter does not provide. |

They are separate packages because the plugin depends on a pinned `analyzer`
version. The presets have no such dependency, so adding them never conflicts
with code generators such as `build_runner`, `freezed`, or `json_serializable`.

## Quick start

The presets require Dart 3.11 or later (Flutter 3.41 or later). The plugin
needs a Dart version whose analysis server supports its source:

| Plugin source | Dart | Flutter |
|---|---|---|
| Git (`plugin.yaml`) | 3.13 or later | 3.47 or later |
| Local `path:` | 3.10 or later | 3.38 or later |

Dart 3.12 (Flutter 3.44) ignores Git plugin sources without an error. On
those versions, point the plugin at a local checkout with `path:` until the
package is published to pub.dev.

Add the presets as a dev dependency. Until the packages are published to
pub.dev, use the tagged Git release:

```yaml
dev_dependencies:
  bitwild_analysis:
    git:
      url: https://github.com/btwld/lints.git
      path: packages/bitwild_analysis
      ref: v0.3.0
```

Then, in `analysis_options.yaml`:

```yaml
include:
  - package:bitwild_analysis/flutter.yaml # or dart.yaml for pure Dart packages
  - package:bitwild_analysis/plugin.yaml # optional: bitwild_lints, recommended rules
```

Restart the analysis server after changing plugin configuration. For pub
workspaces, SDK requirements, overrides, and CI, follow the
[installation guide](doc/installing.md).

## Presets

- `dart.yaml`: `package:lints/recommended.yaml`, the `strict-casts`,
  `strict-inference`, and `strict-raw-types` analyzer modes, and the rules
  most Bitwild repositories already enable (async and resource safety, likely
  bugs, and shared style).
- `flutter.yaml`: `dart.yaml` plus `package:flutter_lints/flutter.yaml` and
  `prefer_const_constructors`.
- `plugin.yaml`: enables the `bitwild_lints` plugin at the matching release,
  with its recommended rules.
- `plugin_all.yaml`: the same plugin with every rule, including the ordering
  and formatting conventions.
- `mix.yaml`: adds Mix's own `mix_lint` plugin, for projects that use Mix.
  Include it next to `plugin.yaml` or `plugin_all.yaml`.

## Rules

In the table, *recommended* rules are enabled by `plugin.yaml`; the others
only by `plugin_all.yaml`.

| Rule | Kind | Catches |
|---|---|---|
| [`unconditional_recursion`](packages/bitwild_lints/README.md#unconditional_recursion) | warning, recommended | A function or method that calls itself on every path, so it can never return. |
| [`avoid_barrel_imports_in_src`](packages/bitwild_lints/README.md#avoid_barrel_imports_in_src) | lint, recommended | Code in `lib/src/` importing its own package's public re-export files. |
| [`avoid_deeply_nested_conditionals`](packages/bitwild_lints/README.md#avoid_deeply_nested_conditionals) | lint, recommended | `?:` expressions nested more than three levels deep. |
| [`blank_line_before_return`](packages/bitwild_lints/README.md#blank_line_before_return) | lint | A `return` not separated from the statements before it. Has a quick fix. |
| [`prefer_named_boolean_parameters`](packages/bitwild_lints/README.md#prefer_named_boolean_parameters) | lint, recommended | Positional `bool` parameters, which make call sites unreadable. |
| [`sort_class_members`](packages/bitwild_lints/README.md#sort_class_members) | lint | Class members out of the configured order. Configurable. |
| [`sort_named_arguments`](packages/bitwild_lints/README.md#sort_named_arguments) | lint | Named arguments out of the standard order. Has a quick fix. |

## Development

```sh
dart pub get
dart format .
dart analyze --fatal-infos
(cd packages/bitwild_lints && dart test)
```

To add a rule, create it under `packages/bitwild_lints/lib/src/rules/`, register
it in `packages/bitwild_lints/lib/main.dart`, and add reflective tests under
`packages/bitwild_lints/test/rules/` (see the
[testing guide](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/testing_rules.md)).
Document it in the rule table above and in the plugin's README.
