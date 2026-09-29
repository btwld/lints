import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';

/// Requires a blank line before a `return` that follows other statements.
///
/// A `return` that is the first statement of its block needs no blank line.
/// Comments directly above the `return` belong to it, so the blank line goes
/// above those comments.
class BlankLineBeforeReturn extends AnalysisRule {
  static const LintCode code = LintCode(
    'blank_line_before_return',
    "Missing a blank line before 'return'.",
    correctionMessage: "Try adding a blank line before 'return'.",
  );

  BlankLineBeforeReturn()
    : super(
        name: 'blank_line_before_return',
        description:
            'Separate a return statement from the statements before it.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addReturnStatement(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final lines = returnLines(node);
    if (lines == null) return;
    final (_, startLine, previousLine) = lines;
    if (startLine - previousLine < 2) rule.reportAtToken(node.returnKeyword);
  }
}

/// The lines around a `return` that follows another statement in a block.
///
/// Returns `(lineInfo, startLine, previousLine)`, where `startLine` is the
/// 1-based line of the first token that belongs to the `return` (its own
/// leading comment, if any) and `previousLine` is the line where the
/// preceding statement ends. Returns `null` when the `return` is not preceded
/// by a statement in the same block.
(LineInfo, int, int)? returnLines(ReturnStatement node) {
  final block = node.parent;
  if (block is! Block) return null;
  final index = block.statements.indexOf(node);
  if (index < 1) return null;

  final lineInfo = (node.root as CompilationUnit).lineInfo;
  final previousLine = lineInfo
      .getLocation(block.statements[index - 1].end)
      .lineNumber;
  final start = _firstOwnToken(node.returnKeyword, previousLine, lineInfo);
  final startLine = lineInfo.getLocation(start.offset).lineNumber;

  return (lineInfo, startLine, previousLine);
}

/// The first comment above [keyword] that is on its own line, or [keyword].
///
/// A comment on [previousLine] trails the previous statement instead.
Token _firstOwnToken(Token keyword, int previousLine, LineInfo lineInfo) {
  for (
    Token? comment = keyword.precedingComments;
    comment != null;
    comment = comment.next
  ) {
    if (lineInfo.getLocation(comment.offset).lineNumber > previousLine) {
      return comment;
    }
  }

  return keyword;
}
