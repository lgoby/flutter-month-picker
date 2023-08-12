import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' as intl;

import 'constants.dart';
import 'utils.dart';

class MonthPicker extends StatefulWidget {
  MonthPicker({
    super.key,
    required this.currentMonth,
    required this.displayedYear,
    required this.firstMonth,
    required this.lastMonth,
    required this.selectedMonth,
    required this.onChanged,
    this.selectableMonthPredicate,
  })  : assert(!firstMonth.isAfter(lastMonth)),
        assert(!displayedYear.isBefore(firstMonth)),
        assert(!displayedYear.isAfter(lastMonth)),
        assert(!selectedMonth.isBefore(firstMonth)),
        assert(!selectedMonth.isAfter(lastMonth));

  final DateTime selectedMonth;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstMonth;
  final DateTime lastMonth;
  final DateTime displayedYear;
  final SelectableMonthPredicate? selectableMonthPredicate;

  @override
  State<MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker> {
  late List<FocusNode> _monthFocusNodes;

  @override
  void initState() {
    super.initState();
    _monthFocusNodes = List<FocusNode>.generate(
      monthsInYear,
      (int index) => FocusNode(skipTraversal: true, debugLabel: 'Month ${index + 1}'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DateTime? focusedMonth = FocusedMonth.maybeOf(context);
    if (focusedMonth != null && MonthUtils.isSameYear(widget.displayedYear, focusedMonth)) {
      _monthFocusNodes[focusedMonth.month - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _monthFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);
    final TextStyle? dayStyle = datePickerTheme.dayStyle ?? defaults.dayStyle;

    T? effectiveValue<T>(T? Function(DatePickerThemeData? theme) getProperty) {
      return getProperty(datePickerTheme) ?? getProperty(defaults);
    }

    T? resolve<T>(
      MaterialStateProperty<T>? Function(DatePickerThemeData? theme) getProperty,
      Set<MaterialState> states,
    ) {
      return effectiveValue(
        (DatePickerThemeData? theme) {
          return getProperty(theme)?.resolve(states);
        },
      );
    }

    final int year = widget.displayedYear.year;
    final List<Widget> monthItems = [];
    for (var month = 1; month <= monthsInYear; month++) {
      final DateTime monthToBuild = DateTime(year, month);
      final bool isDisabled = monthToBuild.isAfter(widget.lastMonth) ||
          monthToBuild.isBefore(widget.firstMonth) ||
          (widget.selectableMonthPredicate != null && !widget.selectableMonthPredicate!(monthToBuild));
      final bool isSelectedMonth = MonthUtils.isSameMonth(widget.selectedMonth, monthToBuild);
      // TODO need to check
      final bool isToday = MonthUtils.isSameMonth(widget.currentMonth, monthToBuild);
      final String semanticLabelSuffix = isToday ? ', ${localizations.currentDateLabel}' : '';

      final Set<MaterialState> states = <MaterialState>{
        if (isDisabled) MaterialState.disabled,
        if (isSelectedMonth) MaterialState.selected,
      };

      final Color? dayForegroundColor = resolve<Color?>(
          (DatePickerThemeData? theme) => isToday ? theme?.todayForegroundColor : theme?.dayForegroundColor, states);
      final Color? dayBackgroundColor = resolve<Color?>(
          (DatePickerThemeData? theme) => isToday ? theme?.todayBackgroundColor : theme?.dayBackgroundColor, states);
      final MaterialStateProperty<Color?> dayOverlayColor = MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) =>
            effectiveValue((DatePickerThemeData? theme) => theme?.dayOverlayColor?.resolve(states)),
      );
      final BoxDecoration decoration = isToday
          ? BoxDecoration(
              color: dayBackgroundColor,
              border: Border.fromBorderSide(
                  (datePickerTheme.todayBorder ?? defaults.todayBorder!).copyWith(color: dayForegroundColor)),
              shape: BoxShape.circle,
            )
          : BoxDecoration(
              color: dayBackgroundColor,
              shape: BoxShape.circle,
            );

      final monthText = intl.DateFormat().dateSymbols.SHORTMONTHS[month - 1];
      Widget monthWidget = Container(
        decoration: decoration,
        child: Center(
          child: Text(monthText, style: dayStyle?.apply(color: dayForegroundColor)),
        ),
      );

      if (isDisabled) {
        monthWidget = ExcludeSemantics(
          child: monthWidget,
        );
      } else {
        monthWidget = InkResponse(
          focusNode: _monthFocusNodes[month - 1],
          onTap: () => widget.onChanged(monthToBuild),
          //TODO need to check
          radius: monthPickerRowHeight / 2 + 4,
          statesController: MaterialStatesController(states),
          overlayColor: dayOverlayColor,
          child: Semantics(
            label:
                '${localizations.formatDecimal(month)}, ${localizations.formatMonthYear(monthToBuild)}$semanticLabelSuffix',
            selected: isSelectedMonth,
            excludeSemantics: true,
            child: monthWidget,
          ),
        );
      }

      monthItems.add(monthWidget);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: monthPickerPadding,
      ),
      child: GridView.custom(
        physics: const ClampingScrollPhysics(),
        gridDelegate: _monthPickerGridDelegate,
        childrenDelegate: SliverChildListDelegate(
          monthItems,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }
}

class _MonthPickerGridDelegate extends SliverGridDelegate {
  const _MonthPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final rowWidth = constraints.crossAxisExtent - (monthPickerColumnCount - 1) * monthPickerRowSpacing;
    final columnHeight = constraints.viewportMainAxisExtent - (monthPickerRowCount - 1) * monthPickerRowSpacing;
    final double tileWidth = rowWidth / monthPickerColumnCount;
    final double tileHeight = columnHeight / monthPickerRowCount;
    final double width = math.min(tileWidth, tileHeight);
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: width,
      childMainAxisExtent: width,
      crossAxisCount: monthPickerColumnCount,
      crossAxisStride: width + monthPickerRowSpacing,
      mainAxisStride: width + monthPickerRowSpacing,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_MonthPickerGridDelegate oldDelegate) => false;
}

const _MonthPickerGridDelegate _monthPickerGridDelegate = _MonthPickerGridDelegate();
