# btwld_rules

An analyzer plugin with btwld's custom lint rules and quick fixes.

Enable it through `package:btwld_lints/plugin.yaml`, or directly in
`analysis_options.yaml`:

```yaml
plugins:
  btwld_rules:
    git:
      url: https://github.com/btwld/lints.git
      path: packages/btwld_rules
      ref: v0.1.0
```

Rules registered as warnings are on by default. Suppress a diagnostic with
`// ignore: btwld_rules/<rule_name>`.

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
