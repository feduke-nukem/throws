import 'repo.dart';

class RepoImpl implements IRepository {
  @override
  Future<List<String>> getSettings() {
    throw ArgumentError();
  }

  @override
  Future<int> getNumber() {
    throw UnimplementedError();
  }
}
