import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

/// Creates a quick fix for one diagnostic.
typedef FixFactory =
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    });

/// Applies a rule's quick fix in [AnalysisRuleTest]s.
mixin FixTestSupport on AnalysisRuleTest {
  /// Returns [code] after applying [fix] at the rule's [nth] diagnostic.
  ///
  /// Call after an assertion such as `assertDiagnostics`, which resolves
  /// [code] into `result`.
  Future<String> applyFix(String code, FixFactory fix, {int nth = 1}) async {
    final diagnostic = result.diagnostics
        .where((d) => d.diagnosticCode.lowerCaseName == rule.name)
        .elementAt(nth - 1);
    final library =
        await result.session.getResolvedLibrary(result.path)
            as ResolvedLibraryResult;
    final context = CorrectionProducerContext.createResolved(
      libraryResult: library,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
      selectionLength: diagnostic.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await fix(context: context).compute(builder);

    return builder.sourceChange.edits.fold<String>(
      code,
      (source, fileEdit) => SourceEdit.applySequence(source, fileEdit.edits),
    );
  }
}
