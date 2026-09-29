// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/utilities/utilities.dart';
import 'package:bitwild_lints/src/rules/sort_class_members.dart';
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

  /// Expects one lint on [token], found inside the first occurrence of
  /// [anchor] in [code], with a message containing [message].
  Future<void> assertLintOn(
    String code,
    String anchor,
    String token,
    String message,
  ) => assertDiagnostics(code, [
    lint(
      code.indexOf(anchor) + anchor.indexOf(token),
      token.length,
      messageContainsAll: [message],
    ),
  ]);

  /// Enables the rule with [section] appended to the test package's
  /// `analysis_options.yaml`.
  void configure(String section) {
    newAnalysisOptionsYamlFile(
      testPackageRootPath,
      '${analysisOptionsContent(rules: [rule.name])}\n$section',
    );
  }

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

  // Configuration.

  Future<void> test_config_customOrder() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order:
      - constructors
      - fields
      - methods
''');
    const code = r'''
class A {
  A();
  int value = 0;
  void run() {}
}

class B {
  int value = 0;
  B();
}
''';
    await assertLintOn(
      code,
      'B();',
      'B',
      'Constructors should come before fields.',
    );
  }

  Future<void> test_config_namedEntries() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order:
      - constructors
      - from-json-constructor
      - fields
      - to-json-method
      - methods
''');
    const code = r'''
class A {
  A();
  int value = 0;
  A.fromJson(Map<String, Object?> json);
  void run() {}
}
''';
    await assertLintOn(
      code,
      'A.fromJson(',
      'A.fromJson',
      'The fromJson constructor should come before fields.',
    );
  }

  Future<void> test_config_namedEntryOutranksModifiers() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order:
      - to-json-method
      - public-methods
''');
    const code = r'''
class A {
  Map<String, Object?> toJson() => {};
  void run() {}
}

class B {
  void run() {}
  Map<String, Object?> toJson() => {};
}
''';
    await assertLintOn(
      code,
      'toJson() => {};\n}',
      'toJson',
      'The toJson method should come before public methods.',
    );
  }

  Future<void> test_config_gettersAndSettersGroup() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order:
      - fields
      - getters-setters
      - methods
''');
    const code = r'''
class A {
  int _value = 0;
  void run() {}
  int get value => _value;
}
''';
    await assertLintOn(
      code,
      'get value',
      'value',
      'Getters and setters should come before methods.',
    );
  }

  Future<void> test_config_fieldAndConstructorModifiers() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order:
      - static-fields
      - late-final-fields
      - fields
      - factory-constructors
      - named-constructors
      - constructors
''');
    const code = r'''
class A {
  static int count = 0;
  late final int total;
  int value = 0;
  factory A.create() => A();
  A.named();
  A();
  late final int extra;
}
''';
    await assertLints(code, [
      ('extra', 'Late final fields should come before constructors.'),
    ]);
  }

  Future<void> test_config_invalidEntriesIgnored() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order:
      - not-a-group
      - fields
      - private-bananas
      - constructors
''');
    const code = r'''
class A {
  A();
  int value = 0;
}
''';
    await assertLints(code, [
      ('value', 'Fields should come before constructors.'),
    ]);
  }

  Future<void> test_config_emptyOrderUsesDefault() async {
    configure('''
bitwild_lints:
  sort_class_members:
    order: []
''');
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

  Future<void> test_config_widgetsOrder() async {
    configure('''
bitwild_lints:
  sort_class_members:
    widgets-order:
      - build-method
      - constructors
''');
    const code = r'''
import 'package:flutter/widgets.dart';

class A extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox();
  const A({super.key});
}

class B extends StatelessWidget {
  const B({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    await assertLintOn(
      code,
      'build(BuildContext context) => const SizedBox();\n}\n',
      'build',
      'The build method should come before constructors.',
    );
  }

  Future<void> test_config_fromRelativeInclude() async {
    newFile('$testPackageRootPath/shared.yaml', '''
bitwild_lints:
  sort_class_members:
    order:
      - constructors
      - fields
''');
    newAnalysisOptionsYamlFile(
      testPackageRootPath,
      analysisOptionsContent(includes: ['shared.yaml'], rules: [rule.name]),
    );
    const code = r'''
class A {
  int value = 0;
  A();
}
''';
    await assertLintOn(
      code,
      'A();',
      'A',
      'Constructors should come before fields.',
    );
  }

  Future<void> test_config_fromPackageInclude() async {
    newPackage('shared_options').addFile('lib/options.yaml', '''
bitwild_lints:
  sort_class_members:
    order:
      - constructors
      - fields
''');
    // Packages added after setUp must be written to the package config again.
    writeTestPackageConfig2();
    newAnalysisOptionsYamlFile(
      testPackageRootPath,
      analysisOptionsContent(
        includes: ['package:shared_options/options.yaml'],
        rules: [rule.name],
      ),
    );
    const code = r'''
class A {
  int value = 0;
  A();
}
''';
    await assertLintOn(
      code,
      'A();',
      'A',
      'Constructors should come before fields.',
    );
  }

  Future<void> test_config_localOverridesInclude() async {
    newFile('$testPackageRootPath/shared.yaml', '''
bitwild_lints:
  sort_class_members:
    order:
      - constructors
      - fields
''');
    newAnalysisOptionsYamlFile(testPackageRootPath, '''
${analysisOptionsContent(includes: ['shared.yaml'], rules: [rule.name])}
bitwild_lints:
  sort_class_members:
    order:
      - fields
      - constructors
''');
    const code = r'''
class A {
  A();
  int value = 0;
}
''';
    await assertLints(code, [
      ('value', 'Fields should come before constructors.'),
    ]);
  }
}
