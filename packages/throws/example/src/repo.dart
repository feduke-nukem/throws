import 'package:throws/throws.dart';

abstract interface class IRepository {
  @Throws(errors: {Exception})
  Future<List<String>> getSettings();
}
