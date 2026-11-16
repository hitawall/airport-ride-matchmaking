const _weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const _months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/// "2:30 PM"
String formatTime(DateTime value) {
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, "0");
  final suffix = local.hour < 12 ? "AM" : "PM";
  return "$hour12:$minute $suffix";
}

/// "Today, 2:30 PM", "Tomorrow, 9:05 AM", "Mon 17 Nov, 6:00 PM".
/// [now] is injectable for tests.
String formatFriendlyDateTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(local.year, local.month, local.day);
  final diffDays = day.difference(today).inDays;

  final String dayLabel;
  if (diffDays == 0) {
    dayLabel = "Today";
  } else if (diffDays == 1) {
    dayLabel = "Tomorrow";
  } else if (diffDays == -1) {
    dayLabel = "Yesterday";
  } else {
    dayLabel = "${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month - 1]}";
  }
  return "$dayLabel, ${formatTime(local)}";
}
