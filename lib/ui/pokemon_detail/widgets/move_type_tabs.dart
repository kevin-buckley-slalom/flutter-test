import 'package:flutter/material.dart';

class MoveTypeTabs extends StatefulWidget {
  final List<String> availableTypes;
  final String selectedMoveType;
  final Function(String) onMoveTypeChanged;

  const MoveTypeTabs({
    super.key,
    required this.availableTypes,
    required this.selectedMoveType,
    required this.onMoveTypeChanged,
  });

  @override
  State<MoveTypeTabs> createState() => _MoveTypeTabsState();
}

class _MoveTypeTabsState extends State<MoveTypeTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _initialIndex() {
    final idx = widget.availableTypes.indexOf(widget.selectedMoveType);
    return idx == -1 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.availableTypes.length,
      vsync: this,
      initialIndex: _initialIndex(),
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        widget.onMoveTypeChanged(
          widget.availableTypes[_tabController.index],
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant MoveTypeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate controller if length changes
    if (oldWidget.availableTypes.length != widget.availableTypes.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: widget.availableTypes.length,
        vsync: this,
        initialIndex: _initialIndex(),
      );
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          widget.onMoveTypeChanged(
            widget.availableTypes[_tabController.index],
          );
        }
      });
    } else if (oldWidget.selectedMoveType != widget.selectedMoveType) {
      final idx = _initialIndex();
      if (_tabController.index != idx) {
        _tabController.animateTo(idx);
      }
    }
  }

  String _formatMoveType(String type) {
    if (['tm', 'hm', 'tr'].contains(type)) {
      return type.toUpperCase();
    }
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final useTabBar = widget.availableTypes.length <= 3;

    if (useTabBar) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.6),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          dividerColor: Colors.transparent,
          tabs: widget.availableTypes
              .map(
                (t) => Tab(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 80),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(_formatMoveType(t)),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    // Multi-row selector for >3 types, styled like tabs
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.availableTypes.map((t) {
          final selected = t == widget.selectedMoveType;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                widget.onMoveTypeChanged(t);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: Text(
                  _formatMoveType(t),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
