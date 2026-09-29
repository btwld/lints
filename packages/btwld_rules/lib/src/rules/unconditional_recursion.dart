import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Reports a function or method that calls itself before it can return.
///
/// A call counts only when every path through the body reaches it: it is not
/// inside a closure, a branch, a loop body, a `catch`, a short-circuiting
/// operand, a null-aware access, or a `late` initializer, and no earlier
/// statement can return, throw, break, or continue. Such a function never
/// finishes. Synchronous code overflows the stack; `async` code keeps
/// allocating suspended frames until the process runs out of memory.
class UnconditionalRecursion extends AnalysisRule {
  static const LintCode code = LintCode(
    'unconditional_recursion',
    "'{0}' calls itself unconditionally, so it can never return.",
    correctionMessage:
        'Call the intended target, or guard the recursive call with a '
        'condition that can stop it.',
    severity: DiagnosticSeverity.WARNING,
  );

  UnconditionalRecursion()
    : super(
        name: 'unconditional_recursion',
        description: 'Avoid functions and methods that always call themselves.',
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
      ..addFunctionDeclaration(this, visitor)
      ..addMethodDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.isGetter || node.isSetter) return;
    _check(node.functionExpression.body, node.declaredFragment?.element);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter || node.isSetter || node.isOperator) return;
    _check(node.body, node.declaredFragment?.element);
  }

  void _check(FunctionBody body, ExecutableElement? element) {
    // Generators run lazily, so a self-referencing generator can be a
    // deliberate infinite sequence.
    if (element == null || body.isGenerator) return;
    if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) return;

    final finder = _SelfCallFinder(element.baseElement);
    body.accept(finder);
    for (final call in finder.calls) {
      if (_isUnconditional(call, body)) {
        rule.reportAtNode(call.methodName, arguments: [element.displayName]);

        return;
      }
    }
  }
}

/// Collects calls that dispatch to [target] on the same receiver.
class _SelfCallFinder extends RecursiveAstVisitor<void> {
  _SelfCallFinder(this.target);

  final ExecutableElement target;
  final List<MethodInvocation> calls = [];

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A call inside a closure or local function runs only if that is invoked.
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.element?.baseElement == target &&
        _isSameReceiver(node)) {
      calls.add(node);
    }
    super.visitMethodInvocation(node);
  }

  static bool _isSameReceiver(MethodInvocation node) {
    if (node.isCascaded || node.isNullAware) return false;

    return switch (node.target) {
      null || ThisExpression() => true,
      // Static members, extension members, and import-prefixed functions.
      SimpleIdentifier(:final element) =>
        element is InterfaceElement ||
            element is ExtensionElement ||
            element is PrefixElement,
      _ => false,
    };
  }
}

/// Whether evaluating [body] always evaluates [call].
bool _isUnconditional(AstNode call, FunctionBody body) {
  AstNode child = call;
  for (var parent = call.parent; parent != null; parent = parent.parent) {
    if (identical(parent, body)) return true;
    if (!_alwaysEvaluates(parent, child)) return false;
    child = parent;
  }

  return false;
}

/// Whether evaluating [parent] always evaluates its direct [child].
bool _alwaysEvaluates(AstNode parent, AstNode child) => switch (parent) {
  ExpressionStatement() ||
  ReturnStatement() ||
  AwaitExpression() ||
  ParenthesizedExpression() ||
  NamedArgument() ||
  AsExpression() ||
  IsExpression() ||
  PrefixExpression() ||
  PostfixExpression() ||
  InterpolationExpression() ||
  StringInterpolation() ||
  ArgumentList() ||
  FunctionExpressionInvocation() ||
  InstanceCreationExpression() ||
  PropertyAccess() ||
  VariableDeclarationList() ||
  VariableDeclarationStatement() ||
  ListLiteral() ||
  SetOrMapLiteral() ||
  MapLiteralEntry() => true,
  MethodInvocation(:final target, :final isNullAware) =>
    identical(child, target) || !isNullAware,
  IndexExpression(:final target, :final isNullAware) =>
    identical(child, target) || !isNullAware,
  VariableDeclaration(:final initializer, :final isLate) =>
    identical(child, initializer) && !isLate,
  AssignmentExpression(:final rightHandSide, :final operator) =>
    !identical(child, rightHandSide) ||
        operator.type != TokenType.QUESTION_QUESTION_EQ,
  BinaryExpression(:final rightOperand, :final operator) =>
    !identical(child, rightOperand) || !_shortCircuits(operator.type),
  ConditionalExpression(:final condition) => identical(child, condition),
  IfStatement(:final expression) => identical(child, expression),
  SwitchStatement(:final expression) => identical(child, expression),
  SwitchExpression(:final expression) => identical(child, expression),
  WhileStatement(:final condition) => identical(child, condition),
  TryStatement(body: final tryBody) => identical(child, tryBody),
  SpreadElement(:final isNullAware) => !isNullAware,
  Block(:final statements) =>
    !statements
        .takeWhile((statement) => !identical(statement, child))
        .any(_mayExit),
  _ => false,
};

bool _shortCircuits(TokenType type) =>
    type == TokenType.AMPERSAND_AMPERSAND ||
    type == TokenType.BAR_BAR ||
    type == TokenType.QUESTION_QUESTION;

bool _mayExit(Statement statement) {
  final finder = _ExitFinder();
  statement.accept(finder);

  return finder.found;
}

/// Finds anything that can leave the enclosing body early.
class _ExitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Exits inside a closure leave the closure, not the enclosing body.
  }

  @override
  void visitReturnStatement(ReturnStatement node) => found = true;

  @override
  void visitBreakStatement(BreakStatement node) => found = true;

  @override
  void visitContinueStatement(ContinueStatement node) => found = true;

  @override
  void visitThrowExpression(ThrowExpression node) => found = true;

  @override
  void visitRethrowExpression(RethrowExpression node) => found = true;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // A call typed `Never`, such as `exit` or `fail`, does not return.
    if (node.staticType?.isBottom ?? false) {
      found = true;

      return;
    }
    super.visitMethodInvocation(node);
  }
}
