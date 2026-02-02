import 'package:flutter/material.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';

class BattleFieldWidget extends StatelessWidget {
  final String team1Name;
  final String team2Name;
  final List<BattlePokemon?> team1Pokemon;
  final List<BattlePokemon?> team2Pokemon;
  final Function(bool isTeam1, int slotIndex)? onPokemonTap;

  const BattleFieldWidget({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.team1Pokemon,
    required this.team2Pokemon,
    this.onPokemonTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Stack(
        children: [
          // Backdrop image
          Container(
            height: 350,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/backdrops/stadium.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay for better readability
          Container(
            height: 350,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Battle layout with teams on left and right
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              children: [
                // Top section: Team names
                SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Team 1 name (left side)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            team1Name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      // Team 2 name (right side)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            team2Name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pokemon slots
                Expanded(
                  child: Row(
                    children: [
                      // Team 1 Pokemon (left side)
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(
                            team1Pokemon.length,
                            (index) => Positioned(
                              left: index * 30.0, // Stagger horizontally
                              top: index * 128.0, // Stagger vertically
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildPokemonSlot(
                                  context,
                                  team1Pokemon[index],
                                  true,
                                  index,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Team 2 Pokemon (right side)
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(
                            team2Pokemon.length,
                            (index) => Positioned(
                              right: index * 30.0, // Stagger horizontally
                              top: index * 128.0, // Stagger vertically
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildPokemonSlot(
                                  context,
                                  team2Pokemon[index],
                                  false,
                                  index,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
    BuildContext context,
    BattlePokemon? pokemon,
    bool isTeam1,
    int slotIndex,
  ) {
    if (pokemon == null) {
      // Empty slot placeholder
      return GestureDetector(
        onTap: () => onPokemonTap?.call(isTeam1, slotIndex),
        child: Container(
          constraints: BoxConstraints(maxWidth: 110),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      Icon(Icons.help_outline, size: 28, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Pokemon with HP bar
    final hpPercentage = pokemon.hpPercentage;
    final hpColor = hpPercentage > 0.5
        ? Colors.green
        : (hpPercentage > 0.25 ? Colors.yellow : Colors.red);

    return GestureDetector(
      onTap: () => onPokemonTap?.call(isTeam1, slotIndex),
      child: Stack(
        children: [
          Container(
            height: 120,
            width: 100,
            // constraints: BoxConstraints(maxWidth: 110),
            decoration: BoxDecoration(
              border: Border.all(
                color: pokemon.queuedAction != null
                    ? Colors.greenAccent
                    : Colors.white30,
                width: pokemon.queuedAction != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.black26,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // HP Bar
                  Container(
                    width: 70,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: 70 * hpPercentage,
                          height: 5,
                          decoration: BoxDecoration(
                            color: hpColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2),
                  // HP Text
                  Text(
                    '${pokemon.currentHp}/${pokemon.maxHp}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                  ),
                  SizedBox(height: 2),
                  // Pokemon Image
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Image.asset(
                      'assets/images/pokemon/${pokemon.imagePath?.toLowerCase()}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.catching_pokemon,
                            size: 28, color: Colors.grey[500]);
                      },
                    ),
                  ),
                  SizedBox(height: 2),
                  // Pokemon Name
                  Text(
                    pokemon.pokemonName.replaceAll('-', ' '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Ready indicator badge
          if (pokemon.queuedAction != null)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
