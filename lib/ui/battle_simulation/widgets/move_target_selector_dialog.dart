import 'package:flutter/material.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';

enum _TargetBehavior {
  singleOtherPokemon, // Choose a single target other than user (allies or opponents)
  autoselectAllTeam, // Autoselect all user's team
  autoselectAllExceptUser, // Autoselect all except user
  autoselectUser, // Autoselect user only
  autoselectAllOpposing, // Autoselect all opposing pokemon
  autoselectAllField, // Autoselect all pokemon
  singleOpponentOnly, // Only allow selecting a single opponent
  autoselectAlly, // Autoselect an ally
  singleUserOrAlly, // Choose user or single ally
}

class MoveTargetSelectorDialog extends StatefulWidget {
  final Move move;
  final BattlePokemon userPokemon;
  final List<BattlePokemon> team1Pokemon;
  final List<BattlePokemon> team2Pokemon;
  final VoidCallback onCancel;
  final Function(String? targetPokemonName) onConfirm;

  static const Map<String, _TargetBehavior> _targetDescriptionMap = {
    "Targets a single adjacent Pokémon.": _TargetBehavior.singleOtherPokemon,
    "Targets all Pokémon on the user's team.":
        _TargetBehavior.autoselectAllTeam,
    "Targets all adjacent Pokémon.": _TargetBehavior.autoselectAllExceptUser,
    "Targets the user, but hits a random adjacent opponent.":
        _TargetBehavior.autoselectUser,
    "Targets all Pokémon on the opposing field.":
        _TargetBehavior.autoselectAllOpposing,
    "Targets the entire field.": _TargetBehavior.autoselectAllField,
    "Targets a single adjacent foe, but not an ally.":
        _TargetBehavior.singleOpponentOnly,
    "Targets any single Pokémon on the field including non-adjacent ones.":
        _TargetBehavior.singleOtherPokemon,
    "Targets an adjacent Pokémon on the user's team.":
        _TargetBehavior.autoselectAlly,
    "Targets all adjacent foes.": _TargetBehavior.autoselectAllOpposing,
    "Targets the user.": _TargetBehavior.autoselectUser,
    "Targets either the user or an adjacent Pokémon on the user's team.":
        _TargetBehavior.singleUserOrAlly,
  };

  const MoveTargetSelectorDialog({
    super.key,
    required this.move,
    required this.userPokemon,
    required this.team1Pokemon,
    required this.team2Pokemon,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<MoveTargetSelectorDialog> createState() =>
      _MoveTargetSelectorDialogState();
}

class _MoveTargetSelectorDialogState extends State<MoveTargetSelectorDialog> {
  String? _selectedTargetName;
  bool _autoConfirm = false;

  @override
  void initState() {
    super.initState();
    _handleTargetBehavior();
  }

  /// Determine target behavior from move description and act accordingly
  void _handleTargetBehavior() {
    final description = widget.move.targets ?? '';
    final behavior =
        MoveTargetSelectorDialog._targetDescriptionMap[description] ??
            _TargetBehavior.singleOtherPokemon; // Default to single selection

    switch (behavior) {
      case _TargetBehavior.autoselectUser:
        _autoConfirm = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onConfirm(widget.userPokemon.pokemonName);
          }
        });

      case _TargetBehavior.autoselectAllTeam:
        _autoConfirm = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onConfirm('all-team');
          }
        });

      case _TargetBehavior.autoselectAllExceptUser:
        _autoConfirm = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onConfirm('all-except-user');
          }
        });

      case _TargetBehavior.autoselectAllOpposing:
        _autoConfirm = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onConfirm('all-opposing');
          }
        });

      case _TargetBehavior.autoselectAllField:
        _autoConfirm = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onConfirm('all-field');
          }
        });

      case _TargetBehavior.autoselectAlly:
        _autoConfirm = true;
        // Get first available ally
        final userTeam = _getUserTeam();
        final allies = userTeam
            .where((p) => p.pokemonName != widget.userPokemon.pokemonName)
            .toList();
        if (allies.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onConfirm(allies.first.pokemonName);
            }
          });
        }

      case _TargetBehavior.singleOtherPokemon:
      case _TargetBehavior.singleOpponentOnly:
      case _TargetBehavior.singleUserOrAlly:
        // These require user selection, show dialog
        _autoConfirm = false;
    }
  }

  List<BattlePokemon> _getUserTeam() {
    final isTeam1User = widget.team1Pokemon.contains(widget.userPokemon);
    return isTeam1User ? widget.team1Pokemon : widget.team2Pokemon;
  }

  List<BattlePokemon> _getOpposingTeam() {
    final isTeam1User = widget.team1Pokemon.contains(widget.userPokemon);
    return isTeam1User ? widget.team2Pokemon : widget.team1Pokemon;
  }

  /// Get valid targets based on target behavior
  List<BattlePokemon> _getValidTargets() {
    final description = widget.move.targets ?? '';
    final behavior =
        MoveTargetSelectorDialog._targetDescriptionMap[description] ??
            _TargetBehavior.singleOtherPokemon;

    final userTeam = _getUserTeam();
    final opposingTeam = _getOpposingTeam();

    switch (behavior) {
      case _TargetBehavior.singleOtherPokemon:
        // Can target any pokemon except user
        return [
          ...opposingTeam,
          ...userTeam.where((p) => p != widget.userPokemon)
        ];

      case _TargetBehavior.singleOpponentOnly:
        // Can only target opposing team
        return opposingTeam;

      case _TargetBehavior.singleUserOrAlly:
        // Can target user or allies
        return [
          widget.userPokemon,
          ...userTeam.where((p) => p != widget.userPokemon)
        ];

      default:
        return opposingTeam;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If this is an auto-confirming behavior, don't show the dialog
    if (_autoConfirm) {
      return SizedBox.shrink();
    }

    final validTargets = _getValidTargets();
    final description = widget.move.targets ?? '';
    final behavior =
        MoveTargetSelectorDialog._targetDescriptionMap[description] ??
            _TargetBehavior.singleOtherPokemon;

    String getDialogTitle() {
      switch (behavior) {
        case _TargetBehavior.singleOpponentOnly:
          return 'Select Opponent for ${widget.move.name}';
        case _TargetBehavior.singleUserOrAlly:
          return 'Select User or Ally for ${widget.move.name}';
        default:
          return 'Select Target for ${widget.move.name}';
      }
    }

    return AlertDialog(
      title: Text(getDialogTitle()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                widget.move.targets ?? 'No target information',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ...validTargets.map((pokemon) {
              final isSelected = _selectedTargetName == pokemon.pokemonName;
              final isUser =
                  pokemon.pokemonName == widget.userPokemon.pokemonName;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTargetName = pokemon.pokemonName;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pokemon.pokemonName.replaceAll('-', ' '),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                              ),
                              if (isUser)
                                Text(
                                  '(User)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.blue),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${pokemon.currentHp}/${pokemon.maxHp} HP',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onCancel();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedTargetName != null
              ? () {
                  widget.onConfirm(_selectedTargetName);
                }
              : null,
          child: Text('Confirm'),
        ),
      ],
    );
  }
}
