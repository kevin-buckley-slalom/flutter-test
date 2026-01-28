import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/team.dart';
import '../../data/repositories/team_repository.dart';

// State class for managing teams list and battle selection
class TeamsListState {
  final List<Team> teams;
  final bool isLoading;
  final String? error;
  final bool isBattleSelectionMode;
  final Set<String> selectedTeamIds;

  TeamsListState({
    this.teams = const [],
    this.isLoading = false,
    this.error,
    this.isBattleSelectionMode = false,
    this.selectedTeamIds = const {},
  });

  TeamsListState copyWith({
    List<Team>? teams,
    bool? isLoading,
    String? error,
    bool? isBattleSelectionMode,
    Set<String>? selectedTeamIds,
  }) {
    return TeamsListState(
      teams: teams ?? this.teams,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isBattleSelectionMode:
          isBattleSelectionMode ?? this.isBattleSelectionMode,
      selectedTeamIds: selectedTeamIds ?? this.selectedTeamIds,
    );
  }
}

// Notifier for managing teams list logic
class TeamsListNotifier extends Notifier<TeamsListState> {
  late final TeamRepository _repository;

  @override
  TeamsListState build() {
    _repository = ref.watch(teamRepositoryProvider);
    // Schedule the async load after build
    Future.microtask(() => loadTeams());
    return TeamsListState(isLoading: true);
  }

  Future<void> loadTeams() async {
    try {
      await _repository.initialize();
      final teams = await _repository.getAll();
      state = state.copyWith(teams: teams, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load teams: $e',
        isLoading: false,
      );
    }
  }

  Future<void> createTeam() async {
    try {
      // Generate default name based on team count
      final teamNumber = state.teams.length + 1;
      final newTeam = await _repository.create('Team $teamNumber');
      final updatedTeams = [...state.teams, newTeam];
      state = state.copyWith(teams: updatedTeams);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create team: $e');
    }
  }

  Future<void> updateTeamName(String teamId, String newName) async {
    try {
      final team = state.teams.firstWhere((t) => t.id == teamId);
      final updatedTeam = team.copyWith(name: newName);
      await _repository.update(updatedTeam);

      final updatedTeams =
          state.teams.map((t) => t.id == teamId ? updatedTeam : t).toList();
      state = state.copyWith(teams: updatedTeams);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update team name: $e');
    }
  }

  Future<void> updateTeam(Team updatedTeam) async {
    try {
      await _repository.update(updatedTeam);

      final updatedTeams = state.teams
          .map((t) => t.id == updatedTeam.id ? updatedTeam : t)
          .toList();
      state = state.copyWith(teams: updatedTeams);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update team: $e');
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      await _repository.delete(teamId);
      final updatedTeams = state.teams.where((t) => t.id != teamId).toList();

      // Remove from selected teams if in battle mode
      final updatedSelectedIds = Set<String>.from(state.selectedTeamIds)
        ..remove(teamId);

      state = state.copyWith(
        teams: updatedTeams,
        selectedTeamIds: updatedSelectedIds,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete team: $e');
    }
  }

  void toggleBattleSelectionMode() {
    state = state.copyWith(
      isBattleSelectionMode: !state.isBattleSelectionMode,
      selectedTeamIds: {}, // Clear selections when toggling mode
    );
  }

  void toggleTeamSelection(String teamId) {
    final selectedIds = Set<String>.from(state.selectedTeamIds);

    if (selectedIds.contains(teamId)) {
      selectedIds.remove(teamId);
    } else if (selectedIds.length < 2) {
      // Only allow selecting up to 2 teams
      selectedIds.add(teamId);
    }

    state = state.copyWith(selectedTeamIds: selectedIds);
  }

  void clearBattleSelection() {
    state = state.copyWith(
      isBattleSelectionMode: false,
      selectedTeamIds: {},
    );
  }
}

// Provider for the teams list notifier
final teamsListProvider =
    NotifierProvider<TeamsListNotifier, TeamsListState>(() {
  return TeamsListNotifier();
});

// Provider for team repository (to be overridden in main.dart)
final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  throw UnimplementedError('teamRepositoryProvider must be overridden');
});
