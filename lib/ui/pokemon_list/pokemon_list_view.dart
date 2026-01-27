import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pokemon_list_widget.dart';
import '../moves_list/moves_list_widget.dart';
import '../abilities_list/abilities_list_widget.dart';
import '../teams_list/teams_list_widget.dart';

class PokemonListView extends ConsumerStatefulWidget {
  const PokemonListView({super.key});

  @override
  ConsumerState<PokemonListView> createState() => _PokemonListViewState();
}

class _PokemonListViewState extends ConsumerState<PokemonListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showHelpModal(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use Champion Dex'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pokémon Tab',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse and search for Pokémon by name, variant, or type. Tap any Pokémon to view detailed stats and moves.',
              ),
              const SizedBox(height: 16),
              Text(
                'Moves Tab',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore all moves in the game. Search by name, type, or category. Tap a move to see its effects and which Pokémon can learn it.',
              ),
              const SizedBox(height: 16),
              Text(
                'Abilities Tab',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse abilities and their effects. Search by name or ability description. Tap to see which Pokémon have each ability.',
              ),
              const SizedBox(height: 16),
              Text(
                'Teams Tab',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create and manage your Pokémon teams. Coming soon!',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 65,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.catching_pokemon,
                color: theme.colorScheme.onPrimary,
                size: 28,
              ),
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Champion Dex',
                  style: GoogleFonts.racingSansOne(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline,
              color: theme.colorScheme.onPrimary,
            ),
            onPressed: () => _showHelpModal(context),
            tooltip: 'Help',
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: theme.colorScheme.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.catching_pokemon),
                      text: 'Pokémon',
                    ),
                    Tab(
                      icon: Icon(Icons.flash_on),
                      text: 'Moves',
                    ),
                    Tab(
                      icon: Icon(Icons.auto_awesome),
                      text: 'Abilities',
                    ),
                    Tab(
                      icon: Icon(Icons.groups),
                      text: 'Teams',
                    ),
                  ],
                  indicatorColor: theme.colorScheme.onPrimary,
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor:
                      theme.colorScheme.onPrimary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PokemonListWidget(),
          MovesListWidget(),
          AbilitiesListWidget(),
          TeamsListWidget(),
        ],
      ),
    );
  }
}
