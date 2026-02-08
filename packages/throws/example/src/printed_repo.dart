import 'delegated_repo.dart';

class PrintedRepo extends DelegatedRepo {
  PrintedRepo(super.repo);

  @override
  Future<List<String>> getSettings() async {
    final result = await super.getSettings();

    print(result);

    if (result.isEmpty) {
      throw Exception('empty');
    }

    return result;
  }
}
