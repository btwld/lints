// Reflective test methods must be named test_*.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:bitwild_lints/src/rules/avoid_barrel_imports_in_src.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidBarrelImportsInSrcTest);
  });
}

@reflectiveTest
class AvoidBarrelImportsInSrcTest extends AnalysisRuleTest {
  String get srcFile => '$testPackageLibPath/src/user.dart';

  @override
  void setUp() {
    rule = AvoidBarrelImportsInSrc();
    newPackage('other')
      ..addFile('lib/other.dart', "export 'src/thing.dart';")
      ..addFile('lib/src/thing.dart', 'class Thing {}');
    super.setUp();
  }

  void writeLibrary() {
    newFile('$testPackageLibPath/src/value.dart', 'class Value {}');
    newFile('$testPackageLibPath/test.dart', "export 'src/value.dart';");
    newFile('$testPackageLibPath/plain.dart', 'class Plain {}');
  }

  // Reported.

  Future<void> test_packageImportOfBarrel() async {
    writeLibrary();
    const code = r'''
import 'package:test/test.dart';

Value v = Value();
''';
    newFile(srcFile, code);
    await assertDiagnosticsInFile(srcFile, [
      lint(code.indexOf("'package"), "'package:test/test.dart'".length),
    ]);
  }

  Future<void> test_relativeImportOfBarrel() async {
    writeLibrary();
    const code = r'''
import '../test.dart';

Value v = Value();
''';
    newFile(srcFile, code);
    await assertDiagnosticsInFile(srcFile, [
      lint(code.indexOf("'../"), "'../test.dart'".length),
    ]);
  }

  Future<void> test_nestedSrcFile() async {
    writeLibrary();
    final path = '$testPackageLibPath/src/deep/user.dart';
    const code = r'''
import 'package:test/test.dart';

Value v = Value();
''';
    newFile(path, code);
    await assertDiagnosticsInFile(path, [
      lint(code.indexOf("'package"), "'package:test/test.dart'".length),
    ]);
  }

  // Not reported.

  Future<void> test_srcImport() async {
    writeLibrary();
    newFile(srcFile, r'''
import 'package:test/src/value.dart';

Value v = Value();
''');
    await assertNoDiagnosticsInFile(srcFile);
  }

  Future<void> test_publicFileWithoutExports() async {
    writeLibrary();
    newFile(srcFile, r'''
import 'package:test/plain.dart';

Plain p = Plain();
''');
    await assertNoDiagnosticsInFile(srcFile);
  }

  Future<void> test_otherPackageBarrel() async {
    newFile(srcFile, r'''
import 'package:other/other.dart';

Thing t = Thing();
''');
    await assertNoDiagnosticsInFile(srcFile);
  }

  Future<void> test_publicLibraryImportingBarrel() async {
    writeLibrary();
    final path = '$testPackageLibPath/api.dart';
    newFile(path, r'''
import 'package:test/test.dart';

Value v = Value();
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_testDirectoryImportingBarrel() async {
    writeLibrary();
    final path = '$testPackageTestPath/value_test.dart';
    newFile(path, r'''
import 'package:test/test.dart';

Value v = Value();
''');
    await assertNoDiagnosticsInFile(path);
  }
}
