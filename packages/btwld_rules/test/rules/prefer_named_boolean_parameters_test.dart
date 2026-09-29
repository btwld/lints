// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:btwld_rules/src/rules/prefer_named_boolean_parameters.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferNamedBooleanParametersTest);
  });
}

@reflectiveTest
class PreferNamedBooleanParametersTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferNamedBooleanParameters();
    super.setUp();
  }

  /// Expects one lint on the parameter named [name], found after [after].
  Future<void> assertLintOn(String code, String name, {String after = ''}) =>
      assertDiagnostics(code, [
        lint(code.indexOf(name, code.indexOf(after)), name.length),
      ]);

  // Reported.

  Future<void> test_topLevelFunction_requiredPositional() async {
    await assertLintOn(r'''
void save(String name, bool overwrite) {}
''', 'overwrite');
  }

  Future<void> test_optionalPositional_nullable() async {
    await assertLintOn(r'''
void save(String name, [bool? overwrite]) {}
''', 'overwrite');
  }

  Future<void> test_optionalPositional_withDefault() async {
    await assertLintOn(r'''
void save(String name, [bool overwrite = false]) {}
''', 'overwrite');
  }

  Future<void> test_eachBooleanReported() async {
    const code = r'''
void save(String name, bool overwrite, bool backup) {}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('overwrite'), 'overwrite'.length),
      lint(code.indexOf('backup'), 'backup'.length),
    ]);
  }

  Future<void> test_twoBooleansOnly() async {
    const code = r'''
void save(bool overwrite, bool backup) {}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('overwrite'), 'overwrite'.length),
      lint(code.indexOf('backup'), 'backup'.length),
    ]);
  }

  Future<void> test_method() async {
    await assertLintOn(r'''
class Store {
  void save(String name, bool overwrite) {}
}
''', 'overwrite');
  }

  Future<void> test_staticMethod() async {
    await assertLintOn(r'''
class Store {
  static void save(String name, bool overwrite) {}
}
''', 'overwrite');
  }

  Future<void> test_localFunction() async {
    await assertLintOn(r'''
void main() {
  void save(String name, bool overwrite) {}
  save('a', true);
}
''', 'overwrite');
  }

  Future<void> test_constructor() async {
    await assertLintOn(
      r'''
class Store {
  Store(String name, bool overwrite);
}
''',
      'overwrite',
      after: 'Store(',
    );
  }

  Future<void> test_fieldFormal() async {
    await assertLintOn(
      r'''
class Store {
  Store(this.name, this.overwrite);

  final String name;
  final bool overwrite;
}
''',
      'overwrite',
      after: 'Store(',
    );
  }

  Future<void> test_superFormal() async {
    await assertLintOn(
      r'''
class Base {
  Base(this.name, {required this.overwrite});

  final String name;
  final bool overwrite;
}

class Store extends Base {
  Store(super.name, bool overwrite) : super(overwrite: overwrite);
}
''',
      'overwrite',
      after: 'Store(',
    );
  }

  Future<void> test_superFormalOfTypeBool_onlySuperclassReported() async {
    const code = r'''
class Base {
  Base(this.name, this.overwrite);

  final String name;
  final bool overwrite;
}

class Store extends Base {
  Store(super.name, super.overwrite);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('overwrite'), 'overwrite'.length),
    ]);
  }

  Future<void> test_override_onlyDeclarationReported() async {
    const code = r'''
abstract class Store {
  void save(String name, bool overwrite);
}

class MemoryStore implements Store {
  @override
  void save(String name, bool overwrite) {}
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('overwrite'), 'overwrite'.length),
    ]);
  }

  // Not reported.

  Future<void> test_named() async {
    await assertNoDiagnostics(r'''
void save(String name, {bool overwrite = false}) {}
''');
  }

  Future<void> test_requiredNamed() async {
    await assertNoDiagnostics(r'''
void save(String name, {required bool overwrite}) {}
''');
  }

  Future<void> test_singleParameter() async {
    await assertNoDiagnostics(r'''
void setEnabled(bool enabled) {}
''');
  }

  Future<void> test_singleOptionalParameter() async {
    await assertNoDiagnostics(r'''
void refresh([bool force = false]) {}
''');
  }

  Future<void> test_operator() async {
    await assertNoDiagnostics(r'''
class Flags {
  bool operator [](int index) => false;
  void operator []=(int index, bool value) {}
}
''');
  }

  Future<void> test_setter() async {
    await assertNoDiagnostics(r'''
class Store {
  set overwrite(bool value) {}
}
''');
  }

  Future<void> test_closure() async {
    await assertNoDiagnostics(r'''
void listen(void Function(String name, bool selected) onChanged) {}

void main() {
  listen((name, selected) {});
  listen((String name, bool selected) {});
}
''');
  }

  Future<void> test_functionTypedParameter() async {
    await assertNoDiagnostics(r'''
void listen(String name, void onChanged(String name, bool selected)) {}
''');
  }

  Future<void> test_nonBooleanPositional() async {
    await assertNoDiagnostics(r'''
void save(String name, int retries) {}
''');
  }
}
