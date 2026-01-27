import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ability.dart';
import 'abilities_list_view_model.dart';

class AbilitiesListWidget extends ConsumerStatefulWidget {
  const AbilitiesListWidget({super.key});

  @override
  ConsumerState<AbilitiesListWidget> createState() =>
      _AbilitiesListWidgetState();
}

class _AbilitiesListWidgetState extends ConsumerState<AbilitiesListWidget> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _sortField = 'name'; // 'name', 'pokemon_count'
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

  bool _matchesSearch(Ability ability, String query) {
    if (query.isEmpty) return true;

    // Check name
    if (ability.name.toLowerCase().contains(query)) {
      return true;
    }

    // Check effect
    if (ability.effect.toLowerCase().contains(query)) {
      return true;
    }

    return false;
  }

  List<Ability> _sortList(List<Ability> list) {
    final sortedList = List<Ability>.from(list);

    sortedList.sort((a, b) {
      int comparison = 0;

      switch (_sortField) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'pokemon_count':
          final aCount = a.regularPokemon.length + a.hiddenPokemon.length;
          final bCount = b.regularPokemon.length + b.hiddenPokemon.length;
          comparison = aCount.compareTo(bCount);
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
                      ('pokemon_count', 'Pokémon Count'),
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
    final abilitiesAsync = ref.watch(abilitiesListViewModelProvider);
    final theme = Theme.of(context);

    return abilitiesAsync.when(
      data: (abilitiesList) {
        // Filter the list based on search query
        final filteredList = _searchQuery.isEmpty
            ? abilitiesList
            : abilitiesList
                .where((ability) => _matchesSearch(ability, _searchQuery))
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
                          hintText: 'Search by name or effect...',
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
                              ? 'No abilities found'
                              : 'No abilities match "$_searchQuery"',
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
                          final ability = sortedList[index];
                          return _AbilityListItem(ability: ability);
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
                'Error loading abilities data',
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

class _AbilityListItem extends StatelessWidget {
  final Ability ability;

  const _AbilityListItem({required this.ability});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pokemonCount =
        ability.regularPokemon.length + ability.hiddenPokemon.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/ability-detail',
            arguments: ability.name,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ability name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ability.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Pokemon count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pokemonCount Pokémon',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Effect description
              Text(
                ability.effect,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
