import 'package:throws/throws.dart';

abstract interface class IRepository {
  @Throws('', {Exception})
  Future<List<String>> getSettings();
}
