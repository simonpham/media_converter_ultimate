import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';

abstract class ConvertJobStorage
    implements BaseStorage<ConvertJob>, Disposable {
  const ConvertJobStorage();
}
