import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/unconditional_recursion.dart';

/// The entry point the Dart analysis server loads.
final plugin = BtwldRulesPlugin();

class BtwldRulesPlugin extends Plugin {
  @override
  String get name => 'btwld_rules';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(UnconditionalRecursion());
  }
}
