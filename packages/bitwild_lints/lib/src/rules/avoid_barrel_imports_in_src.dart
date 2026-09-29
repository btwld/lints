import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Flags `lib/src` code that imports its own package's public re-export files.
///
/// A public library that exports other libraries is the package's API.
/// Implementation code that depends on it can create import cycles and pulls
/// in more than it uses; it should import the declaring file under `lib/src/`.
class AvoidBarrelImportsInSrc extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_barrel_imports_in_src',
    "Don't import the package's public API from 'lib/src'.",
    correctionMessage:
        "Try importing the file under 'lib/src/' that declares what you use.",
  );

  AvoidBarrelImportsInSrc()
    : super(
        name: 'avoid_barrel_imports_in_src',
        description:
            "Avoid importing the package's own re-export files from "
            "'lib/src'.",
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitImportDirective(ImportDirective node) {
    final source = (node.root as CompilationUnit).declaredFragment?.source.uri;
    final imported = node.libraryImport?.importedLibrary;
    if (source == null || imported == null) return;

    final package = _srcPackage(source);
    if (package == null) return;
    final target = imported.uri;
    if (target.scheme != 'package') return;
    final segments = target.pathSegments;
    if (segments.first != package || segments[1] == 'src') return;
    if (!imported.fragments.any((f) => f.libraryExports.isNotEmpty)) return;

    rule.reportAtNode(node.uri);
  }

  /// The package name when [uri] is a library under that package's
  /// `lib/src/`, otherwise `null`.
  static String? _srcPackage(Uri uri) {
    if (uri.scheme != 'package') return null;
    final segments = uri.pathSegments;
    if (segments.length < 3 || segments[1] != 'src') return null;

    return segments.first;
  }
}
