// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:bitwild_lints/src/fixes/add_blank_line_before_return.dart';
import 'package:bitwild_lints/src/rules/blank_line_before_return.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../src/fix_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BlankLineBeforeReturnTest);
  });
}

@reflectiveTest
class BlankLineBeforeReturnTest extends AnalysisRuleTest with FixTestSupport {
  @override
  void setUp() {
    rule = BlankLineBeforeReturn();
    super.setUp();
  }

  // Reported.

  Future<void> test_afterStatement() async {
    const code = r'''
int f(int a) {
  final b = a + 1;
  return b;
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('return'), 6)]);
    expect(await applyFix(code, AddBlankLineBeforeReturn.new), r'''
int f(int a) {
  final b = a + 1;

  return b;
}
''');
  }

  Future<void> test_commentAboveReturn_blankLineGoesAboveComment() async {
    const code = r'''
int f(int a) {
  final b = a + 1;
  // Explain the result.
  return b;
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('return'), 6)]);
    expect(await applyFix(code, AddBlankLineBeforeReturn.new), r'''
int f(int a) {
  final b = a + 1;

  // Explain the result.
  return b;
}
''');
  }

  Future<void> test_trailingCommentOnPreviousLine() async {
    const code = r'''
int f(int a) {
  final b = a + 1; // Trailing comment.
  return b;
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('return'), 6)]);
    expect(await applyFix(code, AddBlankLineBeforeReturn.new), r'''
int f(int a) {
  final b = a + 1; // Trailing comment.

  return b;
}
''');
  }

  Future<void> test_insideNestedBlock() async {
    const code = r'''
void f(bool a) {
  if (a) {
    print('');
    return;
  }
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('return'), 6)]);
  }

  Future<void> test_afterMultilineStatement() async {
    const code = r'''
int f(List<int> items) {
  final total = items.fold(
    0,
    (sum, item) => sum + item,
  );
  return total;
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('return total'), 6)]);
  }

  // Not reported.

  Future<void> test_firstStatementInBlock() async {
    await assertNoDiagnostics(r'''
int f(bool a) {
  if (a) {
    return 1;
  }

  return 0;
}
''');
  }

  Future<void> test_blankLineBeforeComment() async {
    await assertNoDiagnostics(r'''
int f(int a) {
  final b = a + 1;

  // Explain the result.
  return b;
}
''');
  }

  Future<void> test_expressionBody() async {
    await assertNoDiagnostics(r'''
int f(int a) => a + 1;
''');
  }

  Future<void> test_returnInClosureFirstStatement() async {
    await assertNoDiagnostics(r'''
void f(List<int> items) {
  items.map((item) {
    return item + 1;
  });
}
''');
  }

  Future<void> test_ifWithoutBraces() async {
    await assertNoDiagnostics(r'''
int f(bool a) {
  if (a) return 1;

  return 0;
}
''');
  }
}
