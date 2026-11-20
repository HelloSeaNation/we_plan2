import 'dart:math';

/// A calendar's share code: the only key to its events, so it must not be
/// guessable.
///
/// New calendars get 12 random characters (about 59 bits), the same as the
/// WePlan phone app. Calendars made before this have a code that is the
/// creation time in milliseconds, a run of digits; those still work.
class ShareCode {
  const ShareCode._();

  /// Letters and digits that can't be mistaken for each other: no 0 or O, no
  /// 1, I or L.
  static const String alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static const int length = 12;

  /// A new random code. It comes from the secure generator; [random] is only
  /// for tests.
  static String generate({Random? random}) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
      ),
    );
  }
}
