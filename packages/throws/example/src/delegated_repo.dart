import 'repo.dart';

abstract class DelegatedRepo implements IRepository {
  final IRepository _repo;

  DelegatedRepo(this._repo);

  @override
  Future<List<String>> getSettings() => _repo.getSettings();
}
