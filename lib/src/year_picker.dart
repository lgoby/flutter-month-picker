import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'constants.dart';

class YearPicker extends StatefulWidget {
  YearPicker({
    super.key,
    required this.currentYear,
    required this.firstYear,
    required this.lastYear,
    required this.selectedYear,
    required this.onChanged,
  })  : assert(!firstYear.isAfter(lastYear)),
        assert(!selectedYear.isBefore(firstYear)),
        assert(!selectedYear.isAfter(lastYear));

  final DateTime currentYear;
  final DateTime firstYear;
  final DateTime lastYear;
  final DateTime selectedYear;
  final ValueChanged<DateTime> onChanged;

  @override
  State<YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<YearPicker> {
  late ScrollController _scrollController;

  static const int minYears = 18;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: _scrollOffsetForYear(widget.selectedYear));
  }

  @override
  void didUpdateWidget(YearPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedYear != oldWidget.selectedYear) {
      _scrollController.jumpTo(_scrollOffsetForYear(widget.selectedYear));
    }
  }

  double _scrollOffsetForYear(DateTime date) {
    final int initialYearIndex = date.year - widget.firstYear.year;
    final int initialYearRow = initialYearIndex ~/ yearPickerColumnCount;

    final int centeredYearRow = initialYearRow - 2;
    return _itemCount < minYears ? 0 : centeredYearRow * yearPickerRowHeight;
  }

  Widget _buildYearItem(BuildContext context, int index) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);

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

    final int offset = _itemCount < minYears ? (minYears - _itemCount) ~/ 2 : 0;
    final int year = widget.firstYear.year + index - offset;
    final bool isSelected = year == widget.selectedYear.year;
    final bool isCurrentYear = year == widget.currentYear.year;
    final bool isDisabled = year < widget.firstYear.year || year > widget.lastYear.year;
    const double decorationHeight = 36.0;
    const double decorationWidth = 72.0;

    final Set<MaterialState> states = <MaterialState>{
      if (isDisabled) MaterialState.disabled,
      if (isSelected) MaterialState.selected,
    };

    final Color? textColor = resolve<Color?>(
        (DatePickerThemeData? theme) => isCurrentYear ? theme?.todayForegroundColor : theme?.yearForegroundColor,
        states);
    final Color? background = resolve<Color?>(
        (DatePickerThemeData? theme) => isCurrentYear ? theme?.todayBackgroundColor : theme?.yearBackgroundColor,
        states);
    final MaterialStateProperty<Color?> overlayColor = MaterialStateProperty.resolveWith<Color?>(
      (Set<MaterialState> states) =>
          effectiveValue((DatePickerThemeData? theme) => theme?.dayOverlayColor?.resolve(states)),
    );

    BoxBorder? border;
    if (isCurrentYear) {
      final BorderSide? todayBorder = datePickerTheme.todayBorder ?? defaults.todayBorder;
      if (todayBorder != null) {
        border = Border.fromBorderSide(todayBorder.copyWith(color: textColor));
      }
    }
    final BoxDecoration decoration = BoxDecoration(
      border: border,
      color: background,
      borderRadius: BorderRadius.circular(decorationHeight / 2),
    );

    final TextStyle? itemStyle = (datePickerTheme.yearStyle ?? defaults.yearStyle)?.apply(color: textColor);
    Widget yearItem = Center(
      child: Container(
        decoration: decoration,
        height: decorationHeight,
        width: decorationWidth,
        child: Center(
          child: Semantics(
            selected: isSelected,
            button: true,
            child: Text(localizations.formatYear(DateTime(year)), style: itemStyle),
          ),
        ),
      ),
    );

    if (isDisabled) {
      yearItem = ExcludeSemantics(
        child: yearItem,
      );
    } else {
      yearItem = InkWell(
        key: ValueKey<int>(year),
        onTap: () => widget.onChanged(DateTime(year)),
        statesController: MaterialStatesController(states),
        overlayColor: overlayColor,
        child: yearItem,
      );
    }

    return yearItem;
  }

  int get _itemCount {
    return widget.lastYear.year - widget.firstYear.year + 1;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    return Column(
      children: <Widget>[
        const Divider(),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            dragStartBehavior: DragStartBehavior.start,
            gridDelegate: _yearPickerGridDelegate,
            itemBuilder: _buildYearItem,
            itemCount: math.max(_itemCount, minYears),
            padding: const EdgeInsets.symmetric(horizontal: yearPickerPadding),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _YearPickerGridDelegate extends SliverGridDelegate {
  const _YearPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double tileWidth =
        (constraints.crossAxisExtent - (yearPickerColumnCount - 1) * yearPickerRowSpacing) / yearPickerColumnCount;
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: yearPickerRowHeight,
      crossAxisCount: yearPickerColumnCount,
      crossAxisStride: tileWidth + yearPickerRowSpacing,
      mainAxisStride: yearPickerRowHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_YearPickerGridDelegate oldDelegate) => false;
}

const _YearPickerGridDelegate _yearPickerGridDelegate = _YearPickerGridDelegate();
