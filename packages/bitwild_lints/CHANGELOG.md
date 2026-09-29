## 0.3.0

- Rename the package from `btwld_rules` to `bitwild_lints`. Update `plugins:`
  entries and `// ignore: btwld_rules/...` comments.
- `sort_class_members` reads its order from the top-level `bitwild_lints:`
  section of `analysis_options.yaml` (`order` and `widgets-order`), following
  `include:`. Without configuration the previous order applies.

## 0.2.0

- Add `avoid_barrel_imports_in_src`, `avoid_deeply_nested_conditionals`,
  `blank_line_before_return`, `prefer_named_boolean_parameters`,
  `sort_class_members`, and `sort_named_arguments`.
- Add quick fixes for `blank_line_before_return` and `sort_named_arguments`.

## 0.1.0

- Initial release with `unconditional_recursion`.
