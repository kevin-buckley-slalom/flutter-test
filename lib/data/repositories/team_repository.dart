import '../models/team.dart';
import '../services/team_storage_service.dart';

class TeamRepository {
  final TeamStorageService _storageService;
  List<Team>? _teams;

  TeamRepository(this._storageService);

  Future<void> initialize() async {
    if (_teams != null) return;
    _teams = await _storageService.loadTeams();
  }

  Future<List<Team>> getAll() async {
    await initialize();
    return List.unmodifiable(_teams!);
  }

  Future<Team?> getById(String id) async {
    await initialize();
    try {
      return _teams!.firstWhere((team) => team.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Team> create(String name) async {
    await initialize();

    // Generate a unique ID using timestamp
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final team = Team(
      id: id,
      name: name,
      members: List.filled(6, null), // 6 empty slots
    );

    _teams!.add(team);
    await _storageService.saveTeams(_teams!);
    return team;
  }

  Future<void> update(Team team) async {
    await initialize();

    final index = _teams!.indexWhere((t) => t.id == team.id);
    if (index != -1) {
      _teams![index] = team;
      await _storageService.saveTeams(_teams!);
    }
  }

  Future<void> delete(String id) async {
    await initialize();

    _teams!.removeWhere((team) => team.id == id);
    await _storageService.saveTeams(_teams!);
  }

  Future<void> deleteAll() async {
    await initialize();

    _teams!.clear();
    await _storageService.clearTeams();
  }
}
