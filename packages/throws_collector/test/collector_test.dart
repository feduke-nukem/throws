import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:throws_collector/src/collector.dart';

import 'helpers.dart';

void main() {
  test('collects thrown errors from fixture project', () async {
    final root = 'test/fixtures/simple_project';
    final entries = await collectThrows(rootPath: root);

    final members = entries.values.single;

    expect(members['Foo.bar'], contains('StateError'));
    expect(members['baz'], contains('Exception'));
  });

  group('collectThrows', () {
    late Map<String, Map<String, Set<String>>> entries;

    setUpAll(() async {
      final root = await createPackage({
        'a.dart': r'''
class Foo {
  Foo() {
    throw FormatException('x');
  }

  Foo.named() {
    throw ArgumentError('x');
  }

  void bar() {
    throw StateError('x');
  }

  void viaVariable(Exception error) {
    throw error;
  }

  void onlyRethrows() {
    try {
      bar();
    } catch (_) {
      rethrow;
    }
  }

  /// Throws a [FormatException] if [input] is bad.
  void documented(String input) {}

  void inClosure() {
    () => throw StateError('x');
  }

  void _private() {
    throw StateError('x');
  }
}

class _Hidden {
  void m() {
    throw StateError('x');
  }
}

mixin M {
  void m() {
    throw UnsupportedError('x');
  }
}

enum E {
  a;

  void m() {
    throw RangeError('x');
  }
}

extension StringX on String {
  void m() {
    throw StateError('x');
  }
}

void top() {
  throw Exception('x');
}

void quiet() {}
''',
        '_private_file.dart': '''
void hidden() {
  throw StateError('x');
}
''',
      });
      entries = await collectThrows(rootPath: root);
    });

    Set<String>? errorsFor(String member) =>
        entries['package:demo/a.dart']?[member];

    test('top-level function', () {
      expect(errorsFor('top'), {'Exception'});
    });

    test('method', () {
      expect(errorsFor('Foo.bar'), {'StateError'});
    });

    test('named constructor', () {
      expect(errorsFor('Foo.named'), {'ArgumentError'});
      expect(errorsFor('Foo.new'), {'FormatException'});
    });

    test('variable uses its static type', () {
      expect(errorsFor('Foo.viaVariable'), {'Exception'});
    });

    test('rethrow without type falls back to Object', () {
      expect(errorsFor('Foo.onlyRethrows'), {'Object'});
    });

    test('doc comment mentions', () {
      expect(errorsFor('Foo.documented'), {'FormatException'});
    });

    test('mixin, enum and extension members', () {
      expect(errorsFor('M.m'), {'UnsupportedError'});
      expect(errorsFor('E.m'), {'RangeError'});
      expect(errorsFor('StringX.m'), {'StateError'});
    });

    test('skips closures, private members and non-throwing functions', () {
      expect(errorsFor('Foo.inClosure'), isNull);
      expect(errorsFor('Foo._private'), isNull);
      expect(errorsFor('_Hidden.m'), isNull);
      expect(errorsFor('quiet'), isNull);
      expect(entries.keys, ['package:demo/a.dart']);
    });
  });

  test('analyzes only the given files', () async {
    final root = await createPackage({
      'a.dart': 'void a() { throw StateError("x"); }',
      'b.dart': 'void b() { throw StateError("x"); }',
    });
    final entries = await collectThrows(
      rootPath: root,
      files: [File(p.join(root, 'lib', 'a.dart'))],
    );
    expect(entries, {
      'package:demo/a.dart': {
        'a': {'StateError'},
      },
    });
  });
}
