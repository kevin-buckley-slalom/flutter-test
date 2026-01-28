import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/team.dart';
import '../../../data/models/team_member.dart';
import '../../../data/models/pokemon.dart';
import '../../pokemon_list/pokemon_list_view_model.dart';
import '../../shared/flat_card.dart';
import '../../shared/pokemon_image.dart';
import '../../team_member_editor/team_member_editor_view.dart';

class TeamCard extends ConsumerStatefulWidget {
  final Team team;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(Team) onTeamUpdate;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  const TeamCard({
    super.key,
    required this.team,
    required this.onEdit,
    required this.onDelete,
    required this.onTeamUpdate,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  @override
  ConsumerState<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends ConsumerState<TeamCard> {
  bool _isExpanded = false;
  Map<String, Pokemon?> _pokemonCache = {};

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  @override
  void didUpdateWidget(TeamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team.members != widget.team.members) {
      _loadPokemon();
    }
  }

  Future<void> _loadPokemon() async {
    final repository = ref.read(pokemonRepositoryProvider);
    await repository.initialize();

    final Map<String, Pokemon?> cache = {};
    for (final member in widget.team.members) {
      if (member != null) {
        final pokemon = repository.byName(member.pokemonName);
        cache[member.pokemonName] = pokemon;
      }
    }

    if (mounted) {
      setState(() {
        _pokemonCache = cache;
      });
    }
  }

  void _handleTap() {
    if (widget.isSelectionMode) {
      widget.onSelectionToggle?.call();
    } else {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }
  }

  void _handlePokemonSlotTap(int index) async {
    if (widget.isSelectionMode) return;

    final existingMember = widget.team.members[index];
    final result = await Navigator.push<TeamMember>(
      context,
      MaterialPageRoute(
        builder: (context) => TeamMemberEditorView(
          team: widget.team,
          memberIndex: index,
          existingMember: existingMember,
        ),
      ),
    );

    if (result != null) {
      final updatedTeam = widget.team.updateMember(index, result);
      widget.onTeamUpdate(updatedTeam);
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text(
          'Are you sure you want to delete "${widget.team.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FlatCard(
      borderRadius: BorderRadius.circular(16),
      elevation: widget.isSelected ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      border: widget.isSelected
          ? Border.all(color: theme.colorScheme.primary, width: 2)
          : null,
      child: Column(
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with team name and edit button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.team.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!widget.isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: widget.onEdit,
                          tooltip: 'Edit team name',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (widget.isSelectionMode && widget.isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pokemon images row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      final member = widget.team.members[index];

                      if (member != null) {
                        final pokemon = _pokemonCache[member.pokemonName];

                        if (pokemon == null) {
                          return _buildPokemonSlot(
                            context,
                            index: index,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          );
                        }

                        return _buildPokemonSlot(
                          context,
                          index: index,
                          child: PokemonImage(
                            imagePath: member.isShiny
                                ? pokemon.imageShinyPath
                                : pokemon.imagePath,
                            imagePathLarge: member.isShiny
                                ? pokemon.imageShinyPathLarge
                                : pokemon.imagePathLarge,
                            size: 48,
                            useLarge: false,
                          ),
                        );
                      } else {
                        // Empty slot placeholder
                        return _buildPokemonSlot(
                          context,
                          index: index,
                          isEmpty: true,
                          child: Icon(
                            Icons.add,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            size: 24,
                          ),
                        );
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Expandable section with action buttons
          if (_isExpanded && !widget.isSelectionMode)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement export functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Export feature coming soon!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteConfirmation(context),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPokemonSlot(
    BuildContext context, {
    required int index,
    required Widget child,
    bool isEmpty = false,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _handlePokemonSlotTap(index),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEmpty
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty
                ? theme.colorScheme.outline.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
