## 0.4.0

- `dart.yaml` adds `avoid_void_async`, `only_throw_errors`,
  `prefer_final_in_for_each`, and `strict_top_level_inference`.
- `dart.yaml` drops `no_adjacent_strings_in_list`. With
  `unnecessary_parenthesis` on, it leaves no clean way to wrap a long string
  inside a list. In five Bitwild repositories it reported 168 times, and the
  reports we checked were deliberate wrapping, not missing commas.
- `flutter.yaml` adds `use_colored_box` and `use_decorated_box`.
- `plugin.yaml` and `plugin_all.yaml` enable `bitwild_lints` 0.4.0.

## 0.3.0

- Rename the package from `btwld_lints` to `bitwild_analysis`. Update the
  dev dependency and `include:` lines.
- `plugin.yaml` and `plugin_all.yaml` enable `bitwild_lints` 0.3.0.

## 0.2.0

- `plugin.yaml` enables the recommended `bitwild_lints` 0.2.0 rules.
- Add `plugin_all.yaml`, which enables every `bitwild_lints` rule.

## 0.1.0

- Initial release with `dart.yaml`, `flutter.yaml`, and `plugin.yaml`.
