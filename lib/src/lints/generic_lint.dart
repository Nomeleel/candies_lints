import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:candies_lints/src/config.dart';
import 'package:candies_lints/src/error/generic.dart';
import 'package:candies_lints/src/extension.dart';
import 'package:candies_lints/src/lints/lint.dart';
import 'package:candies_lints/src/log.dart';
import 'package:path/path.dart' as path_package;

/// The generic lint base
abstract class GenericLint extends CandyLint {
  Iterable<GenericAnalysisError> toGenericAnalysisErrors({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesLintsConfig? config,
    required String content,
    required LineInfo lineInfo,
  }) sync* {
    final List<SourceRange> nodes = matchLint(
      content,
      path,
      lineInfo,
    ).toList();

    CandiesLintsLogger().log(
      'find ${nodes.length} yaml lint($code) at $path',
      root: analysisContext.root,
    );

    final List<GenericAnalysisError> errors = <GenericAnalysisError>[];
    _cacheErrorsForFixes[path] = errors;
    for (final SourceRange node in nodes) {
      final Location location = sourceSpanToLocation(
        path,
        node,
        lineInfo,
      );

      final GenericAnalysisError error = toGenericAnalysisError(
        analysisContext: analysisContext,
        path: path,
        location: location,
        config: config,
        content: content,
      );
      errors.add(error);
      yield error;
    }
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Stream<AnalysisErrorFixes> toGenericAnalysisErrorFixesStream({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
  }) async* {
    final List<GenericAnalysisError>? errors =
        _cacheErrorsForFixes[parameters.file];
    if (errors != null) {
      for (final GenericAnalysisError error in errors) {
        if (error.location.offset <= parameters.offset &&
            parameters.offset <=
                error.location.offset + error.location.length) {
          yield await toGenericAnalysisErrorFixes(
            error: error,
            path: parameters.file,
            analysisContext: analysisContext,
          );
        }
      }
    }
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<AnalysisErrorFixes> toGenericAnalysisErrorFixes({
    required GenericAnalysisError error,
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    List<SourceChange> fixes = await getGenericFixes(
      analysisContext,
      path,
      error,
    );

    if (fixes.isNotEmpty) {
      fixes = fixes.reversed.toList();
    }

    CandiesLintsLogger().log(
      'get ${fixes.length} fixes for yaml lint($code) at $path',
      root: analysisContext.root,
    );

    return AnalysisErrorFixes(
      error,
      fixes: <PrioritizedSourceChange>[
        for (int i = 0; i < fixes.length; i++)
          PrioritizedSourceChange(i, fixes[i])
      ],
    );
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<SourceChange> getGenericFix({
    required AnalysisContext analysisContext,
    required String path,
    required String message,
    required void Function(FileEditBuilder builder) buildFileEdit,
  }) async {
    final ChangeBuilder changeBuilder =
        ChangeBuilder(session: analysisContext.currentSession);

    await changeBuilder.addGenericFileEdit(
      path,
      buildFileEdit,
    );

    final SourceChange sourceChange = changeBuilder.sourceChange;
    sourceChange.message = message;
    return sourceChange;
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<List<SourceChange>> getGenericFixes(
    AnalysisContext analysisContext,
    String path,
    GenericAnalysisError error,
  ) async =>
      <SourceChange>[];

  GenericAnalysisError toGenericAnalysisError({
    required AnalysisContext analysisContext,
    required String path,
    required Location location,
    required CandiesLintsConfig? config,
    required String content,
  }) {
    CandiesLintsLogger().log(
      'find error: $code at ${location.startLine} line in $path',
      root: analysisContext.root,
    );
    return GenericAnalysisError(
      config?.getSeverity(this) ?? severity,
      type,
      location,
      message,
      code,
      correction: correction,
      contextMessages: contextMessages,
      url: url,
      content: content,
      //hasFix: hasFix,
    );
  }

  Location sourceSpanToLocation(
    String path,
    SourceRange sourceRange,
    LineInfo lineInfo,
  ) {
    final CharacterLocation startLocation =
        lineInfo.getLocation(sourceRange.offset);
    final CharacterLocation endLocation = lineInfo.getLocation(sourceRange.end);
    return Location(
      path,
      sourceRange.offset,
      sourceRange.length,
      startLocation.lineNumber,
      startLocation.columnNumber,
      endLine: endLocation.lineNumber,
      endColumn: endLocation.columnNumber,
    );
  }

  final Map<String, List<GenericAnalysisError>> _cacheErrorsForFixes =
      <String, List<GenericAnalysisError>>{};

  List<GenericAnalysisError>? clearCacheErrors(String path) {
    return _cacheErrorsForFixes.remove(path);
  }

  Iterable<SourceRange> matchLint(
    String content,
    String file,
    LineInfo lineInfo,
  );

  bool isFileType({
    required String file,
    required String type,
  }) {
    return path_package.extension(file) == type;
  }
}
