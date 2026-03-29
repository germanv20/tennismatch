const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<String> normalizeDays(List rawDays) {
  final map = {
    'Mon': 'Mon', 'Tue': 'Tue', 'Wed': 'Wed',
    'Thu': 'Thu', 'Fri': 'Fri', 'Sat': 'Sat', 'Sun': 'Sun',
    'Lun': 'Mon', 'Mar': 'Tue', 'Mié': 'Wed',
    'Jue': 'Thu', 'Vie': 'Fri', 'Sáb': 'Sat', 'Dom': 'Sun',
  };

  return rawDays
      .map<String>((day) => map[day.toString()] ?? day.toString())
      .toSet()
      .toList();
}

List<String> sortDays(List rawDays) {
  final normalized = normalizeDays(rawDays);

  normalized.sort(
    (a, b) => weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)),
  );

  return normalized;
}