// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:btwld_rules/src/rules/sort_class_members.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SortClassMembersTest);
  });
}

@reflectiveTest
class SortClassMembersTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = SortClassMembers();
    super.setUp();
  }

  /// Expects one lint per `(text, message)` pair, on the first occurrence of
  /// `text` in [code], with a message containing `message`.
  Future<void> assertLints(String code, List<(String, String)> lints) =>
      assertDiagnostics(code, [
        for (final (text, message) in lints)
          lint(code.indexOf(text), text.length, messageContainsAll: [message]),
      ]);

  // Regular classes: reported.

  Future<void> test_fieldAfterConstructor() async {
    const code = r'''
class A {
  A();
  int value = 0;
}
''';
    await assertLints(code, [
      ('value', 'Public fields should come before constructors.'),
    ]);
  }

  Future<void> test_constructorAfterMethod_reportedAtConstructorName() async {
    const code = r'''
class A {
  void run() {}
  A.named();
}
''';
    await assertLints(code, [
      ('A.named', 'Constructors should come before public methods.'),
    ]);
  }

  Future<void> test_staticMethodAfterPrivateMethod() async {
    const code = r'''
class A {
  void _helper() {}
  static void create() {}
  void run() => _helper();
}
''';
    await assertLints(code, [
      ('create', 'Static methods should come before private methods.'),
    ]);
  }

  Future<void> test_privateStaticMethodCountsAsStaticMethod() async {
    const code = r'''
class A {
  void _helper() {}
  static void _create() {}
  void run() {
    _create();
    _helper();
  }
}
''';
    await assertLints(code, [
      ('_create', 'Static methods should come before private methods.'),
    ]);
  }

  Future<void> test_privateMethodAfterPublicGetter() async {
    const code = r'''
class A {
  int get total => 0;
  void _helper() {}
  void run() => _helper();
}
''';
    await assertLints(code, [
      ('_helper', 'Private methods should come before public getters.'),
    ]);
  }

  Future<void> test_publicMethodAfterOverriddenMethod() async {
    const code = r'''
class A {
  @override
  String toString() => '';
  void run() {}
}
''';
    await assertLints(code, [
      ('run', 'Public methods should come before overridden public methods.'),
    ]);
  }

  Future<void> test_buildNotLast() async {
    const code = r'''
class A {
  void build() {}
  void run() {}
}
''';
    await assertLints(code, [
      ('run', 'Public methods should come before the build method.'),
    ]);
  }

  Future<void> test_everyOutOfOrderMemberReported() async {
    const code = r'''
class A {
  A();
  int first = 0;
  int second = 0;
}
''';
    await assertLints(code, [
      ('first', 'Public fields should come before constructors.'),
      ('second', 'Public fields should come before constructors.'),
    ]);
  }

  // Regular classes: not reported.

  Future<void> test_regularOrder() async {
    await assertNoDiagnostics(r'''
abstract class Base {
  int get size;
  void run();
}

class A extends Base {
  static int count = 0;
  int value = 0;
  int _hidden = 0;

  A();
  A.named();

  static A create() => A();

  void _helper() {
    _hidden.toString();
  }

  int get _secret => _hidden;
  set _secret(int next) => _hidden = next;

  int get total => _secret;
  set total(int next) => value = next;

  void reset() {
    _helper();
    _secret = 0;
  }

  @override
  void run() {}

  @override
  int get size => 0;

  void build() {}
}
''');
  }

  Future<void> test_mixinsEnumsAndExtensionsNotChecked() async {
    await assertNoDiagnostics(r'''
mixin M {
  void run() {}
  int value = 0;
}

enum E {
  a;

  void run() {}
  final int value = 0;
}

extension X on int {
  void run() {}
  static int value = 0;
}
''');
  }

  // Widget classes.

  Future<void> test_widgetOrder() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  static const step = 1;
  final label = 'count';
  var count = 0;

  @override
  void initState() {
    super.initState();
    _increment();
  }

  void _increment() => count += step;

  @override
  Widget build(BuildContext context) => Text('$label $count');

  int get doubled => count * 2;

  void reset() => count = 0;
}
''');
  }

  Future<void> test_widgetInitStateAfterBuild() async {
    const code = r'''
import 'package:flutter/widgets.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  @override
  Widget build(BuildContext context) => Text('');

  @override
  void initState() {
    super.initState();
  }
}
''';
    await assertLints(code, [
      (
        'initState',
        'The initState method should come before the build method.',
      ),
    ]);
  }

  Future<void> test_widgetFinalFieldAfterMutableField() async {
    const code = r'''
import 'package:flutter/widgets.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  var count = 0;
  final label = 'count';

  @override
  Widget build(BuildContext context) => Text('$label $count');
}
''';
    await assertLints(code, [
      ('label', 'Final fields should come before mutable fields.'),
    ]);
  }

  Future<void> test_widgetConstFieldAfterFinalField() async {
    const code = r'''
import 'package:flutter/widgets.dart';

class Label extends StatelessWidget {
  const Label({super.key});

  final text = 'label';
  static const prefix = '>';

  @override
  Widget build(BuildContext context) => Text('$prefix $text');
}
''';
    await assertLints(code, [
      ('prefix', 'Const fields should come before final fields.'),
    ]);
  }
}
