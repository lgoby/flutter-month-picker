import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'month_picker.dart';
import 'utils.dart';

class MonthSelectorPicker extends StatefulWidget {
  MonthSelectorPicker({
    super.key,
    required this.initialYear,
    required this.currentMonth,
    required this.firstMonth,
    required this.lastMonth,
    required this.selectedMonth,
    required this.onChanged,
    required this.onDisplayedYearChanged,
    this.selectableMonthPredicate,
  })  : assert(!firstMonth.isAfter(lastMonth)),
        assert(!initialYear.isBefore(firstMonth)),
        assert(!initialYear.isAfter(lastMonth)),
        assert(!selectedMonth.isBefore(firstMonth)),
        assert(!selectedMonth.isAfter(lastMonth));

  final DateTime initialYear;
  final DateTime currentMonth;
  final DateTime firstMonth;
  final DateTime lastMonth;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;
  final ValueChanged<DateTime> onDisplayedYearChanged;
  final SelectableMonthPredicate? selectableMonthPredicate;

  @override
  State<MonthSelectorPicker> createState() => _MonthSelectorPickerState();
}

class _MonthSelectorPickerState extends State<MonthSelectorPicker> {
  final GlobalKey _pageViewKey = GlobalKey();
  late DateTime _currentYear;
  late PageController _pageController;
  late MaterialLocalizations _localizations;
  late TextDirection _textDirection;
  Map<ShortcutActivator, Intent>? _shortcutMap;
  Map<Type, Action<Intent>>? _actionMap;
  late FocusNode _monthGridFocus;
  DateTime? _focusedMonth;

  @override
  void initState() {
    super.initState();
    _currentYear = widget.initialYear;
    _pageController = PageController(initialPage: MonthUtils.yearDelta(widget.firstMonth, _currentYear));
    _shortcutMap = const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
      SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
      SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
      SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
    };
    _actionMap = <Type, Action<Intent>>{
      NextFocusIntent: CallbackAction<NextFocusIntent>(onInvoke: _handleGridNextFocus),
      PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(onInvoke: _handleGridPreviousFocus),
      DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(onInvoke: _handleDirectionFocus),
    };
    _monthGridFocus = FocusNode(debugLabel: 'Month Grid');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localizations = MaterialLocalizations.of(context);
    _textDirection = Directionality.of(context);
  }

  @override
  void didUpdateWidget(MonthSelectorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialYear != oldWidget.initialYear && widget.initialYear != _currentYear) {
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration timeStamp) => _showYear(widget.initialYear, jump: true),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _monthGridFocus.dispose();
    super.dispose();
  }

  void _handleMonthSelected(DateTime selectedMonth) {
    _focusedMonth = selectedMonth;
    widget.onChanged(selectedMonth);
  }

  void _handleYearPageChanged(int yearPage) {
    setState(() {
      final DateTime yearDate = MonthUtils.addYearsToYearDate(widget.firstMonth, yearPage);
      if (!MonthUtils.isSameYear(_currentYear, yearDate)) {
        _currentYear = MonthUtils.yearOnly(yearDate);
        widget.onDisplayedYearChanged(_currentYear);
        if (_focusedMonth != null && !MonthUtils.isSameYear(_focusedMonth, _currentYear)) {
          _focusedMonth = _focusableMonthForYear(_currentYear, _focusedMonth!.month);
        }
        SemanticsService.announce(
          _localizations.formatYear(_currentYear),
          _textDirection,
        );
      }
    });
  }

  DateTime? _focusableMonthForYear(DateTime yearDate, int preferredMonth) {
    final DateTime newFocus = DateTime(yearDate.year, preferredMonth);
    if (_isSelectable(newFocus)) {
      return newFocus;
    }
    return null;
  }

  void _handleNextYear() {
    if (!_isDisplayingLastYear) {
      _pageController.nextPage(
        duration: monthSelectorScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  void _handlePreviousYear() {
    if (!_isDisplayingFirstYear) {
      _pageController.previousPage(
        duration: monthSelectorScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  void _showYear(DateTime year, {bool jump = false}) {
    final int yearPage = MonthUtils.yearDelta(widget.firstMonth, year);
    if (jump) {
      _pageController.jumpToPage(yearPage);
    } else {
      _pageController.animateToPage(
        yearPage,
        duration: monthSelectorScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  bool get _isDisplayingFirstYear {
    return !_currentYear.isAfter(
      MonthUtils.yearOnly(widget.firstMonth),
    );
  }

  bool get _isDisplayingLastYear {
    return !_currentYear.isBefore(
      MonthUtils.yearOnly(widget.lastMonth),
    );
  }

  void _handleGridFocusChange(bool focused) {
    setState(() {
      if (focused && _focusedMonth == null) {
        if (MonthUtils.isSameYear(widget.selectedMonth, _currentYear)) {
          _focusedMonth = widget.selectedMonth;
        } else if (MonthUtils.isSameYear(widget.currentMonth, _currentYear)) {
          _focusedMonth = _focusableMonthForYear(_currentYear, widget.currentMonth.month);
        } else {
          _focusedMonth = _focusableMonthForYear(_currentYear, 1);
        }
      }
    });
  }

  void _handleGridNextFocus(NextFocusIntent intent) {
    _monthGridFocus.requestFocus();
    _monthGridFocus.nextFocus();
  }

  void _handleGridPreviousFocus(PreviousFocusIntent intent) {
    _monthGridFocus.requestFocus();
    _monthGridFocus.previousFocus();
  }

  void _handleDirectionFocus(DirectionalFocusIntent intent) {
    assert(_focusedMonth != null);
    setState(() {
      final DateTime? nextMonth = _nextMonthInDirection(_focusedMonth!, intent.direction);
      if (nextMonth != null) {
        _focusedMonth = nextMonth;
        if (!MonthUtils.isSameYear(_focusedMonth, _currentYear)) {
          _showYear(_focusedMonth!);
        }
      }
    });
  }

  // TODO need to check
  static const Map<TraversalDirection, int> _directionOffset = <TraversalDirection, int>{
    TraversalDirection.up: -monthPickerColumnCount,
    TraversalDirection.right: 1,
    TraversalDirection.down: monthPickerColumnCount,
    TraversalDirection.left: -1,
  };

  int _monthDirectionOffset(TraversalDirection traversalDirection, TextDirection textDirection) {
    if (textDirection == TextDirection.rtl) {
      if (traversalDirection == TraversalDirection.left) {
        traversalDirection = TraversalDirection.right;
      } else if (traversalDirection == TraversalDirection.right) {
        traversalDirection = TraversalDirection.left;
      }
    }
    return _directionOffset[traversalDirection]!;
  }

  DateTime? _nextMonthInDirection(DateTime month, TraversalDirection direction) {
    final TextDirection textDirection = Directionality.of(context);
    DateTime nextDate = MonthUtils.addMonthsToMonthDate(month, _monthDirectionOffset(direction, textDirection));
    while (!nextDate.isBefore(widget.firstMonth) && !nextDate.isAfter(widget.lastMonth)) {
      if (_isSelectable(nextDate)) {
        return nextDate;
      }
      nextDate = MonthUtils.addMonthsToMonthDate(nextDate, _monthDirectionOffset(direction, textDirection));
    }
    return null;
  }

  bool _isSelectable(DateTime month) {
    return widget.selectableMonthPredicate == null || widget.selectableMonthPredicate!.call(month);
  }

  Widget _buildItems(BuildContext context, int index) {
    final DateTime year = MonthUtils.addYearsToYearDate(widget.firstMonth, index);
    return MonthPicker(
      key: ValueKey<DateTime>(year),
      selectedMonth: widget.selectedMonth,
      currentMonth: widget.currentMonth,
      onChanged: _handleMonthSelected,
      firstMonth: widget.firstMonth,
      lastMonth: widget.lastMonth,
      displayedYear: year,
      selectableMonthPredicate: widget.selectableMonthPredicate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color controlColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.60);

    return Semantics(
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            height: monthSelectorHeaderHeight,
            child: Row(
              children: <Widget>[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: controlColor,
                  tooltip: _isDisplayingFirstYear ? null : _localizations.previousMonthTooltip,
                  onPressed: _isDisplayingFirstYear ? null : _handlePreviousYear,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: controlColor,
                  tooltip: _isDisplayingLastYear ? null : _localizations.nextMonthTooltip,
                  onPressed: _isDisplayingLastYear ? null : _handleNextYear,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FocusableActionDetector(
              shortcuts: _shortcutMap,
              actions: _actionMap,
              focusNode: _monthGridFocus,
              onFocusChange: _handleGridFocusChange,
              child: FocusedMonth(
                month: _monthGridFocus.hasFocus ? _focusedMonth : null,
                child: PageView.builder(
                  key: _pageViewKey,
                  controller: _pageController,
                  itemBuilder: _buildItems,
                  itemCount: MonthUtils.yearDelta(widget.firstMonth, widget.lastMonth) + 1,
                  onPageChanged: _handleYearPageChanged,
                ),
              ),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
