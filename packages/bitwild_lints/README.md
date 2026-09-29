# bitwild_lints

An analyzer plugin with Bitwild's custom lint rules and quick fixes.

Enable it through `package:bitwild_analysis/plugin.yaml`, or directly in
`analysis_options.yaml`:

```yaml
plugins:
  bitwild_lints:
    git:
      url: https://github.com/btwld/lints.git
      path: packages/bitwild_lints
      ref: v0.3.0
```

The Git source needs Dart 3.13 or later; on Dart 3.10 to 3.12, use
`path:` with a local checkout of this repository.

`unconditional_recursion` finds bugs, so it is a warning and on by default.
The other rules are conventions: they are lints. `package:bitwild_analysis/plugin.yaml`
enables the recommended ones and `plugin_all.yaml` enables all of them. Each
can be turned off on its own (see the
[installation guide](../../doc/installing.md#turning-things-off)). Rules that
take options read them from a top-level `bitwild_lints:` section in
`analysis_options.yaml`; today that is `sort_class_members`. Suppress a single
diagnostic with `// ignore: bitwild_lints/<rule_name>`.

| Rule | Kind | Enabled by | Quick fix |
|---|---|---|---|
| [`unconditional_recursion`](#unconditional_recursion) | warning | default |  |
| [`avoid_barrel_imports_in_src`](#avoid_barrel_imports_in_src) | lint | plugin.yaml |  |
| [`avoid_deeply_nested_conditionals`](#avoid_deeply_nested_conditionals) | lint | plugin.yaml |  |
| [`blank_line_before_return`](#blank_line_before_return) | lint | plugin_all.yaml | Add a blank line before 'return' |
| [`prefer_named_boolean_parameters`](#prefer_named_boolean_parameters) | lint | plugin.yaml |  |
| [`sort_class_members`](#sort_class_members) | lint | plugin_all.yaml |  |
| [`sort_named_arguments`](#sort_named_arguments) | lint | plugin_all.yaml | Sort named arguments |

## Rules

### unconditional_recursion

A function or method that calls itself on every path before it can return
never finishes. Synchronous code overflows the stack. `async` code is worse:
each call suspends at an `await` and allocates a new frame, so the process
keeps growing until it runs out of memory, and a test runner's timeout may
never fire.

**Bad**: a one-token edit turned a wrapper into a call to itself:

```dart
Future<void> addRun(RunRecord run) async {
  await createSessionFor(run);
  await addRun(run); // Should be repository.addRun(run).
}
```

**Good**:

```dart
Future<void> addRun(RunRecord run) async {
  await createSessionFor(run);
  await repository.addRun(run);
}
```

The rule reports only calls that every path reaches. It ignores recursion
that can stop:

- calls inside closures, such as tree walks through `visitChildren`;
- calls inside `if`, `switch`, loop bodies, `catch`, `?:` branches, the right
  side of `&&`, `||`, or `??`, null-aware accesses, and `late` initializers;
- calls after a statement that can `return`, `throw`, `break`, `continue`, or
  call a function returning `Never`;
- calls on another object, including `super` and other instances of the same
  class;
- `sync*` and `async*` generators, which can intentionally produce infinite
  sequences.

For a deliberate self-rescheduling loop, prefer `while (true)` or
`Timer.periodic`, or suppress the diagnostic with a comment explaining why.

### avoid_barrel_imports_in_src

Code under `lib/src/` should not import its own package's public re-export
files: libraries outside `lib/src/` that contain `export` directives. Those
files are the package's public API. Depending on them from the
implementation invites import cycles and pulls in more than the file uses.

**Bad**:

```dart
// lib/src/widgets/button.dart
import 'package:my_package/my_package.dart'; // Re-exports src files.
```

**Good**:

```dart
// lib/src/widgets/button.dart
import 'package:my_package/src/theme/colors.dart';
```

Relative imports that resolve to such a file count too. The rule ignores
files outside `lib/src/` (`lib/*.dart`, `test/`, `bin/`), imports from other
packages, public files without `export` directives, and imports of files
under `lib/src/`.

### avoid_deeply_nested_conditionals

Conditional expressions (`?:`) nested more than three levels deep are hard to
read. A conditional's level is one plus the number of conditionals around it,
whether it sits in the condition, the `then` branch, or the `else` branch.
Every conditional at level 4 or deeper is reported. The count restarts inside
a closure, because a closure body is a separate function.

**Bad**:

```dart
String label(int n) => n == 0
    ? 'none'
    : n == 1
    ? 'one'
    : n == 2
    ? 'two'
    : n == 3 // Level 4.
    ? 'three'
    : 'many';
```

**Good**:

```dart
String label(int n) => switch (n) {
  0 => 'none',
  1 => 'one',
  2 => 'two',
  3 => 'three',
  _ => 'many',
};
```

### blank_line_before_return

A `return` that follows other statements in a block is separated from them by
a blank line, so the exit point stands out. Comments directly above the
`return` belong to it, so the blank line goes above them. A `return` that is
the first statement of its block needs no blank line.

**Bad**:

```dart
int total(List<int> items) {
  final sum = items.fold(0, (a, b) => a + b);
  return sum;
}
```

**Good**:

```dart
int total(List<int> items) {
  final sum = items.fold(0, (a, b) => a + b);

  return sum;
}
```

The quick fix inserts the blank line.

### prefer_named_boolean_parameters

A call like `save(user, true)` doesn't say what `true` means. Positional
`bool` or `bool?` parameters, required or optional, are reported in
functions (top-level and local), methods, and constructors, including
`this.flag` parameters.

**Bad**:

```dart
void save(User user, bool overwrite) {}

save(user, true);
```

**Good**:

```dart
void save(User user, {bool overwrite = false}) {}

save(user, overwrite: true);
```

The rule ignores declarations with a single parameter, such as
`setEnabled(bool enabled)`; methods marked `@override` and `super.`
parameters, whose position is set by the supertype (the supertype's own
declaration is still reported when it is in your code); operators and
setters; closures, whose signature comes from the expected callback type; and
the inner parameters of function-typed parameters.

### sort_class_members

Class members follow one predictable order, so readers know where to look and
parallel edits touch the same places. The order is configurable; without
configuration, these defaults apply.

Regular classes:

1. public fields
2. private fields
3. constructors
4. static methods
5. private methods
6. private getters
7. private setters
8. public getters
9. public setters
10. public methods
11. overridden public methods
12. overridden public getters
13. the `build` method

Widget classes (subclasses of Flutter's `Widget` or `State`):

1. constructors
2. `const` fields
3. static methods
4. `final` fields
5. mutable fields
6. the `initState` method
7. private methods
8. overridden public methods
9. the `build` method

**Bad** (with the default order):

```dart
class Cart {
  Cart();

  int total = 0; // Public fields should come before constructors.
}
```

**Good**:

```dart
class Cart {
  int total = 0;

  Cart();
}
```

#### Configuring the order

Set `order` for regular classes and `widgets-order` for widget classes in a
top-level `bitwild_lints:` section of `analysis_options.yaml`. Each list
replaces its default; one you leave out keeps its default.

```yaml
bitwild_lints:
  sort_class_members:
    order:
      - static-fields
      - constructors
      - named-constructors
      - fields
      - getters-setters
      - methods
      - overridden-methods
      - to-json-method
    widgets-order:
      - constructors
      - fields
      - init-state-method
      - dispose-method
      - build-method
```

An entry is either modifiers followed by a group, or a member's name in kebab
case followed by its kind:

- **Groups:** `fields`, `constructors`, `methods`, `getters`, `setters`, and
  `getters-setters` (both).
- **Modifiers:** `public` or `private`; `static`; `overridden` (members marked
  `@override`); for fields, `const`, `final`, or `var`, and `late`; for
  constructors, `named` and `factory`. Combine them, as in
  `overridden-public-getters` or `late-final-fields`.
- **Named members:** `build-method`, `init-state-method`, `to-json-method`,
  `hash-code-getter`, `from-json-constructor`, and so on. The kind is
  singular: `field`, `constructor`, `method`, `getter`, or `setter`.

A group without a modifier matches every value of it: `fields` includes
static and private fields. A member takes the most specific entry it matches.
Named entries are the most specific, then entries with more modifiers, and
ties go to the earlier entry. So with both `static-methods` and
`private-methods`, a private static method counts as a static method.
Members that match no entry can go anywhere, and unrecognized entries are
ignored.

The section follows `include:`, so a workspace can configure the order once in
its root options file, and a project's own file overrides what it includes.
Restart the analysis server after changing it.

The rule checks `class` declarations only, not mixins, enums, extensions, or
extension types. There is no quick fix: moving a member safely means carrying
its comments, annotations, and surrounding blank lines along with it.

### sort_named_arguments

Named arguments appear in the same order everywhere, which makes calls easier
to scan and reduces merge conflicts. The expected order is:

1. `key`, then `spec`;
2. the other named arguments, in the order the invoked function, method, or
   constructor declares its parameters;
3. `child`, then `children`.

Positional arguments are not checked and can stay anywhere.

**Bad**:

```dart
Box(child: const Text('Hi'), key: key, width: 10);
```

**Good**:

```dart
Box(key: key, width: 10, child: const Text('Hi'));
```

The rule ignores argument lists with fewer than two named arguments, and calls
whose named arguments don't resolve to declared parameters, such as calls on
`dynamic`.

The quick fix reorders the named arguments and leaves positional arguments in
place. Reordering also changes the order in which the argument expressions are
evaluated, so check calls whose arguments have side effects.
