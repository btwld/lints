# bitwild_analysis

Analysis options presets for Bitwild Dart and Flutter projects.

```yaml
include:
  - package:bitwild_analysis/flutter.yaml # or dart.yaml for pure Dart packages
  - package:bitwild_analysis/plugin.yaml # optional: bitwild_lints, recommended rules
```

| Preset | Contents |
|---|---|
| `dart.yaml` | `package:lints/recommended.yaml`, strict analyzer modes, and Bitwild's shared rules. |
| `flutter.yaml` | `dart.yaml` plus `package:flutter_lints/flutter.yaml` and `prefer_const_constructors`. |
| `plugin.yaml` | The [`bitwild_lints`](../bitwild_lints) analyzer plugin at the matching release, with its recommended rules. |
| `plugin_all.yaml` | The same plugin with every rule, including the ordering and formatting conventions. Use instead of `plugin.yaml`. |

The rule selection comes from the rules most active Bitwild repositories already
enable on top of the official sets. Rules that conflict with the tall-style
formatter (`require_trailing_commas`) or with established member ordering
(`sort_constructors_first`) are left out. Project-specific choices such as
`public_member_api_docs` or import style stay in each project's own options.

To turn off a rule from a preset, set it to `false` in your
`analysis_options.yaml`:

```yaml
linter:
  rules:
    prefer_single_quotes: false
```
