# btwld lints

Shared static analysis for btwld Dart and Flutter projects.

| Package | What it is |
|---|---|
| [`btwld_lints`](packages/btwld_lints) | Analysis options presets: the Dart and Flutter lint rules our projects share. |
| [`btwld_rules`](packages/btwld_rules) | An [analyzer plugin](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/using_plugins.md) with custom rules and quick fixes that the built-in linter does not provide. |

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
  btwld_lints:
    git:
      url: https://github.com/btwld/lints.git
      path: packages/btwld_lints
      ref: v0.2.0
```

Then, in `analysis_options.yaml`:

```yaml
include:
  - package:btwld_lints/flutter.yaml # or dart.yaml for pure Dart packages
  - package:btwld_lints/plugin.yaml # optional: btwld_rules, recommended rules
```

Restart the analysis server after changing plugin configuration. For pub
workspaces, SDK requirements, overrides, and CI, follow the
[installation guide](doc/installing.md).

## Presets

- `dart.yaml`: `package:lints/recommended.yaml`, the `strict-casts`,
  `strict-inference`, and `strict-raw-types` analyzer modes, and the rules
  most btwld repositories already enable (async and resource safety, likely
  bugs, and shared style).
- `flutter.yaml`: `dart.yaml` plus `package:flutter_lints/flutter.yaml` and
  `prefer_const_constructors`.
- `plugin.yaml`: enables the `btwld_rules` plugin at the matching release,
  with its recommended rules.
- `plugin_all.yaml`: the same plugin with every rule, including the ordering
  and formatting conventions.

## Rules

In the table, *recommended* rules are enabled by `plugin.yaml`; the others
only by `plugin_all.yaml`.

| Rule | Kind | Catches |
|---|---|---|
| [`unconditional_recursion`](packages/btwld_rules/README.md#unconditional_recursion) | warning, recommended | A function or method that calls itself on every path, so it can never return. |
| [`avoid_barrel_imports_in_src`](packages/btwld_rules/README.md#avoid_barrel_imports_in_src) | lint, recommended | Code in `lib/src/` importing its own package's public re-export files. |
| [`avoid_deeply_nested_conditionals`](packages/btwld_rules/README.md#avoid_deeply_nested_conditionals) | lint, recommended | `?:` expressions nested more than three levels deep. |
| [`blank_line_before_return`](packages/btwld_rules/README.md#blank_line_before_return) | lint | A `return` not separated from the statements before it. Has a quick fix. |
| [`prefer_named_boolean_parameters`](packages/btwld_rules/README.md#prefer_named_boolean_parameters) | lint, recommended | Positional `bool` parameters, which make call sites unreadable. |
| [`sort_class_members`](packages/btwld_rules/README.md#sort_class_members) | lint | Class members out of btwld's standard order. |
| [`sort_named_arguments`](packages/btwld_rules/README.md#sort_named_arguments) | lint | Named arguments out of the standard order. Has a quick fix. |

## Development

```sh
dart pub get
dart format .
dart analyze --fatal-infos
(cd packages/btwld_rules && dart test)
```

To add a rule, create it under `packages/btwld_rules/lib/src/rules/`, register
it in `packages/btwld_rules/lib/main.dart`, and add reflective tests under
`packages/btwld_rules/test/rules/` (see the
[testing guide](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/testing_rules.md)).
Document it in the rule table above and in the plugin's README.
