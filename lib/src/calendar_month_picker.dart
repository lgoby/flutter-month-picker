import 'package:flutter/material.dart' hide YearPicker;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'month_selector.dart';
import 'utils.dart';
import 'year_picker.dart';

class CalendarMonthPicker extends StatefulWidget {
  CalendarMonthPicker({
    super.key,
    required DateTime initialMonth,
    required DateTime firstMonth,
    required DateTime lastMonth,
    DateTime? currentMonth,
    required this.onMonthChanged,
    this.onDisplayedYearChanged,
    this.initialCalendarMode = MonthPickerMode.month,
    this.selectableMonthPredicate,
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
      'Provided initialMonth ${this.initialMonth} must satisfy provided selectableMonthPredicate.',
    );
  }

  final DateTime initialMonth;
  final DateTime firstMonth;
  final DateTime lastMonth;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime>? onDisplayedYearChanged;
  final MonthPickerMode initialCalendarMode;
  final SelectableMonthPredicate? selectableMonthPredicate;

  @override
  State<CalendarMonthPicker> createState() => _CalendarMonthPickerState();
}

class _CalendarMonthPickerState extends State<CalendarMonthPicker> {
  bool _announcedInitialMonth = false;
  late MonthPickerMode _mode;
  late DateTime _currentDisplayedYear;
  late DateTime _selectedMonth;
  final GlobalKey _monthSelectorKey = GlobalKey();
  final GlobalKey _yearPickerKey = GlobalKey();
  late MaterialLocalizations _localizations;
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialCalendarMode;
    _currentDisplayedYear = MonthUtils.yearOnly(widget.initialMonth);
    _selectedMonth = widget.initialMonth;
  }

  @override
  void didUpdateWidget(CalendarMonthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCalendarMode != oldWidget.initialCalendarMode) {
      _mode = widget.initialCalendarMode;
    }
    if (!MonthUtils.isSameDay(widget.initialMonth, oldWidget.initialMonth)) {
      _currentDisplayedYear = MonthUtils.yearOnly(widget.initialMonth);
      _selectedMonth = widget.initialMonth;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    _localizations = MaterialLocalizations.of(context);
    _textDirection = Directionality.of(context);
    if (!_announcedInitialMonth) {
      _announcedInitialMonth = true;
      // TODO need to check
      final bool isToday = MonthUtils.isSameMonth(widget.currentMonth, _selectedMonth);
      final String semanticLabelSuffix = isToday ? ', ${_localizations.currentDateLabel}' : '';
      SemanticsService.announce(
        '${_localizations.formatFullDate(_selectedMonth)}$semanticLabelSuffix',
        _textDirection,
      );
    }
  }

  void _vibrate() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        HapticFeedback.vibrate();
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
    }
  }

  void _handleModeChanged(MonthPickerMode mode) {
    _vibrate();
    setState(() {
      _mode = mode;
      // TODO need to check
      if (_mode == MonthPickerMode.month) {
        SemanticsService.announce(
          _localizations.formatMonthYear(_selectedMonth),
          _textDirection,
        );
      } else {
        SemanticsService.announce(
          _localizations.formatYear(_selectedMonth),
          _textDirection,
        );
      }
    });
  }

  void _handleDisplayedYearChanged(DateTime value) {
    setState(() {
      if (!MonthUtils.isSameYear(_currentDisplayedYear, value)) {
        _currentDisplayedYear = MonthUtils.yearOnly(value);
        widget.onDisplayedYearChanged?.call(_currentDisplayedYear);
      }
    });
  }

  void _handleYearChanged(DateTime value) {
    _vibrate();

    if (value.isBefore(widget.firstMonth)) {
      value = widget.firstMonth;
    } else if (value.isAfter(widget.lastMonth)) {
      value = widget.lastMonth;
    }

    setState(() {
      _mode = MonthPickerMode.month;
      _handleDisplayedYearChanged(value);
    });
  }

  void _handleDayChanged(DateTime value) {
    _vibrate();
    setState(() {
      _selectedMonth = value;
      widget.onMonthChanged(_selectedMonth);
    });
  }

  Widget _buildPicker() {
    switch (_mode) {
      case MonthPickerMode.month:
        return MonthSelectorPicker(
          key: _monthSelectorKey,
          initialYear: _currentDisplayedYear,
          currentMonth: widget.currentMonth,
          firstMonth: widget.firstMonth,
          lastMonth: widget.lastMonth,
          selectedMonth: _selectedMonth,
          onChanged: _handleDayChanged,
          onDisplayedYearChanged: _handleDisplayedYearChanged,
          selectableMonthPredicate: widget.selectableMonthPredicate,
        );
      case MonthPickerMode.year:
        return Padding(
          padding: const EdgeInsets.only(top: monthSelectorHeaderHeight),
          child: YearPicker(
            key: _yearPickerKey,
            currentYear: widget.currentMonth,
            firstYear: widget.firstMonth,
            lastYear: widget.lastMonth,
            selectedYear: _currentDisplayedYear,
            onChanged: _handleYearChanged,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    return Stack(
      children: <Widget>[
        SizedBox(
          height: monthSelectorHeaderHeight + monthPickerHeight,
          child: _buildPicker(),
        ),
        _MonthPickerModeToggleButton(
          mode: _mode,
          title: _localizations.formatYear(_currentDisplayedYear),
          onTitlePressed: () {
            _handleModeChanged(_mode == MonthPickerMode.month ? MonthPickerMode.year : MonthPickerMode.month);
          },
        ),
      ],
    );
  }
}

class _MonthPickerModeToggleButton extends StatefulWidget {
  const _MonthPickerModeToggleButton({
    required this.mode,
    required this.title,
    required this.onTitlePressed,
  });

  final MonthPickerMode mode;
  final String title;
  final VoidCallback onTitlePressed;

  @override
  _MonthPickerModeToggleButtonState createState() => _MonthPickerModeToggleButtonState();
}

class _MonthPickerModeToggleButtonState extends State<_MonthPickerModeToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: widget.mode == MonthPickerMode.year ? 0.5 : 0,
      upperBound: 0.5,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_MonthPickerModeToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) {
      return;
    }

    if (widget.mode == MonthPickerMode.year) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color controlColor = colorScheme.onSurface.withOpacity(0.60);

    return Container(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      height: monthSelectorHeaderHeight,
      child: Row(
        children: <Widget>[
          Flexible(
            child: Semantics(
              label: MaterialLocalizations.of(context).selectYearSemanticsLabel,
              excludeSemantics: true,
              button: true,
              child: SizedBox(
                height: monthSelectorHeaderHeight,
                child: InkWell(
                  onTap: widget.onTitlePressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: controlColor,
                            ),
                          ),
                        ),
                        RotationTransition(
                          turns: _controller,
                          child: Icon(
                            Icons.arrow_drop_down,
                            color: controlColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.mode == MonthPickerMode.month) const SizedBox(width: monthSelectorNavButtonsWidth),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
