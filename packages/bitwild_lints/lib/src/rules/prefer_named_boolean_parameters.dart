import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Flags positional `bool` parameters in function, method, and constructor
/// declarations.
///
/// A call such as `save(user, true)` does not say what `true` means; a named
/// parameter makes it `save(user, overwrite: true)`. Declarations with a
/// single parameter, overrides, operators, and setters are exempt, as are
/// closures, whose signatures are dictated by the expected callback type.
class PreferNamedBooleanParameters extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_named_boolean_parameters',
    "Make the boolean parameter '{0}' a named parameter.",
    correctionMessage:
        'Try converting it to a named parameter so call sites read '
        "'name: true'.",
  );

  PreferNamedBooleanParameters()
    : super(
        name: 'prefer_named_boolean_parameters',
        description: 'Prefer named parameters for boolean flags.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addConstructorDeclaration(this, visitor)
      ..addFunctionDeclaration(this, visitor)
      ..addMethodDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _check(node.parameters);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.isGetter || node.isSetter) return;
    _check(node.functionExpression.parameters);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter || node.isSetter || node.isOperator) return;
    if (node.declaredFragment?.element.metadata.hasOverride ?? false) return;
    _check(node.parameters);
  }

  void _check(FormalParameterList? parameters) {
    if (parameters == null || parameters.parameters.length < 2) return;
    for (final parameter in parameters.parameters) {
      final name = parameter.name;
      final element = parameter.declaredFragment?.element;
      if (name == null || element == null || !parameter.isPositional) continue;
      // A `super.` parameter's position is set by the superclass constructor,
      // which is reported itself when it belongs to this code base.
      if (element is SuperFormalParameterElement) continue;
      if (!element.type.isDartCoreBool) continue;

      rule.reportAtToken(name, arguments: [name.lexeme]);
    }
  }
}
