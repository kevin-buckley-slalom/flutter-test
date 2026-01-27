import 'package:championdex/ui/pokemon_detail/widgets/move_category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/move.dart';
import 'moves_list_view_model.dart';

class MovesListWidget extends ConsumerStatefulWidget {
  const MovesListWidget({super.key});

  @override
  ConsumerState<MovesListWidget> createState() => _MovesListWidgetState();
}

class _MovesListWidgetState extends ConsumerState<MovesListWidget> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _sortField =
      'name'; // 'name', 'type', 'category', 'power', 'accuracy', 'pp'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Move move, String query) {
    if (query.isEmpty) return true;

    // Check name
    if (move.name.toLowerCase().contains(query)) {
      return true;
    }

    // Check type
    if (move.type.toLowerCase().contains(query)) {
      return true;
    }

    // Check category
    if (move.category.toLowerCase().contains(query)) {
      return true;
    }

    return false;
  }

  List<Move> _sortList(List<Move> list) {
    final sortedList = List<Move>.from(list);

    sortedList.sort((a, b) {
      int comparison = 0;

      switch (_sortField) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'type':
          comparison = a.type.compareTo(b.type);
          break;
        case 'category':
          comparison = a.category.compareTo(b.category);
          break;
        case 'power':
          final aPower = a.power ?? 0;
          final bPower = b.power ?? 0;
          comparison = aPower.compareTo(bPower);
          break;
        case 'accuracy':
          final aAccuracy = a.accuracy ?? 0;
          final bAccuracy = b.accuracy ?? 0;
          comparison = aAccuracy.compareTo(bAccuracy);
          break;
        case 'pp':
          comparison = a.pp.compareTo(b.pp);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sortedList;
  }

  void _showSortOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort By',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortAscending ? 'Asc' : 'Desc',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _sortAscending ? 0 : 0.5,
                        duration: const Duration(milliseconds: 300),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _sortAscending = !_sortAscending;
                            });
                            setModalState(() {});
                          },
                          tooltip: _sortAscending
                              ? 'Switch to descending'
                              : 'Switch to ascending',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Sort options list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...[
                      ('name', 'Name'),
                      ('type', 'Type'),
                      ('category', 'Category'),
                      ('power', 'Power'),
                      ('accuracy', 'Accuracy'),
                      ('pp', 'PP'),
                    ].map((option) {
                      final (field, label) = option;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _sortField = field;
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: _sortField == field
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Text(
                                label,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _sortField == field
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontWeight: _sortField == field
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movesAsync = ref.watch(movesListViewModelProvider);
    final theme = Theme.of(context);

    return movesAsync.when(
      data: (movesList) {
        // Filter the list based on search query
        final filteredList = _searchQuery.isEmpty
            ? movesList
            : movesList
                .where((move) => _matchesSearch(move, _searchQuery))
                .toList();

        // Sort the filtered list
        final sortedList = _sortList(filteredList);

        return Column(
          children: [
            // Search bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, type, or category...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.sort,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () => _showSortOptions(context),
                      tooltip: 'Sort',
                    ),
                  ],
                ),
              ),
            ),

            // List content
            Expanded(
              child: sortedList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No moves found'
                              : 'No moves match "$_searchQuery"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Scrollbar(
                      thickness: 16,
                      radius: const Radius.circular(8),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: sortedList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final move = sortedList[index];
                          return _MoveListItem(move: move);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading moves data',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveListItem extends StatelessWidget {
  final Move move;

  const _MoveListItem({required this.move});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
    final dividerColorLight =
        theme.colorScheme.onSurface.withValues(alpha: 0.2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/move-detail',
            arguments: move.name,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Category icon + Move name
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Fixed width for category icon
                    SizedBox(
                      width: 50,
                      child: Tooltip(
                        message: move.category,
                        child: MoveCategoryIcon(
                          category: move.category.toLowerCase(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Move name - emphasized and bold
                    Expanded(
                      child: Text(
                        move.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Divider between name and stats
              Divider(
                height: 1,
                color: dividerColor,
                thickness: 1,
                indent: 8,
                endIndent: 8,
              ),
              // Stats table: Power, Accuracy, PP
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Power column
                    Expanded(
                      flex: 5,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Power',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              move.power?.toString() ?? '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 45,
                      color: dividerColorLight,
                    ),
                    // Accuracy column
                    Expanded(
                      flex: 6,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Accuracy',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              move.accuracy?.toString() ?? '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 45,
                      color: dividerColorLight,
                    ),
                    // PP column
                    Expanded(
                      flex: 5,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'PP',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${move.pp} - ${(move.pp * 1.6).toStringAsFixed(0)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
