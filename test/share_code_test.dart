import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:we_plan2/utils/share_code.dart';

void main() {
  group('ShareCode.generate', () {
    test('makes 12 characters from the unambiguous alphabet', () {
      for (var i = 0; i < 200; i++) {
        final code = ShareCode.generate();
        expect(code, hasLength(ShareCode.length));
        expect(code, matches(RegExp('^[${ShareCode.alphabet}]{12}\$')));
      }
    });

    test('is not a timestamp', () {
      final code = ShareCode.generate();
      expect(int.tryParse(code), isNull);
    });

    test('makes a different code each time', () {
      final codes = {for (var i = 0; i < 1000; i++) ShareCode.generate()};
      expect(codes, hasLength(1000));
    });

    test('follows the random source it is given', () {
      expect(
        ShareCode.generate(random: Random(1)),
        ShareCode.generate(random: Random(1)),
      );
    });

    test('can be a calendar name the Firestore rules allow', () {
      // The rules only open collections named shared_<letters and digits>.
      expect(
        'shared_${ShareCode.generate()}',
        matches(RegExp(r'^shared_[A-Za-z0-9]+$')),
      );
    });
  });
}
