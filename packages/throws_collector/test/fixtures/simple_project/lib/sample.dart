library;

class Foo {
  void bar() {
    throw StateError('oops');
  }
}

void baz() {
  throw Exception('nope');
}
