import 'package:flutter/material.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/repositories/move_repository.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/ui/pokemon_detail/widgets/move_category_icon.dart';
import 'package:championdex/ui/battle_simulation/widgets/move_target_selector_dialog.dart';
import 'package:championdex/ui/shared/pokemon_image.dart';

class PokemonConfigBottomSheet extends StatefulWidget {
  final BattlePokemon pokemon;
  final List<BattlePokemon> benchPokemon;
  final List<BattlePokemon> fieldPokemon; // Pokemon currently on the field
  final List<BattlePokemon?> team1Pokemon; // Full team 1
  final List<BattlePokemon?> team2Pokemon; // Full team 2
  final List<String> availableMoves;
  final MoveRepository moveRepository;
  final Function(BattleAction?) onActionSet;
  final Function(int hp) onHpChanged;
  final Function(Map<String, int> statStages) onStatStagesChanged;
  final Function(BattlePokemon newPokemon)? onPokemonChanged;

  const PokemonConfigBottomSheet({
    super.key,
    required this.pokemon,
    required this.benchPokemon,
    required this.fieldPokemon,
    required this.team1Pokemon,
    required this.team2Pokemon,
    required this.availableMoves,
    required this.moveRepository,
    required this.onActionSet,
    required this.onHpChanged,
    required this.onStatStagesChanged,
    this.onPokemonChanged,
  });

  @override
  State<PokemonConfigBottomSheet> createState() =>
      _PokemonConfigBottomSheetState();
}

class _PokemonConfigBottomSheetState extends State<PokemonConfigBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentHp;
  late Map<String, int> _statStages;
  BattleAction? _selectedAction;
  String? _nonVolatileStatus;
  final Set<String> _volatileStatuses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentHp =
        widget.pokemon.currentHp.clamp(0, widget.pokemon.maxHp).toInt();
    _statStages = Map<String, int>.from(widget.pokemon.statStages);
    _selectedAction = widget.pokemon.queuedAction;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configure Pokémon',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(),
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Action'),
              Tab(text: 'HP & Stats'),
              Tab(text: 'Status\nConditions'),
              Tab(text: 'Select'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Action Tab
                _buildActionTab(),
                // HP & Stat Stages Tab
                _buildHpAndStatsTab(),
                // Combined Status Tab
                _buildCombinedStatusTab(),
                // Pokemon Selection Tab
                _buildPokemonSelectTab(),
              ],
            ),
          ),
          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                widget.onActionSet(_selectedAction);
                widget.onHpChanged(_currentHp);
                widget.onStatStagesChanged(_statStages);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
              child: Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  void _showReserveSelectionDialog(
    BuildContext context,
    String moveName,
    String? targetName,
    Move move,
  ) {
    // Get reserve pokemon - those not on field
    final fieldPokemonNames =
        widget.fieldPokemon.map((pokemon) => pokemon.pokemonName).toSet();
    final availableReserves = widget.benchPokemon
        .where((pokemon) => !fieldPokemonNames.contains(pokemon.pokemonName))
        .toList();

    if (availableReserves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No reserve Pokémon available to switch in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    BattlePokemon? selectedReserve;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select Pokémon to Switch In'),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (availableReserves.length * 72.0).clamp(0, 300),
              ),
              child: ListView.builder(
                itemCount: availableReserves.length,
                itemBuilder: (context, index) {
                  final reserve = availableReserves[index];
                  final isSelected =
                      selectedReserve?.pokemonName == reserve.pokemonName;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: PokemonImage(
                          imagePath: reserve.imagePath,
                          imagePathLarge: reserve.imagePathLarge,
                          size: 40,
                          useLarge: false,
                        ),
                      ),
                      title: Text(reserve.pokemonName),
                      subtitle: Text('Lv.${reserve.level}'),
                      trailing: isSelected ? Icon(Icons.check) : null,
                      onTap: () {
                        setDialogState(() {
                          selectedReserve = reserve;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Update state before closing dialog
                setState(() {
                  _selectedAction = null;
                });
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReserve != null
                  ? () {
                      final action = AttackAction(
                        moveName: moveName,
                        targetPokemonName: targetName,
                        switchInPokemonName: selectedReserve?.pokemonName,
                      );
                      // Update state before closing dialog
                      setState(() {
                        _selectedAction = action;
                      });
                      // Immediately notify parent so action is saved
                      widget.onActionSet(action);
                      Navigator.pop(dialogContext);
                    }
                  : null,
              child: Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHpAndStatsTab() {
    final stats = [
      ('ATK', 'atk'),
      ('DEF', 'def'),
      ('SPA', 'spa'),
      ('SPD', 'spd'),
      ('SPE', 'spe'),
      ('ACC', 'acc'),
      ('EVA', 'eva'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HP Section
          Text(
            'Current HP',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _currentHp.clamp(0, widget.pokemon.maxHp).toDouble(),
                  min: 0,
                  max: widget.pokemon.maxHp.toDouble(),
                  divisions: widget.pokemon.maxHp,
                  label: '${_currentHp.clamp(0, widget.pokemon.maxHp)}',
                  onChanged: (value) {
                    setState(() => _currentHp = value.toInt());
                  },
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${_currentHp.clamp(0, widget.pokemon.maxHp)} / ${widget.pokemon.maxHp}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    setState(() => _currentHp = widget.pokemon.maxHp),
                child: Text('Full'),
              ),
              OutlinedButton(
                onPressed: () => setState(
                    () => _currentHp = (widget.pokemon.maxHp * 0.5).toInt()),
                child: Text('50%'),
              ),
              OutlinedButton(
                onPressed: () => setState(
                    () => _currentHp = (widget.pokemon.maxHp * 0.25).toInt()),
                child: Text('25%'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _currentHp = 1),
                child: Text('1 HP'),
              ),
            ],
          ),
          SizedBox(height: 24),
          Divider(),
          SizedBox(height: 16),
          // Stat Stages Section
          Text(
            'Stat Stages (-6 to +6)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Text(
            'Modify battle stat modifiers',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          SizedBox(height: 16),
          // Two columns of stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column (first 4 stats)
              Expanded(
                child: Column(
                  children: stats.take(4).map((stat) {
                    return _buildStatStageControl(stat.$1, stat.$2);
                  }).toList(),
                ),
              ),
              SizedBox(width: 16),
              // Right column (last 4 stats)
              Expanded(
                child: Column(
                  children: stats.skip(4).map((stat) {
                    return _buildStatStageControl(stat.$1, stat.$2);
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatStageControl(String label, String key) {
    final value = _statStages[key] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: value > -6
                    ? () {
                        setState(() {
                          _statStages[key] = (value - 1).clamp(-6, 6);
                        });
                      }
                    : null,
                icon: Icon(Icons.remove_circle_outline),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: Text(
                  value > 0 ? '+$value' : '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: value > 0
                            ? Colors.green
                            : (value < 0 ? Colors.red : null),
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: value < 6
                    ? () {
                        setState(() {
                          _statStages[key] = (value + 1).clamp(-6, 6);
                        });
                      }
                    : null,
                icon: Icon(Icons.add_circle_outline),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Action:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 16),
          // Switch action
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch to:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // Filter out pokemon already on the field
                        final fieldPokemonNames = widget.fieldPokemon
                            .map((p) => p.pokemonName)
                            .toSet();
                        final availableForSwitch = widget.benchPokemon
                            .where((p) =>
                                !fieldPokemonNames.contains(p.pokemonName))
                            .toList();

                        if (availableForSwitch.isEmpty) {
                          return Text(
                            'No other Pokémon available',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          );
                        }

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableForSwitch.map((poke) {
                            final isSelected =
                                _selectedAction is SwitchAction &&
                                    (_selectedAction as SwitchAction)
                                            .targetPokemonName ==
                                        poke.pokemonName;

                            return InputChip(
                              avatar: SizedBox(
                                width: 32,
                                height: 32,
                                child: PokemonImage(
                                  imagePath: poke.imagePath,
                                  imagePathLarge: poke.imagePathLarge,
                                  size: 32,
                                  useLarge: false,
                                ),
                              ),
                              label:
                                  Text(poke.pokemonName.replaceAll('-', ' ')),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedAction = SwitchAction(
                                      targetPokemonName: poke.pokemonName,
                                    );
                                  } else {
                                    _selectedAction = null;
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Attack action
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Move:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: 8),
                    if (widget.availableMoves.isEmpty)
                      Text(
                        'No moves available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      )
                    else
                      ...widget.availableMoves.map((moveName) {
                        return FutureBuilder<Move?>(
                          future: widget.moveRepository.getMoveByName(moveName),
                          builder: (context, snapshot) {
                            final move = snapshot.data;
                            final isSelected = _selectedAction
                                    is AttackAction &&
                                (_selectedAction as AttackAction).moveName ==
                                    moveName;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: InkWell(
                                onTap: () {
                                  if (isSelected) {
                                    setState(() {
                                      _selectedAction = null;
                                    });
                                  } else if (move != null) {
                                    // Capture outer context for use in callbacks
                                    final outerContext = context;

                                    // Show target selection dialog
                                    final team1 = widget.team1Pokemon
                                        .whereType<BattlePokemon>()
                                        .toList();
                                    final team2 = widget.team2Pokemon
                                        .whereType<BattlePokemon>()
                                        .toList();

                                    showDialog(
                                      context: outerContext,
                                      builder: (dialogContext) =>
                                          MoveTargetSelectorDialog(
                                        move: move,
                                        userPokemon: widget.pokemon,
                                        team1Pokemon: team1,
                                        team2Pokemon: team2,
                                        onCancel: () {
                                          Navigator.pop(dialogContext);
                                          // Unselect the move if cancelled
                                          setState(() {
                                            _selectedAction = null;
                                          });
                                        },
                                        onConfirm: (targetName) {
                                          Navigator.pop(dialogContext);

                                          if (move.switchesOut == true) {
                                            // Schedule reserve dialog after this one closes
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              _showReserveSelectionDialog(
                                                outerContext,
                                                moveName,
                                                targetName,
                                                move,
                                              );
                                            });
                                          } else {
                                            final action = AttackAction(
                                              moveName: moveName,
                                              targetPokemonName: targetName,
                                            );
                                            setState(() {
                                              _selectedAction = action;
                                            });
                                            // Immediately notify parent so action is saved
                                            widget.onActionSet(action);
                                          }
                                        },
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context).dividerColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withOpacity(0.3)
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Category icon
                                      if (move != null)
                                        SizedBox(
                                          width: 50,
                                          height: 40,
                                          child: MoveCategoryIcon(
                                            category: move.category,
                                          ),
                                        ),
                                      if (move != null) SizedBox(width: 12),
                                      // Move name
                                      Expanded(
                                        child: Text(
                                          moveName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                      // Move stats
                                      if (move != null)
                                        _buildMoveStatChip(
                                          context,
                                          'BP',
                                          move.power?.toString() ?? '—',
                                        ),
                                      if (move != null) SizedBox(width: 8),
                                      if (move != null)
                                        _buildMoveStatChip(
                                          context,
                                          'ACC',
                                          move.accuracy?.toString() ?? '—',
                                        ),
                                      if (move != null) SizedBox(width: 8),
                                      if (move != null)
                                        _buildMoveStatChip(
                                          context,
                                          'PP',
                                          move.maxPp?.toString() ??
                                              move.pp.toString(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          ),
          // Selected action summary
          if (_selectedAction != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Action:',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      SizedBox(height: 8),
                      if (_selectedAction is SwitchAction)
                        Text(
                          'Switch to ${(_selectedAction as SwitchAction).targetPokemonName.replaceAll('-', ' ')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_selectedAction is AttackAction) ...[
                        Text(
                          'Use ${(_selectedAction as AttackAction).moveName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if ((_selectedAction as AttackAction)
                                .targetPokemonName !=
                            null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: _buildTargetDescription(
                              ((_selectedAction as AttackAction)
                                      .targetPokemonName ??
                                  ''),
                              context,
                            ),
                          ),
                        if ((_selectedAction as AttackAction)
                                .switchInPokemonName !=
                            null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Switch in ${(_selectedAction as AttackAction).switchInPokemonName?.replaceAll('-', ' ')}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.green,
                                  ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetDescription(String target, BuildContext context) {
    String getTargetLabel() {
      switch (target) {
        case 'all-team':
          return 'Target: Entire Team';
        case 'all-except-user':
          return 'Target: All Except User';
        case 'all-opposing':
          return 'Target: All Opponents';
        case 'all-field':
          return 'Target: All Pokemon';
        default:
          return 'Target: ${target.replaceAll('-', ' ')}';
      }
    }

    return Text(
      getTargetLabel(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.blue,
          ),
    );
  }

  Widget _buildMoveStatChip(BuildContext context, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedStatusTab() {
    final nonVolatileStatusOptions = [
      'Burn',
      'Freeze',
      'Paralysis',
      'Poison',
      'Toxic Poison',
      'Sleep',
    ];
    final volatileStatusOptions = [
      'Confusion',
      'Infatuation',
      'Ability Suppression',
      'Substitute',
      'Bound',
      'Curse',
      'Nightmare',
      'Perish Song',
      'Leech Seed',
      'Salt Cure',
      'Foresight',
      'Miracle Eye',
      'Minimize',
      'Tar Shot',
      'Grounded',
      'Telekinesis',
      'Aqua Ring',
      'Rooted',
      'Protect',
      'Helping Hand',
      'Power Trick',
      'Imprison',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Non-Volatile Status Section
          Text(
            'Status Conditions:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 8),
          Text(
            'Only one at a time. Persists when switching.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...nonVolatileStatusOptions.map((status) {
                final isSelected = _nonVolatileStatus == status;
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _nonVolatileStatus = status;
                      } else {
                        _nonVolatileStatus = null;
                      }
                    });
                  },
                );
              }),
            ],
          ),
          if (_nonVolatileStatus != null) ...[
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _nonVolatileStatus = null);
              },
              icon: Icon(Icons.clear),
              label: Text('Clear Status'),
            ),
          ],
          SizedBox(height: 24),
          Divider(),
          SizedBox(height: 16),
          // Volatile Status Section
          Text(
            'Effected By:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 8),
          Text(
            'Multiple possible. Removed when switching out.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...volatileStatusOptions.map((status) {
                final isSelected = _volatileStatuses.contains(status);
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _volatileStatuses.add(status);
                      } else {
                        _volatileStatuses.remove(status);
                      }
                    });
                  },
                );
              }),
            ],
          ),
          if (_volatileStatuses.isNotEmpty) ...[
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _volatileStatuses.clear());
              },
              icon: Icon(Icons.clear),
              label: Text('Clear All'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPokemonSelectTab() {
    // Get reserve pokemon from the bench for this team (exclude any on-field)
    final fieldPokemonNames =
        widget.fieldPokemon.map((pokemon) => pokemon.pokemonName).toSet();
    final reservePokemon = widget.benchPokemon
        .where((pokemon) => !fieldPokemonNames.contains(pokemon.pokemonName))
        .toList();
    final uniqueReservePokemon = <String, BattlePokemon>{
      for (final pokemon in reservePokemon) pokemon.pokemonName: pokemon,
    }.values.toList();

    if (uniqueReservePokemon.isEmpty) {
      return const Center(
        child: Text('No reserve pokemon available'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: uniqueReservePokemon.length,
      itemBuilder: (context, index) {
        final reserveMember = uniqueReservePokemon[index];

        return ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: PokemonImage(
              imagePath: reserveMember.imagePath,
              imagePathLarge: reserveMember.imagePathLarge,
              size: 48,
              useLarge: false,
            ),
          ),
          title: Text(reserveMember.pokemonName),
          subtitle: Text(
            'Reserve',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () {
            // Reset state for new pokemon
            setState(() {
              _currentHp =
                  reserveMember.currentHp.clamp(0, reserveMember.maxHp).toInt();
              _statStages = {
                'attack': 0,
                'defense': 0,
                'sp-attack': 0,
                'sp-defense': 0,
                'speed': 0,
                'accuracy': 0,
                'evasion': 0,
              };
              _selectedAction = null;
              _nonVolatileStatus = null;
              _volatileStatuses.clear();
            });

            // Notify parent of pokemon swap
            widget.onPokemonChanged?.call(reserveMember);

            // Close the bottom sheet and return the new pokemon
            Navigator.of(context).pop(reserveMember);
          },
        );
      },
    );
  }
}

/// Show the Pokémon configuration bottom sheet
Future<BattlePokemon?> showPokemonConfigBottomSheet(
  BuildContext context, {
  required BattlePokemon pokemon,
  required List<BattlePokemon> benchPokemon,
  required List<BattlePokemon> fieldPokemon,
  required List<BattlePokemon?> team1Pokemon,
  required List<BattlePokemon?> team2Pokemon,
  required List<String> availableMoves,
  required MoveRepository moveRepository,
  required Function(BattleAction?) onActionSet,
  required Function(int hp) onHpChanged,
  required Function(Map<String, int> statStages) onStatStagesChanged,
  Function(BattlePokemon newPokemon)? onPokemonChanged,
}) {
  return showModalBottomSheet<BattlePokemon?>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: PokemonConfigBottomSheet(
        pokemon: pokemon,
        benchPokemon: benchPokemon,
        fieldPokemon: fieldPokemon,
        team1Pokemon: team1Pokemon,
        team2Pokemon: team2Pokemon,
        availableMoves: availableMoves,
        moveRepository: moveRepository,
        onActionSet: onActionSet,
        onHpChanged: onHpChanged,
        onStatStagesChanged: onStatStagesChanged,
        onPokemonChanged: onPokemonChanged,
      ),
    ),
  );
}
