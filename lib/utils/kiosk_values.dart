/// The original clients use kioskId and kioskID. Keep identifiers case-sensitive.
String kioskIdentity(Map<dynamic, dynamic> row) {
  String id(Object? value) =>
      value is String || value is num ? value.toString().trim() : '';
  final primary = id(row['kioskId']);
  return primary.isNotEmpty ? primary : id(row['kioskID']);
}

num? kioskNumber(Object? value) {
  final parsed = value is num
      ? value
      : value is String
          ? num.tryParse(value.trim())
          : null;
  return parsed?.isFinite == true ? parsed : null;
}

bool kioskHasUsableCapacity(Map<dynamic, dynamic> row) {
  final current = kioskNumber(row['currentCapacity']);
  final maximum = kioskNumber(row['maxCapacity']);
  return current != null &&
      maximum != null &&
      current >= 0 &&
      maximum > 0 &&
      (current / maximum * 100).isFinite;
}
