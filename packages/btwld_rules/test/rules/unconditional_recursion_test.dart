// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:btwld_rules/src/rules/unconditional_recursion.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnconditionalRecursionTest);
  });
}

@reflectiveTest
class UnconditionalRecursionTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = UnconditionalRecursion();
    super.setUp();
  }

  /// Expects one lint on the [nth] occurrence of `name(` in [code].
  Future<void> assertLintAt(String code, String name, {int nth = 1}) async {
    var offset = -1;
    for (var i = 0; i < nth; i++) {
      offset = code.indexOf('$name(', offset + 1);
    }
    await assertDiagnostics(code, [lint(offset, name.length)]);
  }

  // Reported.

  Future<void> test_asyncLocalHelper_callsItselfInsteadOfWrappedMethod() async {
    // A wrapper that a bulk edit turned into a call to itself.
    await assertLintAt(
      r'''
class Repository {
  Future<void> addRun(String run) async {}
}

Future<void> createSessionFor(String run) async {}

void main() {
  final repository = Repository();

  Future<void> addRun(String run) async {
    await createSessionFor(run);
    await addRun(run);
  }

  repository.addRun('r1');
  addRun('r2');
}
''',
      'addRun',
      nth: 3,
    );
  }

  Future<void> test_topLevelFunction() async {
    await assertLintAt(
      r'''
void f(int n) {
  print(n);
  f(n - 1);
}
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_expressionBody() async {
    await assertLintAt(
      r'''
int f(int n) => f(n) + 1;
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_instanceMethod_implicitThis() async {
    await assertLintAt(
      r'''
class A {
  void m() {
    m();
  }
}
''',
      'm',
      nth: 2,
    );
  }

  Future<void> test_instanceMethod_explicitThis() async {
    await assertLintAt(
      r'''
class A {
  void m() {
    this.m();
  }
}
''',
      'm',
      nth: 2,
    );
  }

  Future<void> test_staticMethod_viaClassName() async {
    await assertLintAt(
      r'''
class A {
  static void m() {
    A.m();
  }
}
''',
      'm',
      nth: 2,
    );
  }

  Future<void> test_insideIfCondition() async {
    await assertLintAt(
      r'''
bool f() {
  if (f()) return true;
  return false;
}
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_insideTryBody() async {
    await assertLintAt(
      r'''
void f() {
  try {
    f();
  } catch (_) {}
}
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_leftOperandOfShortCircuit() async {
    await assertLintAt(
      r'''
bool f(bool b) => f(b) && b;
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_variableInitializer() async {
    await assertLintAt(
      r'''
int f() {
  final x = f();
  return x;
}
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_unawaitedInAsyncBody() async {
    await assertLintAt(
      r'''
Future<void> f() async {
  await Future<void>.delayed(Duration.zero);
  f();
}
''',
      'f',
      nth: 2,
    );
  }

  Future<void> test_reportedOncePerDeclaration() async {
    await assertLintAt(
      r'''
void f() {
  f();
  f();
}
''',
      'f',
      nth: 2,
    );
  }

  // Not reported.

  Future<void> test_guardedByEarlyReturn() async {
    await assertNoDiagnostics(r'''
void f(int n) {
  if (n == 0) return;
  f(n - 1);
}
''');
  }

  Future<void> test_insideIfBranch() async {
    await assertNoDiagnostics(r'''
void f(int n) {
  if (n > 0) {
    f(n - 1);
  }
}
''');
  }

  Future<void> test_insideConditionalBranch() async {
    await assertNoDiagnostics(r'''
int f(int n) => n == 0 ? 0 : f(n - 1);
''');
  }

  Future<void> test_rightOperandOfShortCircuit() async {
    await assertNoDiagnostics(r'''
bool f(bool b) => b && f(!b);
''');
  }

  Future<void> test_ifNullOperand() async {
    await assertNoDiagnostics(r'''
int f(int? cached) => cached ?? f(0);
''');
  }

  Future<void> test_treeWalkInsideClosure() async {
    await assertNoDiagnostics(r'''
class Node {
  final List<Node> children = [];
  void visitChildren(bool Function(Node) visitor) {
    children.forEach(visitor);
  }
}

void main() {
  final nodes = <Node>[];
  void visit(Node node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(Node());
}
''');
  }

  Future<void> test_sameNameMethodOnAnotherObject() async {
    await assertNoDiagnostics(r'''
class Repository {
  Future<void> addRun(String run) async {}
}

void main() {
  final repository = Repository();

  Future<void> addRun(String run) async {
    await repository.addRun(run);
  }

  addRun('r1');
}
''');
  }

  Future<void> test_delegatingWrapperClass() async {
    await assertNoDiagnostics(r'''
abstract class Closeable {
  Future<void> close();
}

class Logged implements Closeable {
  Logged(this.inner);
  final Closeable inner;

  @override
  Future<void> close() => inner.close();
}
''');
  }

  Future<void> test_superCall() async {
    await assertNoDiagnostics(r'''
class A {
  void dispose() {}
}

class B extends A {
  @override
  void dispose() {
    super.dispose();
  }
}
''');
  }

  Future<void> test_differentInstanceOfSameClass() async {
    await assertNoDiagnostics(r'''
class Node {
  Node? next;
  int length() => 1 + (next?.length() ?? 0);
}
''');
  }

  Future<void> test_generator() async {
    await assertNoDiagnostics(r'''
Iterable<int> naturals(int n) sync* {
  yield n;
  yield* naturals(n + 1);
}
''');
  }

  Future<void> test_lateInitializer() async {
    await assertNoDiagnostics(r'''
int f() {
  late final x = f();
  return 0;
}
''');
  }

  Future<void> test_afterThrow() async {
    await assertNoDiagnostics(r'''
void f(bool fail) {
  if (fail) throw 'stop';
  f(fail);
}
''');
  }

  Future<void> test_afterCallReturningNever() async {
    await assertNoDiagnostics(r'''
Never stop() => throw 'stop';

void f(bool done) {
  if (done) stop();
  f(done);
}
''');
  }

  Future<void> test_insideCatch() async {
    await assertNoDiagnostics(r'''
void f() {
  try {
    print('');
  } catch (_) {
    f();
  }
}
''');
  }

  Future<void> test_insideLoopBody() async {
    await assertNoDiagnostics(r'''
void f(List<int> items) {
  for (final item in items) {
    f([item]);
  }
}
''');
  }

  Future<void> test_tearOffPassedToScheduler() async {
    await assertNoDiagnostics(r'''
void poll() {
  Future<void>.delayed(const Duration(seconds: 1), poll);
}
''');
  }
}
