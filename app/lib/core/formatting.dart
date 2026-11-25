import 'package:intl/intl.dart';

/// Türkçe tarih, sayı ve arama yardımcıları.
abstract final class Fmt {
  static final DateFormat _dayMonth = DateFormat('d MMM', 'tr');
  static final DateFormat _dayMonthYear = DateFormat('d MMM y', 'tr');
  static final DateFormat _long = DateFormat('d MMMM y, HH:mm', 'tr');
  static final DateFormat _date = DateFormat('d MMMM y', 'tr');
  static final DateFormat _time = DateFormat('HH:mm', 'tr');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'tr');
  static final NumberFormat _decimal = NumberFormat.decimalPattern('tr');

  /// Göreli zamanların hesaplandığı saat. Testler sabit bir "şimdi" verir ki ekran görüntüleri tutarlı olsun.
  static DateTime Function() now = DateTime.now;

  /// "az önce", "5 dk önce", "3 sa önce", "dün", "4 gün önce", "12 Kas".
  static String relative(DateTime time, {DateTime? now}) {
    final current = (now ?? Fmt.now()).toLocal();
    final local = time.toLocal();
    final diff = current.difference(local);
    if (diff.isNegative || diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays == 1) return 'dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (local.year == current.year) return _dayMonth.format(local);
    return _dayMonthYear.format(local);
  }

  static String longDate(DateTime time) => _long.format(time.toLocal());
  static String date(DateTime time) => _date.format(time.toLocal());
  static String shortDate(DateTime time) {
    final local = time.toLocal();
    return local.year == DateTime.now().year ? _dayMonth.format(local) : _dayMonthYear.format(local);
  }

  static String clock(DateTime time) => _time.format(time.toLocal());

  /// 1234 → "1,2 B", 1234567 → "1,2 Mn".
  static String compact(int value) => _compact.format(value);

  static String decimal(int value) => _decimal.format(value);

  /// Model parametre sayısı: 7_241_000_000 → "7,2 Mr".
  static String parameters(int value) => _compact.format(value);
}

/// Türkçe karakterlere duyarsız arama için metni sadeleştirir:
/// "Güvenlik" ve "guvenlik", "İstanbul" ve "istanbul" aynı sonucu verir.
String foldForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_fold[char] ?? char.toLowerCase());
  }
  return buffer.toString();
}

const Map<String, String> _fold = {
  'İ': 'i',
  'I': 'i',
  'ı': 'i',
  'Ğ': 'g',
  'ğ': 'g',
  'Ü': 'u',
  'ü': 'u',
  'Ş': 's',
  'ş': 's',
  'Ö': 'o',
  'ö': 'o',
  'Ç': 'c',
  'ç': 'c',
  'Â': 'a',
  'â': 'a',
  'Î': 'i',
  'î': 'i',
  'Û': 'u',
  'û': 'u',
};
