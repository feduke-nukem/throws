import 'dart:io';

import 'package:path/path.dart' as p;

class Spinner {
  final int total;
  final List<String> _frames = const ['|', '/', '-', '\\'];
  var _frameIndex = 0;

  Spinner({required this.total});

  void tick(int current, String path) {
    if (!stdout.hasTerminal) {
      return;
    }
    final frame = _frames[_frameIndex];
    _frameIndex = (_frameIndex + 1) % _frames.length;
    final fileName = p.basename(path);
    stdout.write('\r$frame Analyzing $current/$total: $fileName');
  }

  void done(int entries) {
    if (!stdout.hasTerminal) {
      return;
    }
    stdout.write('\rDone. Collected $entries entries.');
    stdout.writeln();
  }
}
