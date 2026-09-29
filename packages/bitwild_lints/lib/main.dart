import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes/add_blank_line_before_return.dart';
import 'src/fixes/sort_named_arguments.dart';
import 'src/rules/avoid_barrel_imports_in_src.dart';
import 'src/rules/avoid_deeply_nested_conditionals.dart';
import 'src/rules/blank_line_before_return.dart';
import 'src/rules/prefer_named_boolean_parameters.dart';
import 'src/rules/sort_class_members.dart';
import 'src/rules/sort_named_arguments.dart';
import 'src/rules/unconditional_recursion.dart';

/// The entry point the Dart analysis server loads.
final plugin = BitwildLintsPlugin();

class BitwildLintsPlugin extends Plugin {
  @override
  String get name => 'bitwild_lints';

  @override
  void register(PluginRegistry registry) {
    // Bugs: on by default.
    registry.registerWarningRule(UnconditionalRecursion());

    // Conventions: enabled through package:bitwild_analysis/plugin.yaml.
    registry
      ..registerLintRule(AvoidBarrelImportsInSrc())
      ..registerLintRule(AvoidDeeplyNestedConditionals())
      ..registerLintRule(BlankLineBeforeReturn())
      ..registerLintRule(PreferNamedBooleanParameters())
      ..registerLintRule(SortClassMembers())
      ..registerLintRule(SortNamedArguments());

    registry
      ..registerFixForRule(
        BlankLineBeforeReturn.code,
        AddBlankLineBeforeReturn.new,
      )
      ..registerFixForRule(SortNamedArguments.code, SortNamedArgumentsFix.new);
  }
}
