// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:btwld_rules/src/fixes/sort_named_arguments.dart';
import 'package:btwld_rules/src/rules/sort_named_arguments.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../src/fix_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SortNamedArgumentsTest);
  });
}

@reflectiveTest
class SortNamedArgumentsTest extends AnalysisRuleTest with FixTestSupport {
  @override
  void setUp() {
    rule = SortNamedArguments();
    super.setUp();
  }

  /// Expects one lint on the argument label [label] in [code].
  Future<void> assertLintAt(String code, String label) async {
    await assertDiagnostics(code, [
      lint(code.indexOf('$label:'), label.length),
    ]);
  }

  // Reported.

  Future<void> test_declarationOrder() async {
    await assertLintAt(r'''
void f({int a = 0, int b = 0}) {}

void g() {
  f(b: 1, a: 2);
}
''', 'b');
  }

  Future<void> test_keyFirst() async {
    await assertLintAt(r'''
void f({int a = 0, Object? key}) {}

void g() {
  f(a: 1, key: null);
}
''', 'a');
  }

  Future<void> test_specAfterKey() async {
    await assertLintAt(r'''
void f({int a = 0, Object? spec, Object? key}) {}

void g() {
  f(spec: null, key: null, a: 1);
}
''', 'spec');
  }

  Future<void> test_childLast() async {
    await assertLintAt(r'''
void f({Object? child, int a = 0}) {}

void g() {
  f(child: null, a: 1);
}
''', 'child');
  }

  Future<void> test_childrenLast() async {
    await assertLintAt(r'''
void f({Object? children, int a = 0}) {}

void g() {
  f(children: null, a: 1);
}
''', 'children');
  }

  Future<void> test_childBeforeChildren() async {
    await assertLintAt(r'''
void f({Object? children, Object? child, int a = 0}) {}

void g() {
  f(a: 1, children: null, child: null);
}
''', 'children');
  }

  Future<void> test_positionalInterleaved() async {
    await assertLintAt(r'''
void f(int x, {int a = 0, int b = 0}) {}

void g() {
  f(b: 1, 0, a: 2);
}
''', 'b');
  }

  Future<void> test_constructorInvocation() async {
    await assertLintAt(r'''
class Box {
  const Box({this.key, this.width = 0, this.child});
  final Object? key;
  final int width;
  final Object? child;
}

const box = Box(child: null, key: null);
''', 'child');
  }

  Future<void> test_superConstructorInvocation() async {
    await assertLintAt(r'''
class A {
  A({int a = 0, int b = 0});
}

class B extends A {
  B() : super(b: 1, a: 2);
}
''', 'b');
  }

  Future<void> test_methodDeclaredNonAlphabetically() async {
    // Function types list named parameters alphabetically; the declaration
    // order must come from the method itself.
    await assertLintAt(r'''
class A {
  void m({int b = 0, int a = 0}) {}
}

void g(A x) {
  x.m(a: 2, b: 1);
}
''', 'a');
  }

  // Not reported.

  Future<void>
  test_functionDeclaredNonAlphabetically_inDeclarationOrder() async {
    await assertNoDiagnostics(r'''
void f({int b = 0, int a = 0}) {}

void g() {
  f(b: 1, a: 2);
}
''');
  }

  Future<void> test_methodDeclaredNonAlphabetically_inDeclarationOrder() async {
    await assertNoDiagnostics(r'''
class A {
  void m({int b = 0, int a = 0}) {}
}

void g(A x) {
  x.m(b: 1, a: 2);
}
''');
  }

  Future<void> test_genericMethod_inDeclarationOrder() async {
    await assertNoDiagnostics(r'''
class A<T> {
  void m<S>({T? value, S? other}) {}
}

void g(A<int> x) {
  x.m<String>(value: 1, other: '');
}
''');
  }

  Future<void>
  test_constructorDeclaredNonAlphabetically_inDeclarationOrder() async {
    await assertNoDiagnostics(r'''
class A {
  A({this.b = 0, this.a = 0});

  final int b;
  final int a;
}

final x = A(b: 1, a: 2);
''');
  }

  Future<void> test_functionTypedValue() async {
    // The declaration order of a function type's named parameters isn't
    // recoverable, so calls through function-typed values aren't checked.
    await assertNoDiagnostics(r'''
void g(void Function({int a, int b}) f) {
  f(b: 1, a: 2);
}
''');
  }

  Future<void> test_sorted() async {
    await assertNoDiagnostics(r'''
void f({Object? key, Object? spec, int a = 0, int b = 0, Object? child,
    Object? children}) {}

void g() {
  f(key: null, spec: null, a: 1, b: 2, child: null, children: null);
}
''');
  }

  Future<void> test_sortedWithPositionalBetween() async {
    await assertNoDiagnostics(r'''
void f(int x, {int a = 0, int b = 0}) {}

void g() {
  f(a: 1, 0, b: 2);
}
''');
  }

  Future<void> test_singleNamedArgument() async {
    await assertNoDiagnostics(r'''
void f(int x, {int a = 0}) {}

void g() {
  f(0, a: 1);
}
''');
  }

  Future<void> test_dynamicCall() async {
    await assertNoDiagnostics(r'''
void g(dynamic d) {
  d.f(b: 1, a: 2);
}
''');
  }

  // Fixes.

  Future<void> test_fix_declarationOrder() async {
    const code = r'''
void f({int a = 0, int b = 0}) {}

void g() {
  f(b: 1, a: 2);
}
''';
    await assertLintAt(code, 'b');
    expect(await applyFix(code, SortNamedArgumentsFix.new), r'''
void f({int a = 0, int b = 0}) {}

void g() {
  f(a: 2, b: 1);
}
''');
  }

  Future<void> test_fix_keyAndChildMultiline() async {
    const code = r'''
class Box {
  const Box({this.width = 0, this.key, this.child});
  final int width;
  final Object? key;
  final Object? child;
}

const box = Box(
  child: null,
  width: 1,
  key: null,
);
''';
    await assertLintAt(code, 'child');
    expect(await applyFix(code, SortNamedArgumentsFix.new), r'''
class Box {
  const Box({this.width = 0, this.key, this.child});
  final int width;
  final Object? key;
  final Object? child;
}

const box = Box(
  key: null,
  width: 1,
  child: null,
);
''');
  }

  Future<void> test_fix_keepsPositionalArguments() async {
    const code = r'''
void f(int x, int y, {int a = 0, int b = 0, Object? child}) {}

void g() {
  f(child: null, 0, b: 1, 1, a: 2);
}
''';
    await assertLintAt(code, 'child');
    expect(await applyFix(code, SortNamedArgumentsFix.new), r'''
void f(int x, int y, {int a = 0, int b = 0, Object? child}) {}

void g() {
  f(a: 2, 0, b: 1, 1, child: null);
}
''');
  }
}
