import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pokemon.dart';
import '../../data/models/team.dart';
import '../../data/models/team_member.dart';
import '../../data/models/move.dart';
import '../../data/models/nature.dart';
import '../../data/services/nature_data_service.dart';
import '../../domain/services/stat_calculator.dart';
import '../../app/theme/type_colors.dart';
import '../shared/flat_card.dart';
import '../shared/pokemon_image.dart';
import '../pokemon_detail/widgets/stat_bar_chart.dart';
import '../pokemon_list/pokemon_list_view_model.dart';
import '../moves_list/moves_list_view_model.dart';
import '../pokemon_detail/widgets/move_category_icon.dart';
import 'widgets/pokemon_selector_sheet.dart';
import 'widgets/iv_ev_editor.dart';
import 'widgets/moves_selector_sheet.dart';

class TeamMemberEditorView extends ConsumerStatefulWidget {
  final Team team;
  final int memberIndex; // 0-5
  final TeamMember? existingMember;

  const TeamMemberEditorView({
    super.key,
    required this.team,
    required this.memberIndex,
    this.existingMember,
  });

  @override
  ConsumerState<TeamMemberEditorView> createState() =>
      _TeamMemberEditorViewState();
}

class _TeamMemberEditorViewState extends ConsumerState<TeamMemberEditorView> {
  Pokemon? _selectedPokemon;
  late int _level;
  String? _gender;
  late String _teraType;
  late String _ability;
  String? _item;
  late bool _isShiny;

  // IVs
  late int _ivHp, _ivAttack, _ivDefense, _ivSpAtk, _ivSpDef, _ivSpeed;

  // EVs
  late int _evHp, _evAttack, _evDefense, _evSpAtk, _evSpDef, _evSpeed;

  String? _nature;
  late List<String> _moves; // Up to 4 moves
  List<Move?> _moveObjects = []; // Loaded Move objects for display
  List<Nature> _availableNatures = [];
  final NatureDataService _natureService = NatureDataService();
  bool _hasUnsavedChanges = false;
  bool _isLoading = false;

  final List<String> _allTypes = [
    'Normal',
    'Fire',
    'Water',
    'Electric',
    'Grass',
    'Ice',
    'Fighting',
    'Poison',
    'Ground',
    'Flying',
    'Psychic',
    'Bug',
    'Rock',
    'Ghost',
    'Dragon',
    'Dark',
    'Steel',
    'Fairy'
  ];

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() async {
    // Load natures
    _availableNatures = await _natureService.loadNatures();

    if (widget.existingMember != null) {
      setState(() {
        _isLoading = true;
      });

      // Load existing member data
      final member = widget.existingMember!;
      _level = member.level;
      _gender = member.gender;
      _teraType = member.teraType;
      _ability = member.ability;
      _item = member.item;
      _isShiny = member.isShiny;
      _ivHp = member.ivHp;
      _ivAttack = member.ivAttack;
      _ivDefense = member.ivDefense;
      _ivSpAtk = member.ivSpAtk;
      _ivSpDef = member.ivSpDef;
      _ivSpeed = member.ivSpeed;
      _evHp = member.evHp;
      _evAttack = member.evAttack;
      _evDefense = member.evDefense;
      _evSpAtk = member.evSpAtk;
      _evSpDef = member.evSpDef;
      _evSpeed = member.evSpeed;
      _nature = member.nature;
      _moves = List<String>.from(member.moves);

      // Load move objects
      await _loadMoveObjects();

      // Load the Pokemon from repository
      final repository = ref.read(pokemonRepositoryProvider);
      await repository.initialize();
      final pokemon = repository.byName(member.pokemonName);
      if (pokemon != null) {
        setState(() {
          _selectedPokemon = pokemon;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Default values for new member
      _level = 50;
      _gender = null;
      _teraType = 'Normal';
      _ability = '';
      _item = null;
      _isShiny = false;
      _ivHp = _ivAttack = _ivDefense = _ivSpAtk = _ivSpDef = _ivSpeed = 31;
      _evHp = _evAttack = _evDefense = _evSpAtk = _evSpDef = _evSpeed = 0;
      _nature = null;
      _moves = [];
    }
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _loadMoveObjects() async {
    final movesData = await ref.read(movesListViewModelProvider.future);
    final moveMap = {for (var move in movesData) move.name: move};

    setState(() {
      _moveObjects = _moves.map((moveName) => moveMap[moveName]).toList();
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showPokemonSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PokemonSelectorSheet(
        onPokemonSelected: (pokemon) {
          setState(() {
            _selectedPokemon = pokemon;
            _teraType = pokemon.types.first;
            _ability = pokemon.regularAbilities.isNotEmpty
                ? pokemon.regularAbilities.first
                : '';
            _gender = _determineGender(pokemon.genderRatio);
            _markChanged();
          });
        },
      ),
    );
  }

  String? _determineGender(Map<String, dynamic>? genderRatio) {
    if (genderRatio == null || genderRatio.isEmpty) return 'none';
    final male = genderRatio['male'];
    final female = genderRatio['female'];
    if (male == 100) return 'male';
    if (female == 100) return 'female';
    // Return first available gender (male takes precedence if both exist)
    if (male != null && male > 0) return 'male';
    if (female != null && female > 0) return 'female';
    return 'none';
  }

  void _save() {
    if (_selectedPokemon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Pokémon')),
      );
      return;
    }

    final member = TeamMember(
      pokemonName: _selectedPokemon!.name,
      level: _level,
      gender: _gender,
      teraType: _teraType,
      ability: _ability,
      item: _item,
      isShiny: _isShiny,
      ivHp: _ivHp,
      ivAttack: _ivAttack,
      ivDefense: _ivDefense,
      ivSpAtk: _ivSpAtk,
      ivSpDef: _ivSpDef,
      ivSpeed: _ivSpeed,
      evHp: _evHp,
      evAttack: _evAttack,
      evDefense: _evDefense,
      evSpAtk: _evSpAtk,
      evSpDef: _evSpDef,
      evSpeed: _evSpeed,
      nature: _nature,
      moves: _moves,
    );

    Navigator.pop(context, member);
  }

  int get _totalEvs =>
      _evHp + _evAttack + _evDefense + _evSpAtk + _evSpDef + _evSpeed;

  int _calculateStat(int baseStat, int iv, int ev, String statName) {
    // Get the nature object
    Nature? natureObj;
    if (_nature != null) {
      natureObj = _natureService.getNatureByName(_nature);
    }

    return StatCalculator.calculateStat(
      baseStat: baseStat,
      iv: iv,
      ev: ev,
      level: _level,
      statName: statName,
      nature: natureObj,
    );
  }

  int _calculateTotalStats() {
    int hp = _calculateStat(_selectedPokemon!.stats.hp, _ivHp, _evHp, 'hp');
    int attack = _calculateStat(
        _selectedPokemon!.stats.attack, _ivAttack, _evAttack, 'attack');
    int defense = _calculateStat(
        _selectedPokemon!.stats.defense, _ivDefense, _evDefense, 'defense');
    int spAtk = _calculateStat(
        _selectedPokemon!.stats.spAtk, _ivSpAtk, _evSpAtk, 'sp_atk');
    int spDef = _calculateStat(
        _selectedPokemon!.stats.spDef, _ivSpDef, _evSpDef, 'sp_def');
    int speed = _calculateStat(
        _selectedPokemon!.stats.speed, _ivSpeed, _evSpeed, 'speed');

    return hp + attack + defense + spAtk + spDef + speed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingMember != null
                ? 'Edit Team Member'
                : 'Add Team Member',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: 'Save',
            ),
          ],
        ),
        body: _isLoading
            ? _buildLoadingState(theme)
            : _selectedPokemon == null
                ? _buildEmptyState(theme)
                : _buildEditorContent(theme),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Pokémon...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.catching_pokemon,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a Pokémon',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to choose a Pokémon for your team',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showPokemonSelector,
              icon: const Icon(Icons.add),
              label: const Text('Select Pokémon'),
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
    );
  }

  Widget _buildEditorContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPokemonHeader(theme),
          const SizedBox(height: 16),
          _buildBasicInfoAndAbility(theme),
          const SizedBox(height: 16),
          _buildMovesSection(theme),
          const SizedBox(height: 24),
          _buildBaseStats(theme),
          const SizedBox(height: 16),
          _buildIvEvEditor(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPokemonHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pokemon image button
        GestureDetector(
          onTap: _showPokemonSelector,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: PokemonImage(
              imagePath: _isShiny
                  ? _selectedPokemon!.imageShinyPath
                  : _selectedPokemon!.imagePath,
              imagePathLarge: _isShiny
                  ? _selectedPokemon!.imageShinyPathLarge
                  : _selectedPokemon!.imagePathLarge,
              size: 100,
              useLarge: false,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Pokemon info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPokemon!.baseName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedPokemon!.variant != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _selectedPokemon!.variant!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Shiny toggle button
                  IconButton(
                    icon: Icon(
                      _isShiny ? Icons.star : Icons.star_border,
                      color: _isShiny
                          ? Colors.amber
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _isShiny = !_isShiny;
                        _markChanged();
                      });
                    },
                    tooltip: _isShiny ? 'Shiny' : 'Not Shiny',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Type chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedPokemon!.types.map((type) {
                  final typeColor = TypeColors.getColor(type);
                  final textColor = TypeColors.getTextColor(type);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Height & Weight
              if (_selectedPokemon!.heightImperial != null &&
                  _selectedPokemon!.weightImperial != null)
                Text(
                  '${_selectedPokemon!.heightImperial} • ${_selectedPokemon!.weightImperial} (${_selectedPokemon!.heightMetric} • ${_selectedPokemon!.weightMetric})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoAndAbility(ThemeData theme) {
    final abilities = [
      ..._selectedPokemon!.regularAbilities,
      ..._selectedPokemon!.hiddenAbilities,
    ];

    return FlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: Level, Gender, Tera Type
          Row(
            children: [
              // Level
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller:
                          TextEditingController(text: _level.toString()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '50',
                      ),
                      onChanged: (value) {
                        final intValue = int.tryParse(value);
                        if (intValue != null) {
                          setState(() {
                            _level = intValue.clamp(1, 100);
                            _markChanged();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Gender
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gender',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _buildGenderItems(),
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() {
                          _gender = value;
                          _markChanged();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Tera Type
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tera Type',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _teraType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _allTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(type),
                                ),
                              ))
                          .toList(),
                      isExpanded: true,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _teraType = value;
                            _markChanged();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: Ability, Item
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ability',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _ability.isEmpty ? null : _ability,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: abilities
                          .map((ability) => DropdownMenuItem(
                                value: ability,
                                child: Text(ability),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _ability = value;
                            _markChanged();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Item selection coming soon!'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(_item ?? 'Select Item'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildGenderItems() {
    final genderRatio = _selectedPokemon?.genderRatio;
    if (genderRatio == null || genderRatio.isEmpty) {
      return [
        const DropdownMenuItem(
          value: 'none',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Genderless'),
          ),
        ),
      ];
    }

    final male = genderRatio['male'];
    final female = genderRatio['female'];

    final items = <DropdownMenuItem<String>>[];
    if (male != null && male > 0) {
      items.add(
        const DropdownMenuItem(
          value: 'male',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('♂ Male'),
          ),
        ),
      );
    }
    if (female != null && female > 0) {
      items.add(
        const DropdownMenuItem(
          value: 'female',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('♀ Female'),
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildMovesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Moves',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(4, (index) {
            final moveSlot = _moves.length > index ? _moves[index] : null;
            return Padding(
              padding: EdgeInsets.only(bottom: index < 3 ? 12 : 0),
              child: _buildMoveSlot(theme, index, moveSlot),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMoveSlot(ThemeData theme, int slotIndex, String? moveName) {
    final move =
        _moveObjects.length > slotIndex ? _moveObjects[slotIndex] : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showMovesSelector(slotIndex);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: moveName != null
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: moveName != null && move != null
              ? Stack(
                  alignment: AlignmentGeometry.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          // Category icon
                          SizedBox(
                            width: 40,
                            height: 30,
                            child: MoveCategoryIcon(
                              category: move.category.toLowerCase(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Move name
                          Expanded(
                            flex: 3,
                            child: Text(
                              move.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Stats
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMoveStatColumn(
                                  theme,
                                  'BP',
                                  move.power?.toString() ?? '—',
                                ),
                                _buildMoveStatColumn(
                                  theme,
                                  'Acc',
                                  move.accuracy?.toString() ?? '—',
                                ),
                                _buildMoveStatColumn(
                                  theme,
                                  'PP',
                                  move.maxPp.toString(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                        ],
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.clear),
                        iconSize: 18,
                        onPressed: () async {
                          setState(() {
                            _moves.removeAt(slotIndex);
                            _markChanged();
                          });
                          await _loadMoveObjects();
                        },
                        tooltip: 'Remove move',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add,
                        size: 24,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add Move',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMoveStatColumn(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showMovesSelector(int slotIndex) async {
    if (_selectedPokemon == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovesSelectorSheet(
        pokemon: _selectedPokemon!,
        onMoveSelected: (moveName) async {
          setState(() {
            // Ensure the moves list is large enough
            while (_moves.length <= slotIndex) {
              _moves.add('');
            }
            _moves[slotIndex] = moveName;
            _markChanged();
          });
          await _loadMoveObjects();
        },
      ),
    );
  }

  Widget _buildBaseStats(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calculated Stats',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        FlatCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              StatBarChart(
                statName: 'hp',
                value: _calculateStat(
                    _selectedPokemon!.stats.hp, _ivHp, _evHp, 'hp'),
              ),
              StatBarChart(
                statName: 'attack',
                value: _calculateStat(_selectedPokemon!.stats.attack, _ivAttack,
                    _evAttack, 'attack'),
              ),
              StatBarChart(
                statName: 'defense',
                value: _calculateStat(_selectedPokemon!.stats.defense,
                    _ivDefense, _evDefense, 'defense'),
              ),
              StatBarChart(
                statName: 'sp_atk',
                value: _calculateStat(_selectedPokemon!.stats.spAtk, _ivSpAtk,
                    _evSpAtk, 'sp_atk'),
              ),
              StatBarChart(
                statName: 'sp_def',
                value: _calculateStat(_selectedPokemon!.stats.spDef, _ivSpDef,
                    _evSpDef, 'sp_def'),
              ),
              StatBarChart(
                statName: 'speed',
                value: _calculateStat(
                    _selectedPokemon!.stats.speed, _ivSpeed, _evSpeed, 'speed'),
              ),
              StatBarChart(
                statName: 'Total',
                value: _calculateTotalStats(),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIvEvEditor(ThemeData theme) {
    final currentNature =
        _nature != null ? _natureService.getNatureByName(_nature) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'IVs & EVs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'EVs: $_totalEvs / 510',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _totalEvs > 510
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FlatCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Nature selector
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Nature',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _nature,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Select Nature',
                      ),
                      items: _availableNatures
                          .map((nature) => DropdownMenuItem(
                                value: nature.name,
                                child: Text(nature.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _nature = value;
                          _markChanged();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              IvEvEditor(
                statName: 'HP',
                ivValue: _ivHp,
                evValue: _evHp,
                baseStatValue: _selectedPokemon!.stats.hp,
                level: _level,
                totalEvs: _totalEvs,
                natureMultiplier:
                    currentNature?.getMultiplierForStat('hp') ?? 1.0,
                onChanged: (iv, ev) {
                  setState(() {
                    _ivHp = iv;
                    _evHp = ev;
                    _markChanged();
                  });
                },
              ),
              IvEvEditor(
                statName: 'ATK',
                ivValue: _ivAttack,
                evValue: _evAttack,
                baseStatValue: _selectedPokemon!.stats.attack,
                level: _level,
                totalEvs: _totalEvs,
                natureMultiplier:
                    currentNature?.getMultiplierForStat('attack') ?? 1.0,
                onChanged: (iv, ev) {
                  setState(() {
                    _ivAttack = iv;
                    _evAttack = ev;
                    _markChanged();
                  });
                },
              ),
              IvEvEditor(
                statName: 'DEF',
                ivValue: _ivDefense,
                evValue: _evDefense,
                baseStatValue: _selectedPokemon!.stats.defense,
                level: _level,
                totalEvs: _totalEvs,
                natureMultiplier:
                    currentNature?.getMultiplierForStat('defense') ?? 1.0,
                onChanged: (iv, ev) {
                  setState(() {
                    _ivDefense = iv;
                    _evDefense = ev;
                    _markChanged();
                  });
                },
              ),
              IvEvEditor(
                statName: 'SPA',
                ivValue: _ivSpAtk,
                evValue: _evSpAtk,
                baseStatValue: _selectedPokemon!.stats.spAtk,
                level: _level,
                totalEvs: _totalEvs,
                natureMultiplier:
                    currentNature?.getMultiplierForStat('sp_atk') ?? 1.0,
                onChanged: (iv, ev) {
                  setState(() {
                    _ivSpAtk = iv;
                    _evSpAtk = ev;
                    _markChanged();
                  });
                },
              ),
              IvEvEditor(
                statName: 'SPD',
                ivValue: _ivSpDef,
                evValue: _evSpDef,
                baseStatValue: _selectedPokemon!.stats.spDef,
                level: _level,
                totalEvs: _totalEvs,
                natureMultiplier:
                    currentNature?.getMultiplierForStat('sp_def') ?? 1.0,
                onChanged: (iv, ev) {
                  setState(() {
                    _ivSpDef = iv;
                    _evSpDef = ev;
                    _markChanged();
                  });
                },
              ),
              IvEvEditor(
                statName: 'SPE',
                ivValue: _ivSpeed,
                evValue: _evSpeed,
                baseStatValue: _selectedPokemon!.stats.speed,
                level: _level,
                totalEvs: _totalEvs,
                natureMultiplier:
                    currentNature?.getMultiplierForStat('speed') ?? 1.0,
                onChanged: (iv, ev) {
                  setState(() {
                    _ivSpeed = iv;
                    _evSpeed = ev;
                    _markChanged();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
