import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Flags conditional expressions (`?:`) nested more than three levels deep.
///
/// The level of a conditional is one plus the number of conditionals that
/// enclose it, counted up to the nearest function body, so a closure starts
/// a new count. Every conditional deeper than [_maxLevel] is reported.
class AvoidDeeplyNestedConditionals extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_deeply_nested_conditionals',
    'Conditional expressions are nested more than 3 levels deep.',
    correctionMessage:
        'Try extracting the logic into a function with if statements or a '
        'switch expression.',
  );

  AvoidDeeplyNestedConditionals()
    : super(
        name: 'avoid_deeply_nested_conditionals',
        description:
            'Avoid conditional expressions nested more than 3 levels deep.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addConditionalExpression(this, _Visitor(this));
  }
}

const _maxLevel = 3;

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    var level = 1;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent is FunctionBody) break;
      if (parent is ConditionalExpression) level++;
    }
    if (level > _maxLevel) rule.reportAtNode(node);
  }
}
