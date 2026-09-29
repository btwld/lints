import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Enforces btwld's order of class members.
///
/// Regular classes:
///
/// 1. public fields
/// 2. private fields
/// 3. constructors
/// 4. static methods
/// 5. private methods
/// 6. private getters
/// 7. private setters
/// 8. public getters
/// 9. public setters
/// 10. public methods
/// 11. overridden public methods
/// 12. overridden public getters
/// 13. the `build` method
///
/// Widget classes (subclasses of Flutter's `Widget` or `State`):
///
/// 1. constructors
/// 2. `const` fields
/// 3. static methods
/// 4. `final` fields
/// 5. mutable fields
/// 6. the `initState` method
/// 7. private methods
/// 8. overridden public methods
/// 9. the `build` method
///
/// An entry without a modifier matches every value of it: public fields
/// include static ones. A member takes the most specific entry it matches;
/// named methods such as `build` are the most specific, and ties go to the
/// earlier entry. Members that match no entry, such as getters in a widget
/// class, can go anywhere. Only `class` declarations are checked.
///
/// No quick fix is offered: moving a member safely means carrying its
/// comments, annotations, and surrounding blank lines along with it.
class SortClassMembers extends AnalysisRule {
  static const LintCode code = LintCode(
    'sort_class_members',
    '{0} should come before {1}.',
    correctionMessage: 'Try moving this member.',
  );

  SortClassMembers()
    : super(
        name: 'sort_class_members',
        description: 'Order class members consistently.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final order = _isWidgetClass(node) ? _widgetOrder : _regularOrder;
    var highest = -1;
    for (final member in node.body.members) {
      final kind = _MemberKind.of(member);
      if (kind == null) continue;
      final index = kind.indexIn(order);
      if (index == null) continue;
      if (index >= highest) {
        highest = index;
        continue;
      }

      final arguments = [order[index].label, _lowerFirst(order[highest].label)];
      switch (member) {
        case FieldDeclaration(:final fields):
          rule.reportAtToken(fields.variables.first.name, arguments: arguments);
        case ConstructorDeclaration(:final errorRange):
          rule.reportAtSourceRange(errorRange, arguments: arguments);
        case MethodDeclaration(:final name):
          rule.reportAtToken(name, arguments: arguments);
        default:
      }
    }
  }
}

bool _isWidgetClass(ClassDeclaration node) {
  final element = node.declaredFragment?.element;
  if (element == null) return false;

  return element.allSupertypes.any((type) {
    final supertype = type.element;
    final uri = supertype.library.uri;

    return (supertype.name == 'Widget' || supertype.name == 'State') &&
        uri.scheme == 'package' &&
        uri.pathSegments.first == 'flutter';
  });
}

String _lowerFirst(String label) => label[0].toLowerCase() + label.substring(1);

enum _Group { field, constructor, method, getter, setter }

enum _Mutability { constant, immutable, mutable }

/// The properties of one class member that decide its position.
class _MemberKind {
  _MemberKind(
    this.group, {
    required this.name,
    this.isStatic = false,
    this.isOverridden = false,
    this.mutability,
  });

  final _Group group;
  final String name;
  final bool isStatic;
  final bool isOverridden;
  final _Mutability? mutability;

  bool get isPrivate => name.startsWith('_');

  static _MemberKind? of(ClassMember member) {
    switch (member) {
      case FieldDeclaration(:final fields, :final isStatic, :final metadata):
        return _MemberKind(
          _Group.field,
          name: fields.variables.first.name.lexeme,
          isStatic: isStatic,
          isOverridden: _hasOverride(metadata),
          mutability: fields.isConst
              ? _Mutability.constant
              : fields.isFinal
              ? _Mutability.immutable
              : _Mutability.mutable,
        );
      case ConstructorDeclaration(:final name):
        return _MemberKind(_Group.constructor, name: name?.lexeme ?? '');
      case MethodDeclaration(:final name, :final isStatic, :final metadata):
        return _MemberKind(
          member.isGetter
              ? _Group.getter
              : member.isSetter
              ? _Group.setter
              : _Group.method,
          name: name.lexeme,
          isStatic: isStatic,
          isOverridden: _hasOverride(metadata),
        );
      default:
        return null;
    }
  }

  /// The index of the most specific entry in [order] that matches this
  /// member, or `null` when none does.
  int? indexIn(List<_Entry> order) {
    int? best;
    for (var i = 0; i < order.length; i++) {
      if (!order[i].matches(this)) continue;
      if (best == null || order[i].specificity > order[best].specificity) {
        best = i;
      }
    }

    return best;
  }

  static bool _hasOverride(NodeList<Annotation> metadata) => metadata.any(
    (annotation) =>
        annotation.name.name == 'override' && annotation.arguments == null,
  );
}

/// One position in a member order. Unset modifiers match any member.
class _Entry {
  const _Entry(
    this.label,
    this.group, {
    this.isPrivate,
    this.isStatic,
    this.isOverridden,
    this.mutability,
    this.methodName,
  });

  final String label;
  final _Group group;
  final bool? isPrivate;
  final bool? isStatic;
  final bool? isOverridden;
  final _Mutability? mutability;
  final String? methodName;

  /// Named methods outrank any combination of modifiers.
  int get specificity => methodName != null
      ? 100
      : [isPrivate, isStatic, isOverridden, mutability].nonNulls.length;

  bool matches(_MemberKind member) =>
      member.group == group &&
      (isPrivate == null || isPrivate == member.isPrivate) &&
      (isStatic == null || isStatic == member.isStatic) &&
      (isOverridden == null || isOverridden == member.isOverridden) &&
      (mutability == null || mutability == member.mutability) &&
      (methodName == null || methodName == member.name);
}

const _regularOrder = [
  _Entry('Public fields', _Group.field, isPrivate: false),
  _Entry('Private fields', _Group.field, isPrivate: true),
  _Entry('Constructors', _Group.constructor),
  _Entry('Static methods', _Group.method, isStatic: true),
  _Entry('Private methods', _Group.method, isPrivate: true),
  _Entry('Private getters', _Group.getter, isPrivate: true),
  _Entry('Private setters', _Group.setter, isPrivate: true),
  _Entry('Public getters', _Group.getter, isPrivate: false),
  _Entry('Public setters', _Group.setter, isPrivate: false),
  _Entry('Public methods', _Group.method, isPrivate: false),
  _Entry(
    'Overridden public methods',
    _Group.method,
    isPrivate: false,
    isOverridden: true,
  ),
  _Entry(
    'Overridden public getters',
    _Group.getter,
    isPrivate: false,
    isOverridden: true,
  ),
  _Entry('The build method', _Group.method, methodName: 'build'),
];

const _widgetOrder = [
  _Entry('Constructors', _Group.constructor),
  _Entry('Const fields', _Group.field, mutability: _Mutability.constant),
  _Entry('Static methods', _Group.method, isStatic: true),
  _Entry('Final fields', _Group.field, mutability: _Mutability.immutable),
  _Entry('Mutable fields', _Group.field, mutability: _Mutability.mutable),
  _Entry('The initState method', _Group.method, methodName: 'initState'),
  _Entry('Private methods', _Group.method, isPrivate: true),
  _Entry(
    'Overridden public methods',
    _Group.method,
    isPrivate: false,
    isOverridden: true,
  ),
  _Entry('The build method', _Group.method, methodName: 'build'),
];
