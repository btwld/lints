import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/blank_line_before_return.dart';

/// Inserts an empty line above a `return` and its leading comments.
class AddBlankLineBeforeReturn extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'bitwild.fix.addBlankLineBeforeReturn',
    DartFixKindPriority.standard,
    "Add a blank line before 'return'",
  );

  AddBlankLineBeforeReturn({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final statement = node.thisOrAncestorOfType<ReturnStatement>();
    if (statement == null) return;
    final lines = returnLines(statement);
    if (lines == null) return;
    final (lineInfo, startLine, previousLine) = lines;
    // A return on the same line as the previous statement needs reformatting,
    // not just an extra line.
    if (startLine == previousLine) return;

    final lineStart = lineInfo.getOffsetOfLine(startLine - 1);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(lineStart, '\n');
    });
  }
}
