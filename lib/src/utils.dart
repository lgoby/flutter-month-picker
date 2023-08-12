import 'package:flutter/material.dart';

abstract final class MonthUtils {
  static DateTime dateOnly(DateTime date) => DateUtils.dateOnly(date);

  static DateTime monthOnly(DateTime date) => DateTime(date.year, date.month);

  static DateTime yearOnly(DateTime date) => DateTime(date.year);

  static bool isSameDay(DateTime? dateA, DateTime? dateB) => DateUtils.isSameDay(dateA, dateB);

  static bool isSameMonth(DateTime? dateA, DateTime? dateB) => DateUtils.isSameMonth(dateA, dateB);

  static bool isSameYear(DateTime? dateA, DateTime? dateB) => dateA?.year == dateB?.year;

  static int monthDelta(DateTime startDate, DateTime endDate) => DateUtils.monthDelta(startDate, endDate);

  static int yearDelta(DateTime startDate, DateTime endDate) => endDate.year - startDate.year;

  static DateTime addMonthsToMonthDate(DateTime monthDate, int monthsToAdd) =>
      DateUtils.addMonthsToMonthDate(monthDate, monthsToAdd);

  static DateTime addYearsToYearDate(DateTime yearDate, int yearsToAdd) => DateTime(yearDate.year + yearsToAdd);

  static DateTime addDaysToDate(DateTime date, int days) => DateUtils.addDaysToDate(date, days);

  static int firstDayOffset(int year, int month, MaterialLocalizations localizations) =>
      DateUtils.firstDayOffset(year, month, localizations);

  static int getDaysInMonth(int year, int month) => DateUtils.getDaysInMonth(year, month);
}

enum MonthPickerMode { month, year }

typedef SelectableMonthPredicate = bool Function(DateTime month);

class FocusedMonth extends InheritedWidget {
  const FocusedMonth({
    super.key,
    required super.child,
    this.month,
  });

  final DateTime? month;

  @override
  bool updateShouldNotify(FocusedMonth oldWidget) {
    return !MonthUtils.isSameMonth(month, oldWidget.month);
  }

  static DateTime? maybeOf(BuildContext context) {
    final FocusedMonth? focusedDate = context.dependOnInheritedWidgetOfExactType<FocusedMonth>();
    return focusedDate?.month;
  }
}
