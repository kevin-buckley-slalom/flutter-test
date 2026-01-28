import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'teams_list_view_model.dart';
import 'widgets/team_card.dart';

class TeamsListWidget extends ConsumerWidget {
  const TeamsListWidget({super.key});

  void _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Team Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Team Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref
                  .read(teamsListProvider.notifier)
                  .updateTeamName(teamId, value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref
                    .read(teamsListProvider.notifier)
                    .updateTeamName(teamId, newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBattleConfirmation(
    BuildContext context,
    WidgetRef ref,
    List<String> selectedTeamIds,
  ) {
    final state = ref.read(teamsListProvider);
    final team1 = state.teams.firstWhere((t) => t.id == selectedTeamIds[0]);
    final team2 = state.teams.firstWhere((t) => t.id == selectedTeamIds[1]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Battle Simulation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ready to simulate a battle between:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.catching_pokemon,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  team1.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    indent: 16,
                    endIndent: 8,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                const Text('vs:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Divider(
                    indent: 8,
                    endIndent: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.catching_pokemon,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  team2.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Battle simulation feature coming soon!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(teamsListProvider.notifier).clearBattleSelection();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(teamsListProvider.notifier).clearBattleSelection();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(teamsListProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading teams',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(teamsListProvider.notifier).loadTeams();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final hasTeams = state.teams.isNotEmpty;
    final canStartBattle = state.teams.length >= 2;

    return Column(
      children: [
        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(teamsListProvider.notifier).createTeam();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Team'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canStartBattle
                      ? () {
                          final notifier = ref.read(teamsListProvider.notifier);
                          if (state.isBattleSelectionMode) {
                            // If already in selection mode, cancel it
                            notifier.clearBattleSelection();
                          } else {
                            // Enter selection mode
                            notifier.toggleBattleSelectionMode();
                          }
                        }
                      : null,
                  icon: Icon(
                    state.isBattleSelectionMode ? Icons.close : Icons.flash_on,
                  ),
                  label: Text(
                    state.isBattleSelectionMode ? 'Cancel' : 'Battle Sim',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isBattleSelectionMode
                        ? theme.colorScheme.errorContainer
                        : null,
                    foregroundColor: state.isBattleSelectionMode
                        ? theme.colorScheme.onErrorContainer
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Battle selection hint
        if (state.isBattleSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.selectedTeamIds.length == 2
                        ? 'Teams selected! Click a team again to continue.'
                        : 'Select ${2 - state.selectedTeamIds.length} more team${state.selectedTeamIds.length == 1 ? '' : 's'} for battle',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (state.selectedTeamIds.length == 2)
                  ElevatedButton(
                    onPressed: () {
                      _showBattleConfirmation(
                        context,
                        ref,
                        state.selectedTeamIds.toList(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: const Text('Start'),
                  ),
              ],
            ),
          ),

        // Teams list or empty state
        Expanded(
          child: hasTeams
              ? ListView.builder(
                  itemCount: state.teams.length,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemBuilder: (context, index) {
                    final team = state.teams[index];
                    final isSelected = state.selectedTeamIds.contains(team.id);

                    return TeamCard(
                      team: team,
                      isSelectionMode: state.isBattleSelectionMode,
                      isSelected: isSelected,
                      onSelectionToggle: () {
                        ref
                            .read(teamsListProvider.notifier)
                            .toggleTeamSelection(team.id);

                        // If two teams are selected, show confirmation after a brief delay
                        final updatedState = ref.read(teamsListProvider);
                        if (updatedState.selectedTeamIds.length == 2) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (context.mounted &&
                                ref
                                        .read(teamsListProvider)
                                        .selectedTeamIds
                                        .length ==
                                    2) {
                              _showBattleConfirmation(
                                context,
                                ref,
                                ref
                                    .read(teamsListProvider)
                                    .selectedTeamIds
                                    .toList(),
                              );
                            }
                          });
                        }
                      },
                      onEdit: () {
                        _showEditNameDialog(
                          context,
                          ref,
                          team.id,
                          team.name,
                        );
                      },
                      onDelete: () {
                        ref
                            .read(teamsListProvider.notifier)
                            .deleteTeam(team.id);
                      },
                      onTeamUpdate: (updatedTeam) {
                        ref
                            .read(teamsListProvider.notifier)
                            .updateTeam(updatedTeam);
                      },
                    );
                  },
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 80,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Teams Yet',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create your first team to get started!\nTeams can have up to 6 Pokémon.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(teamsListProvider.notifier).createTeam();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Your First Team'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
