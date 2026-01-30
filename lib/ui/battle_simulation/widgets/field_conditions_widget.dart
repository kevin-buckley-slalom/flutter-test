import 'package:flutter/material.dart';

class FieldConditionsWidget extends StatefulWidget {
  final Function(String category, dynamic value) onFieldConditionChanged;

  const FieldConditionsWidget({
    super.key,
    required this.onFieldConditionChanged,
  });

  @override
  State<FieldConditionsWidget> createState() => _FieldConditionsWidgetState();
}

class _FieldConditionsWidgetState extends State<FieldConditionsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final terrains = ['Electric', 'Grassy', 'Misty', 'Psychic'];
  final weathers = [
    'Harsh Sunlight',
    'Heavy Rain',
    'Strong Winds',
    'Hail',
    'Sandstorm',
    'Rain',
    'Sun',
    'Snow'
  ];
  final rooms = ['Trick Room', 'Wonder Room', 'Magic Room'];
  final singleSideEffects = [
    'Reflect',
    'Light Screen',
    'Aurora Veil',
    'Tailwind',
    'Safeguard',
    'Sea of Fire',
    'Rainbow',
    'Swamp',
    'Stealth Rocks',
    'Spikes',
    'Toxic Spikes',
  ];
  final otherEffects = [
    'Gravity',
    'Ion Deluge',
    'Fairy Aura',
    'Dark Aura',
    'Mud Sport',
    'Water Sport'
  ];

  String? selectedTerrain;
  String? selectedWeather;
  final Set<String> selectedRooms = {};
  final Map<String, Set<String>> selectedSingleSideEffects = {
    'team1': {},
    'team2': {},
  };
  final Map<String, int> spikesLayers = {
    'team1': 0,
    'team2': 0,
  };
  final Map<String, int> toxicSpikesLayers = {
    'team1': 0,
    'team2': 0,
  };
  final Set<String> selectedOtherEffects = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Text(
                'Terrain',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            Tab(
              child: Text(
                'Weather',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            Tab(
              child: Text(
                'Rooms',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            Tab(
              child: Text(
                'Side\nEffects',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            Tab(
              child: Text(
                'Other',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          isScrollable: false,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.w600, height: 1.1),
          unselectedLabelStyle:
              Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.1),
        ),
        SizedBox(
          height: 250,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Terrain Tab
              _buildSingleSelectTab(
                options: terrains,
                selectedValue: selectedTerrain,
                onSelected: (value) {
                  setState(() => selectedTerrain = value);
                  widget.onFieldConditionChanged('terrain', value);
                },
                onClear: () {
                  setState(() => selectedTerrain = null);
                  widget.onFieldConditionChanged('terrain', null);
                },
              ),
              // Weather Tab
              _buildSingleSelectTab(
                options: weathers,
                selectedValue: selectedWeather,
                onSelected: (value) {
                  setState(() => selectedWeather = value);
                  widget.onFieldConditionChanged('weather', value);
                },
                onClear: () {
                  setState(() => selectedWeather = null);
                  widget.onFieldConditionChanged('weather', null);
                },
              ),
              // Rooms Tab
              _buildMultiSelectTab(
                options: rooms,
                selectedValues: selectedRooms,
                onSelected: (value, isSelected) {
                  setState(() {
                    if (isSelected) {
                      selectedRooms.add(value);
                    } else {
                      selectedRooms.remove(value);
                    }
                  });
                  widget.onFieldConditionChanged(
                      'rooms', selectedRooms.toList());
                },
                onClear: () {
                  setState(() => selectedRooms.clear());
                  widget.onFieldConditionChanged('rooms', []);
                },
              ),
              // Single Side Effects Tab
              _buildSidedEffectsTab(
                options: singleSideEffects,
                selectedTeam1: selectedSingleSideEffects['team1']!,
                selectedTeam2: selectedSingleSideEffects['team2']!,
                onTeam1Selected: (value, isSelected) {
                  setState(() {
                    if (isSelected) {
                      selectedSingleSideEffects['team1']!.add(value);
                    } else {
                      selectedSingleSideEffects['team1']!.remove(value);
                    }
                  });
                  widget.onFieldConditionChanged(
                    'singleSideEffects',
                    selectedSingleSideEffects,
                  );
                },
                onTeam2Selected: (value, isSelected) {
                  setState(() {
                    if (isSelected) {
                      selectedSingleSideEffects['team2']!.add(value);
                    } else {
                      selectedSingleSideEffects['team2']!.remove(value);
                    }
                  });
                  widget.onFieldConditionChanged(
                    'singleSideEffects',
                    selectedSingleSideEffects,
                  );
                },
              ),
              // Other Effects Tab
              _buildMultiSelectTab(
                options: otherEffects,
                selectedValues: selectedOtherEffects,
                onSelected: (value, isSelected) {
                  setState(() {
                    if (isSelected) {
                      selectedOtherEffects.add(value);
                    } else {
                      selectedOtherEffects.remove(value);
                    }
                  });
                  widget.onFieldConditionChanged(
                    'otherEffects',
                    selectedOtherEffects.toList(),
                  );
                },
                onClear: () {
                  setState(() => selectedOtherEffects.clear());
                  widget.onFieldConditionChanged('otherEffects', []);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleSelectTab({
    required List<String> options,
    required String? selectedValue,
    required Function(String) onSelected,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selectedValue == option,
                  onSelected: (_) => onSelected(option),
                ),
              ),
            ],
          ),
          if (selectedValue != null) ...[
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.clear),
              label: Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiSelectTab({
    required List<String> options,
    required Set<String> selectedValues,
    required Function(String, bool) onSelected,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selectedValues.contains(option),
                  onSelected: (isSelected) => onSelected(option, isSelected),
                ),
              ),
            ],
          ),
          if (selectedValues.isNotEmpty) ...[
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.clear),
              label: Text('Clear All'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidedEffectsTab({
    required List<String> options,
    required Set<String> selectedTeam1,
    required Set<String> selectedTeam2,
    required Function(String, bool) onTeam1Selected,
    required Function(String, bool) onTeam2Selected,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team 1 Effects',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map(
                (option) {
                  if (option == 'Spikes' || option == 'Toxic Spikes') {
                    return _buildLayeredEffectChip(
                      label: option,
                      isSelected: selectedTeam1.contains(option),
                      team: 'team1',
                      effectType: option,
                      onToggle: (isSelected) =>
                          onTeam1Selected(option, isSelected),
                    );
                  }
                  return FilterChip(
                    label: Text(option),
                    selected: selectedTeam1.contains(option),
                    onSelected: (isSelected) =>
                        onTeam1Selected(option, isSelected),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Team 2 Effects',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map(
                (option) {
                  if (option == 'Spikes' || option == 'Toxic Spikes') {
                    return _buildLayeredEffectChip(
                      label: option,
                      isSelected: selectedTeam2.contains(option),
                      team: 'team2',
                      effectType: option,
                      onToggle: (isSelected) =>
                          onTeam2Selected(option, isSelected),
                    );
                  }
                  return FilterChip(
                    label: Text(option),
                    selected: selectedTeam2.contains(option),
                    onSelected: (isSelected) =>
                        onTeam2Selected(option, isSelected),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayeredEffectChip({
    required String label,
    required bool isSelected,
    required String team,
    required String effectType,
    required Function(bool) onToggle,
  }) {
    final isSpikes = effectType == 'Spikes';
    final layerMap = isSpikes ? spikesLayers : toxicSpikesLayers;
    final currentLayers = layerMap[team] ?? 0;

    if (!isSelected) {
      return FilterChip(
        label: Text(label),
        selected: false,
        onSelected: (isSelected) {
          onToggle(true);
          setState(() {
            layerMap[team] = 1;
          });
          widget.onFieldConditionChanged(
            effectType == 'Spikes' ? 'spikes' : 'toxicSpikes',
            {'team1': spikesLayers['team1'], 'team2': spikesLayers['team2']},
          );
        },
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              onToggle(false);
              setState(() {
                layerMap[team] = 0;
              });
              widget.onFieldConditionChanged(
                effectType == 'Spikes' ? 'spikes' : 'toxicSpikes',
                {
                  'team1': spikesLayers['team1'],
                  'team2': spikesLayers['team2']
                },
              );
            },
            child: Text(label),
          ),
          SizedBox(width: 8),
          _buildLayerControl(
            currentLayers: currentLayers,
            maxLayers: 3,
            onLayersChanged: (newLayers) {
              setState(() {
                layerMap[team] = newLayers;
              });
              widget.onFieldConditionChanged(
                effectType == 'Spikes' ? 'spikes' : 'toxicSpikes',
                {
                  'team1': spikesLayers['team1'],
                  'team2': spikesLayers['team2']
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLayerControl({
    required int currentLayers,
    required int maxLayers,
    required Function(int) onLayersChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (currentLayers > 0)
          GestureDetector(
            onTap: () => onLayersChanged(currentLayers - 1),
            child: Icon(Icons.remove, size: 16),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('$currentLayers', style: TextStyle(fontSize: 12)),
        ),
        if (currentLayers < maxLayers)
          GestureDetector(
            onTap: () => onLayersChanged(currentLayers + 1),
            child: Icon(Icons.add, size: 16),
          ),
      ],
    );
  }
}
