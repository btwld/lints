import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Requires named arguments in a consistent order.
///
/// `key` comes first and `spec` second. Other named arguments follow the
/// order in which the invoked function declares its parameters. `child` and
/// then `children` come last. Positional arguments are not checked.
class SortNamedArguments extends AnalysisRule {
  static const LintCode code = LintCode(
    'sort_named_arguments',
    "Named arguments aren't in the expected order.",
    correctionMessage:
        "Try putting 'key' and 'spec' first, then the other named arguments "
        "in parameter declaration order, then 'child' and 'children'.",
  );

  SortNamedArguments()
    : super(
        name: 'sort_named_arguments',
        description: 'Order named arguments consistently.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addArgumentList(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitArgumentList(ArgumentList node) {
    final expected = sortedNamedArguments(node);
    if (expected == null) return;

    final actual = node.arguments.whereType<NamedArgument>().toList();
    for (var i = 0; i < actual.length; i++) {
      if (!identical(actual[i], expected[i])) {
        rule.reportAtToken(actual[i].name);

        return;
      }
    }
  }
}

/// The named arguments of [node] in the expected order.
///
/// Returns `null` when there are fewer than two named arguments or when the
/// order can't be determined because an argument doesn't resolve to a
/// parameter of the invoked function.
List<NamedArgument>? sortedNamedArguments(ArgumentList node) {
  final named = node.arguments.whereType<NamedArgument>().toList();
  if (named.length < 2) return null;
  if (named.any((argument) => argument.correspondingParameter == null)) {
    return null;
  }

  final parameters = _declaredParameters(named.first);
  if (parameters == null) return null;
  final declared = [
    for (final parameter in parameters)
      if (parameter.isNamed) parameter.name,
  ];

  final ranks = <NamedArgument, int>{};
  for (final argument in named) {
    final name = argument.name.lexeme;
    final index = declared.indexOf(name);
    if (index < 0) return null;
    ranks[argument] = switch (name) {
      'key' => -2,
      'spec' => -1,
      'child' => declared.length,
      'children' => declared.length + 1,
      _ => index,
    };
  }

  // Ranks are unique because argument names are, so the sort is stable.
  return named..sort((a, b) => ranks[a]!.compareTo(ranks[b]!));
}

/// The parameters of the function, method, or constructor that declares
/// [argument]'s parameter, in declaration order.
///
/// Function types list named parameters alphabetically, so the order must
/// come from the declaration. Calls through function-typed values have no
/// declaration and return `null`.
List<FormalParameterElement>? _declaredParameters(NamedArgument argument) {
  final enclosing =
      argument.correspondingParameter?.baseElement.enclosingElement;

  return enclosing is ExecutableElement ? enclosing.formalParameters : null;
}
