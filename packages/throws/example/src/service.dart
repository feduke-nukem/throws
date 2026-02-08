import 'repo.dart';

class Service {
  final IRepository _repository;

  Service({
    required IRepository repository,
  }) : _repository = repository;

  Future<void> _doStuff() async {
    final result = await _repository.getSettings();

    print(result);
  }
}
