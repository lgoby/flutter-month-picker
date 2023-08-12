import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calendar_month_picker.dart';
import 'constants.dart';
import 'utils.dart';

Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  required DateTime firstMonth,
  required DateTime lastMonth,
  DateTime? currentMonth,
  SelectableMonthPredicate? selectableMonthPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  TextDirection? textDirection,
  TransitionBuilder? builder,
  MonthPickerMode initialMonthPickerMode = MonthPickerMode.month,
  Offset? anchorPoint,
}) async {
  initialMonth = MonthUtils.monthOnly(initialMonth);
  firstMonth = MonthUtils.monthOnly(firstMonth);
  lastMonth = MonthUtils.monthOnly(lastMonth);
  assert(
    !lastMonth.isBefore(firstMonth),
    'lastMonth $lastMonth must be on or after firstMonth $firstMonth.',
  );
  assert(
    !initialMonth.isBefore(firstMonth),
    'initialMonth $initialMonth must be on or after firstMonth $firstMonth.',
  );
  assert(
    !initialMonth.isAfter(lastMonth),
    'initialMonth $initialMonth must be on or before lastMonth $lastMonth.',
  );
  assert(
    selectableMonthPredicate == null || selectableMonthPredicate(initialMonth),
    'Provided initialMonth $initialMonth must satisfy provided selectableMonthPredicate.',
  );
  assert(debugCheckHasMaterialLocalizations(context));

  Widget dialog = MonthPickerDialog(
    initialMonth: initialMonth,
    firstMonth: firstMonth,
    lastMonth: lastMonth,
    currentMonth: currentMonth,
    selectableMonthPredicate: selectableMonthPredicate,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    initialCalendarMode: initialMonthPickerMode,
  );

  if (textDirection != null) {
    dialog = Directionality(
      textDirection: textDirection,
      child: dialog,
    );
  }

  if (locale != null) {
    dialog = Localizations.override(
      context: context,
      locale: locale,
      child: dialog,
    );
  }

  return showDialog<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    builder: (BuildContext context) {
      return builder == null ? dialog : builder(context, dialog);
    },
    anchorPoint: anchorPoint,
  );
}

class MonthPickerDialog extends StatefulWidget {
  MonthPickerDialog({
    super.key,
    required DateTime initialMonth,
    required DateTime firstMonth,
    required DateTime lastMonth,
    DateTime? currentMonth,
    this.selectableMonthPredicate,
    this.cancelText,
    this.confirmText,
    this.helpText,
    this.initialCalendarMode = MonthPickerMode.month,
    this.restorationId,
  })  : initialMonth = MonthUtils.monthOnly(initialMonth),
        firstMonth = MonthUtils.monthOnly(firstMonth),
        lastMonth = MonthUtils.monthOnly(lastMonth),
        currentMonth = MonthUtils.monthOnly(currentMonth ?? DateTime.now()) {
    assert(
      !this.lastMonth.isBefore(this.firstMonth),
      'lastMonth ${this.lastMonth} must be on or after firstMonth ${this.firstMonth}.',
    );
    assert(
      !this.initialMonth.isBefore(this.firstMonth),
      'initialMonth ${this.initialMonth} must be on or after firstMonth ${this.firstMonth}.',
    );
    assert(
      !this.initialMonth.isAfter(this.lastMonth),
      'initialMonth ${this.initialMonth} must be on or before lastMonth ${this.lastMonth}.',
    );
    assert(
      selectableMonthPredicate == null || selectableMonthPredicate!(this.initialMonth),
      'Provided initialMonth ${this.initialMonth} must satisfy provided selectableMonthPredicate',
    );
  }

  final DateTime initialMonth;
  final DateTime firstMonth;
  final DateTime lastMonth;
  final DateTime currentMonth;
  final SelectableMonthPredicate? selectableMonthPredicate;
  final String? cancelText;
  final String? confirmText;
  final String? helpText;
  final MonthPickerMode initialCalendarMode;
  final String? restorationId;

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> with RestorationMixin {
  late final RestorableDateTime _selectedMonth = RestorableDateTime(widget.initialMonth);

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedMonth, 'selected_month');
  }

  final GlobalKey _calendarPickerKey = GlobalKey();

  void _handleOk() {
    Navigator.pop(context, _selectedMonth.value);
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  void _handleDateChanged(DateTime month) {
    setState(() {
      _selectedMonth.value = month;
    });
  }

  Size _dialogSize(BuildContext context) {
    final bool useMaterial3 = Theme.of(context).useMaterial3;
    final Orientation orientation = MediaQuery.orientationOf(context);
    switch (orientation) {
      case Orientation.portrait:
        return useMaterial3 ? calendarPortraitDialogSizeM3 : calendarPortraitDialogSizeM2;
      case Orientation.landscape:
        return calendarLandscapeDialogSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool useMaterial3 = theme.useMaterial3;
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final Orientation orientation = MediaQuery.orientationOf(context);
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);
    final TextTheme textTheme = theme.textTheme;

    TextStyle? headlineStyle;
    if (useMaterial3) {
      headlineStyle = datePickerTheme.headerHeadlineStyle ?? defaults.headerHeadlineStyle;
    } else {
      headlineStyle = orientation == Orientation.landscape ? textTheme.headlineSmall : textTheme.headlineMedium;
    }
    final Color? headerForegroundColor = datePickerTheme.headerForegroundColor ?? defaults.headerForegroundColor;
    headlineStyle = headlineStyle?.copyWith(color: headerForegroundColor);

    final Widget actions = Container(
      alignment: AlignmentDirectional.centerEnd,
      constraints: const BoxConstraints(minHeight: 52.0),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: OverflowBar(
        spacing: 8,
        children: <Widget>[
          TextButton(
            onPressed: _handleCancel,
            child: Text(widget.cancelText ??
                (useMaterial3 ? localizations.cancelButtonLabel : localizations.cancelButtonLabel.toUpperCase())),
          ),
          TextButton(
            onPressed: _handleOk,
            child: Text(widget.confirmText ?? localizations.okButtonLabel),
          ),
        ],
      ),
    );

    final Widget picker = CalendarMonthPicker(
      key: _calendarPickerKey,
      initialMonth: _selectedMonth.value,
      firstMonth: widget.firstMonth,
      lastMonth: widget.lastMonth,
      currentMonth: widget.currentMonth,
      onMonthChanged: _handleDateChanged,
      selectableMonthPredicate: widget.selectableMonthPredicate,
      initialCalendarMode: widget.initialCalendarMode,
    );

    final Widget header = _MonthPickerDialogHeader(
      helpText: widget.helpText ??
          (useMaterial3 ? localizations.datePickerHelpText : localizations.datePickerHelpText.toUpperCase()),
      titleText: localizations.formatMonthYear(_selectedMonth.value),
      titleStyle: headlineStyle,
      orientation: orientation,
      isShort: orientation == Orientation.landscape,
    );

    final double textScaleFactor = math.min(MediaQuery.textScaleFactorOf(context), 1.3);
    final Size dialogSize = _dialogSize(context) * textScaleFactor;
    final DialogTheme dialogTheme = theme.dialogTheme;
    return Dialog(
      backgroundColor: datePickerTheme.backgroundColor ?? defaults.backgroundColor,
      elevation: useMaterial3
          ? datePickerTheme.elevation ?? defaults.elevation!
          : datePickerTheme.elevation ?? dialogTheme.elevation ?? 24,
      shadowColor: datePickerTheme.shadowColor ?? defaults.shadowColor,
      surfaceTintColor: datePickerTheme.surfaceTintColor ?? defaults.surfaceTintColor,
      shape: useMaterial3
          ? datePickerTheme.shape ?? defaults.shape
          : datePickerTheme.shape ?? dialogTheme.shape ?? defaults.shape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        width: dialogSize.width,
        height: dialogSize.height,
        duration: dialogSizeAnimationDuration,
        curve: Curves.easeIn,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: textScaleFactor,
          ),
          child: Builder(builder: (BuildContext context) {
            switch (orientation) {
              case Orientation.portrait:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    header,
                    if (useMaterial3) const Divider(),
                    Expanded(child: picker),
                    actions,
                  ],
                );
              case Orientation.landscape:
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    header,
                    if (useMaterial3) const VerticalDivider(),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: picker),
                          actions,
                        ],
                      ),
                    ),
                  ],
                );
            }
          }),
        ),
      ),
    );
  }
}

class _MonthPickerDialogHeader extends StatelessWidget {
  const _MonthPickerDialogHeader({
    required this.helpText,
    required this.titleText,
    required this.titleStyle,
    required this.orientation,
    this.isShort = false,
  });

  static const double _monthPickerHeaderLandscapeWidth = 152.0;
  static const double _monthPickerHeaderPortraitHeight = 120.0;
  static const double _monthPickerHeaderPaddingLandscape = 16.0;

  final String helpText;
  final String titleText;
  final TextStyle? titleStyle;
  final Orientation orientation;
  final bool isShort;

  @override
  Widget build(BuildContext context) {
    final DatePickerThemeData themeData = DatePickerTheme.of(context);
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);
    final Color? backgroundColor = themeData.headerBackgroundColor ?? defaults.headerBackgroundColor;
    final Color? foregroundColor = themeData.headerForegroundColor ?? defaults.headerForegroundColor;
    final TextStyle? helpStyle = (themeData.headerHelpStyle ?? defaults.headerHelpStyle)?.copyWith(
      color: foregroundColor,
    );

    final Text help = Text(
      helpText,
      style: helpStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final Text title = Text(
      titleText,
      semanticsLabel: titleText,
      style: titleStyle,
      maxLines: orientation == Orientation.portrait ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );

    switch (orientation) {
      case Orientation.portrait:
        return SizedBox(
          height: _monthPickerHeaderPortraitHeight,
          child: Material(
            color: backgroundColor,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 24,
                end: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 16),
                  help,
                  const Flexible(child: SizedBox(height: 38)),
                  Expanded(child: title),
                ],
              ),
            ),
          ),
        );
      case Orientation.landscape:
        return SizedBox(
          width: _monthPickerHeaderLandscapeWidth,
          child: Material(
            color: backgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _monthPickerHeaderPaddingLandscape,
                  ),
                  child: help,
                ),
                SizedBox(height: isShort ? 16 : 56),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _monthPickerHeaderPaddingLandscape,
                    ),
                    child: title,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
