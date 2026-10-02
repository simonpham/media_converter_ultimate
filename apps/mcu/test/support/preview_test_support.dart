import 'package:platform_utils/platform_utils.dart';

class TestPreviewSession implements MediaPreviewSession {
  @override
  Future<PreviewMediaInfo> inspect(String path) async =>
      const PreviewMediaInfo(Duration(seconds: 10));

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
