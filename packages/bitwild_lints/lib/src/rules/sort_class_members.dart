import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../config.dart';

/// Enforces a configurable order of class members.
///
/// Orders are lists of entries such as `public-fields`,
/// `overridden-public-methods`, or `build-method`, read from the
/// `bitwild_lints: sort_class_members:` section of `analysis_options.yaml`
/// (`order` for regular classes, `widgets-order` for subclasses of Flutter's
/// `Widget` or `State`). Without configuration, [defaultOrder] and
/// [defaultWidgetsOrder] apply.
///
/// An entry without a modifier matches every value of it: `fields` includes
/// static and private fields. A member takes the most specific entry it
/// matches; named entries such as `build-method` are the most specific, and
/// ties go to the earlier entry. Members that match no entry can go anywhere,
/// and unrecognized entries are ignored. Only `class` declarations are
/// checked.
///
/// No quick fix is offered: moving a member safely means carrying its
/// comments, annotations, and surrounding blank lines along with it.
class SortClassMembers extends AnalysisRule {
  static const LintCode code = LintCode(
    'sort_class_members',
    '{0} should come before {1}.',
    correctionMessage: 'Try moving this member.',
  );

  /// The order for regular classes when none is configured.
  static const defaultOrder = [
    'public-fields',
    'private-fields',
    'constructors',
    'static-methods',
    'private-methods',
    'private-getters',
    'private-setters',
    'public-getters',
    'public-setters',
    'public-methods',
    'overridden-public-methods',
    'overridden-public-getters',
    'build-method',
  ];

  /// The order for widget classes when none is configured.
  static const defaultWidgetsOrder = [
    'constructors',
    'const-fields',
    'static-methods',
    'final-fields',
    'var-fields',
    'init-state-method',
    'private-methods',
    'overridden-public-methods',
    'build-method',
  ];

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
    final options = RuleOptions.forRule(context.definingUnit.file, name);
    final visitor = _Visitor(
      this,
      order: _parseOrder(options?['order']) ?? _parseOrder(defaultOrder)!,
      widgetsOrder:
          _parseOrder(options?['widgets-order']) ??
          _parseOrder(defaultWidgetsOrder)!,
    );
    registry.addClassDeclaration(this, visitor);
  }
}

/// The valid entries of a configured order, or `null` when it has none.
List<_Entry>? _parseOrder(Object? entries) {
  if (entries is! List) return null;
  final order = entries.whereType<String>().map(_Entry.parse).nonNulls.toList();

  return order.isEmpty ? null : order;
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, {required this.order, required this.widgetsOrder});

  final AnalysisRule rule;
  final List<_Entry> order;
  final List<_Entry> widgetsOrder;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final order = _isWidgetClass(node) ? widgetsOrder : this.order;
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

String _upperFirst(String label) => label[0].toUpperCase() + label.substring(1);

enum _Group {
  field('field', 'fields'),
  constructor('constructor', 'constructors'),
  method('method', 'methods'),
  getter('getter', 'getters'),
  setter('setter', 'setters');

  const _Group(this.singular, this.plural);

  final String singular;
  final String plural;
}

enum _Mutability { constant, immutable, mutable }

/// The properties of one class member that decide its position.
class _MemberKind {
  _MemberKind(
    this.group, {
    required this.name,
    this.isStatic = false,
    this.isOverridden = false,
    this.isLate = false,
    this.isFactory = false,
    this.mutability,
  });

  final _Group group;

  /// The member's name; empty for an unnamed constructor.
  final String name;
  final bool isStatic;
  final bool isOverridden;
  final bool isLate;
  final bool isFactory;
  final _Mutability? mutability;

  bool get isPrivate => name.startsWith('_');

  bool get isNamed => name.isNotEmpty;

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

  static _MemberKind? of(ClassMember member) {
    switch (member) {
      case FieldDeclaration(:final fields, :final isStatic, :final metadata):
        return _MemberKind(
          _Group.field,
          name: fields.variables.first.name.lexeme,
          isStatic: isStatic,
          isOverridden: _hasOverride(metadata),
          isLate: fields.isLate,
          mutability: fields.isConst
              ? _Mutability.constant
              : fields.isFinal
              ? _Mutability.immutable
              : _Mutability.mutable,
        );
      case ConstructorDeclaration(:final name, :final factoryKeyword):
        return _MemberKind(
          _Group.constructor,
          name: name?.lexeme ?? '',
          isFactory: factoryKeyword != null,
        );
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

  static bool _hasOverride(NodeList<Annotation> metadata) => metadata.any(
    (annotation) =>
        annotation.name.name == 'override' && annotation.arguments == null,
  );
}

/// One position in a member order. Unset modifiers match any member.
class _Entry {
  _Entry(
    this.label,
    this.groups, {
    this.isPrivate,
    this.isStatic,
    this.isOverridden,
    this.isLate,
    this.isNamed,
    this.isFactory,
    this.mutability,
    this.memberName,
  });

  final String label;
  final Set<_Group> groups;
  final bool? isPrivate;
  final bool? isStatic;
  final bool? isOverridden;
  final bool? isLate;
  final bool? isNamed;
  final bool? isFactory;
  final _Mutability? mutability;
  final String? memberName;

  /// Named entries outrank any combination of modifiers.
  int get specificity => memberName != null
      ? 100
      : [
          isPrivate,
          isStatic,
          isOverridden,
          isLate,
          isNamed,
          isFactory,
          mutability,
        ].nonNulls.length;

  bool matches(_MemberKind member) =>
      groups.contains(member.group) &&
      (isPrivate == null || isPrivate == member.isPrivate) &&
      (isStatic == null || isStatic == member.isStatic) &&
      (isOverridden == null || isOverridden == member.isOverridden) &&
      (isLate == null || isLate == member.isLate) &&
      (isNamed == null || isNamed == member.isNamed) &&
      (isFactory == null || isFactory == member.isFactory) &&
      (mutability == null || mutability == member.mutability) &&
      (memberName == null || memberName == member.name);

  /// Parses an entry such as `public-fields`, `overridden-public-methods`,
  /// `getters-setters`, `build-method`, or `from-json-constructor`.
  ///
  /// Returns `null` for text that isn't a valid entry.
  static _Entry? parse(String text) {
    final words = text.trim().split('-');
    if (words.any((word) => word.isEmpty)) return null;

    // A named entry: the member's name in kebab case, then a singular group.
    for (final group in _Group.values) {
      if (words.length > 1 && words.last == group.singular) {
        final name = _camelCase(words.sublist(0, words.length - 1));

        return _Entry('The $name ${group.singular}', {group}, memberName: name);
      }
    }

    final Set<_Group> groups;
    final List<String> modifiers;
    if (words.length >= 2 &&
        words[words.length - 2] == 'getters' &&
        words.last == 'setters') {
      groups = {_Group.getter, _Group.setter};
      modifiers = words.sublist(0, words.length - 2);
    } else {
      final group = _Group.values.where((g) => g.plural == words.last);
      if (group.isEmpty) return null;
      groups = {group.single};
      modifiers = words.sublist(0, words.length - 1);
    }

    bool? isPrivate, isStatic, isOverridden, isLate, isNamed, isFactory;
    _Mutability? mutability;
    for (final modifier in modifiers) {
      switch (modifier) {
        case 'public':
          isPrivate = false;
        case 'private':
          isPrivate = true;
        case 'static':
          isStatic = true;
        case 'overridden':
          isOverridden = true;
        case 'late':
          isLate = true;
        case 'named':
          isNamed = true;
        case 'factory':
          isFactory = true;
        case 'const':
          mutability = _Mutability.constant;
        case 'final':
          mutability = _Mutability.immutable;
        case 'var':
          mutability = _Mutability.mutable;
        default:
          return null;
      }
    }

    final groupLabel = groups.length == 2
        ? 'getters and setters'
        : groups.single.plural;
    final label = [
      for (final modifier in modifiers)
        modifier == 'var' ? 'mutable' : modifier,
      groupLabel,
    ].join(' ');

    return _Entry(
      _upperFirst(label),
      groups,
      isPrivate: isPrivate,
      isStatic: isStatic,
      isOverridden: isOverridden,
      isLate: isLate,
      isNamed: isNamed,
      isFactory: isFactory,
      mutability: mutability,
    );
  }

  static String _camelCase(List<String> words) =>
      [words.first, for (final word in words.skip(1)) _upperFirst(word)].join();
}
