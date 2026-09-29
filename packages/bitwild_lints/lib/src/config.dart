import 'dart:convert';

import 'package:analyzer/file_system/file_system.dart';
import 'package:yaml/yaml.dart';

/// The key of this plugin's section in `analysis_options.yaml`.
const configSectionName = 'bitwild_lints';

/// Reads rule options from the `bitwild_lints:` section of the analysis
/// options file that applies to a Dart file.
///
/// The analyzer passes plugin rules no options of their own, so rules that
/// need configuration read this top-level section, which the analyzer
/// ignores. `include:` entries are followed, with relative paths and
/// `package:` URIs, so a workspace can configure every member from its root
/// options file.
///
/// ```yaml
/// bitwild_lints:
///   sort_class_members:
///     order:
///       - constructors
///       - fields
/// ```
abstract final class RuleOptions {
  // Keyed by file system and path: stamps are only comparable within one
  // file system.
  static final _cache = <(ResourceProvider, String), _CachedOptions>{};

  /// The options map for [ruleName], or `null` when it isn't configured.
  static Map<String, Object?>? forRule(File file, String ruleName) {
    final options = _optionsFileFor(file);
    if (options == null) return null;
    final section = _load(options)[configSectionName];
    if (section is! Map<String, Object?>) return null;
    final rule = section[ruleName];

    return rule is Map<String, Object?> ? rule : null;
  }

  static File? _optionsFileFor(File file) {
    for (Folder? folder = file.parent; folder != null;) {
      final options = folder.getFile('analysis_options.yaml');
      if (options.exists) return options;
      folder = folder.isRoot ? null : folder.parent;
    }

    return null;
  }

  static Map<String, Object?> _load(File file) {
    final key = (file.provider, file.path);
    final cached = _cache[key];
    if (cached != null && cached.isCurrent) return cached.options;

    final sources = <File>[];
    final options = _read(file, sources, {});
    _cache[key] = _CachedOptions(options, [
      for (final source in sources) (source, source.modificationStamp),
    ]);

    return options;
  }

  /// Parses [file] merged over the files it includes, recording every file
  /// read in [sources].
  static Map<String, Object?> _read(
    File file,
    List<File> sources,
    Set<String> visiting,
  ) {
    if (!visiting.add(file.path) || !file.exists) return {};
    sources.add(file);
    final Object? yaml;
    try {
      yaml = _plain(loadYaml(file.readAsStringSync()));
    } on YamlException {
      return {};
    }
    if (yaml is! Map<String, Object?>) return {};

    var merged = <String, Object?>{};
    final includes = switch (yaml['include']) {
      final String include => [include],
      final List<Object?> list => list.whereType<String>().toList(),
      _ => const <String>[],
    };
    for (final include in includes) {
      final included = _resolveInclude(file, include);
      if (included != null) {
        merged = _merge(merged, _read(included, sources, visiting));
      }
    }

    return _merge(merged, yaml);
  }

  static File? _resolveInclude(File from, String include) {
    final provider = from.provider;
    final pathContext = provider.pathContext;
    if (!include.startsWith('package:')) {
      return provider.getFile(
        pathContext.normalize(pathContext.join(from.parent.path, include)),
      );
    }

    final uri = Uri.parse(include);
    final packageName = uri.pathSegments.first;
    final rest = uri.pathSegments.skip(1).join('/');
    final libUri = _packageLibUri(from.parent, packageName);

    return libUri == null
        ? null
        : provider.getFile(pathContext.fromUri(libUri.resolve(rest)));
  }

  /// The `lib/` directory of [packageName] according to the nearest
  /// `.dart_tool/package_config.json` above [folder].
  static Uri? _packageLibUri(Folder folder, String packageName) {
    final pathContext = folder.provider.pathContext;
    for (Folder? current = folder; current != null;) {
      final configFile = current
          .getFolder('.dart_tool')
          .getFile('package_config.json');
      if (configFile.exists) {
        final Object? json;
        try {
          json = jsonDecode(configFile.readAsStringSync());
        } on FormatException {
          return null;
        }
        final packages = json is Map ? json['packages'] : null;
        if (packages is! List) return null;
        for (final package in packages) {
          if (package is Map && package['name'] == packageName) {
            final base = pathContext.toUri('${configFile.parent.path}/');
            final root = base.resolve(_asDirectory('${package['rootUri']}'));

            return root.resolve(_asDirectory('${package['packageUri']}'));
          }
        }

        return null;
      }
      current = current.isRoot ? null : current.parent;
    }

    return null;
  }

  static String _asDirectory(String uri) => uri.endsWith('/') ? uri : '$uri/';

  /// Merges [override] onto [base]: nested maps merge, other values replace.
  static Map<String, Object?> _merge(
    Map<String, Object?> base,
    Map<String, Object?> override,
  ) => {
    ...base,
    for (final MapEntry(:key, :value) in override.entries)
      key: switch ((base[key], value)) {
        (final Map<String, Object?> a, final Map<String, Object?> b) => _merge(
          a,
          b,
        ),
        _ => value,
      },
  };

  /// Converts parsed YAML into plain maps and lists with string keys.
  static Object? _plain(Object? node) => switch (node) {
    final YamlMap map => {
      for (final MapEntry(:key, :value) in map.entries) '$key': _plain(value),
    },
    final YamlList list => [for (final item in list) _plain(item)],
    _ => node,
  };
}

class _CachedOptions {
  _CachedOptions(this.options, this.stamps);

  final Map<String, Object?> options;
  final List<(File, int)> stamps;

  bool get isCurrent => stamps.every(
    (stamp) => stamp.$1.exists && stamp.$1.modificationStamp == stamp.$2,
  );
}
