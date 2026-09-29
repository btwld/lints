// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:btwld_rules/src/rules/avoid_deeply_nested_conditionals.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDeeplyNestedConditionalsTest);
  });
}

@reflectiveTest
class AvoidDeeplyNestedConditionalsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDeeplyNestedConditionals();
    super.setUp();
  }

  /// The offset and length of the conditional in [code] that starts with
  /// the first occurrence of [start] and ends with [end].
  (int, int) span(String code, String start, String end) {
    final offset = code.indexOf(start);

    return (offset, code.indexOf(end, offset) + end.length - offset);
  }

  // Reported.

  Future<void> test_fourLevels_inElse() async {
    const code = r'''
String f(int n) => n == 0
    ? 'a'
    : n == 1
    ? 'b'
    : n == 2
    ? 'c'
    : n == 3
    ? 'd'
    : 'e';
''';
    final (offset, length) = span(code, 'n == 3', "'e'");
    await assertDiagnostics(code, [lint(offset, length)]);
  }

  Future<void> test_fiveLevels_reportedTwice() async {
    const code = r'''
String f(int n) => n == 0
    ? 'a'
    : n == 1
    ? 'b'
    : n == 2
    ? 'c'
    : n == 3
    ? 'd'
    : n == 4
    ? 'e'
    : 'f';
''';
    final (offset3, length3) = span(code, 'n == 3', "'f'");
    final (offset4, length4) = span(code, 'n == 4', "'f'");
    await assertDiagnostics(code, [
      lint(offset3, length3),
      lint(offset4, length4),
    ]);
  }

  Future<void> test_fourLevels_inThen() async {
    const code = r'''
int f(bool a, bool b, bool c, bool d) =>
    a ? (b ? (c ? (d ? 1 : 2) : 3) : 4) : 5;
''';
    final (offset, length) = span(code, 'd ?', '2');
    await assertDiagnostics(code, [lint(offset, length)]);
  }

  Future<void> test_fourLevels_inCondition() async {
    const code = r'''
int f(bool a, bool b, bool c) =>
    (a ? (b ? (c ? true : false) : false) : false) ? 1 : 2;
''';
    final (offset, length) = span(code, 'c ?', 'true : false');
    await assertDiagnostics(code, [lint(offset, length)]);
  }

  // Not reported.

  Future<void> test_threeLevels() async {
    await assertNoDiagnostics(r'''
String f(int n) => n == 0
    ? 'a'
    : n == 1
    ? 'b'
    : n == 2
    ? 'c'
    : 'd';
''');
  }

  Future<void> test_closureStartsNewCount() async {
    await assertNoDiagnostics(r'''
int Function() f(bool a, bool b, bool c, bool d, bool e) => a
    ? () => b
          ? c
                ? d
                      ? 1
                      : 2
                : 3
          : 4
    : () => e
          ? 5
          : 6;
''');
  }

  Future<void> test_separateConditionals() async {
    await assertNoDiagnostics(r'''
int f(bool a, bool b) {
  final x = a ? 1 : 2;
  final y = b ? x : 3;

  return x == y ? (a ? 4 : 5) : 6;
}
''');
  }
}
