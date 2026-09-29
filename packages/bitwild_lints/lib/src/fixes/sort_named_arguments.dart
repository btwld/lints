import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/sort_named_arguments.dart';

/// Reorders named arguments, leaving positional arguments where they are.
class SortNamedArgumentsFix extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'bitwild.fix.sortNamedArguments',
    DartFixKindPriority.standard,
    'Sort named arguments',
  );

  SortNamedArgumentsFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final argumentList = node.thisOrAncestorOfType<ArgumentList>();
    if (argumentList == null) return;
    final expected = sortedNamedArguments(argumentList);
    if (expected == null) return;

    // Each named-argument slot receives the argument that belongs there.
    final actual = argumentList.arguments.whereType<NamedArgument>().toList();
    await builder.addDartFileEdit(file, (builder) {
      for (var i = 0; i < actual.length; i++) {
        if (identical(actual[i], expected[i])) continue;
        builder.addSimpleReplacement(
          range.node(actual[i]),
          utils.getNodeText(expected[i]),
        );
      }
    });
  }
}
