import 'package:flutter/material.dart';
import 'package:championdex/domain/battle/simulation_event.dart';

class SimulationEventWidget extends StatefulWidget {
  final SimulationEvent event;
  final int eventIndex;
  final bool isModified;
  final bool needsRecalculation;
  final Function(EventModification) onModify;
  final Function() onRerunFromHere;

  const SimulationEventWidget({
    super.key,
    required this.event,
    required this.eventIndex,
    required this.isModified,
    required this.needsRecalculation,
    required this.onModify,
    required this.onRerunFromHere,
  });

  @override
  State<SimulationEventWidget> createState() => _SimulationEventWidgetState();
}

class _SimulationEventWidgetState extends State<SimulationEventWidget> {
  bool _isExpanded = false;
  int? _selectedDamageRoll;
  bool _forceCrit = false;
  bool _forceMiss = false;

  @override
  void initState() {
    super.initState();
    _selectedDamageRoll = widget.event.damageAmount;
  }

  Color _getEventColor() {
    if (widget.isModified) return Colors.orange.shade700;
    if (widget.needsRecalculation) return Colors.grey.shade400;

    switch (widget.event.type) {
      case SimulationEventType.moveUsed:
        return Colors.blue.shade600;
      case SimulationEventType.damageDealt:
        return Colors.red.shade600;
      case SimulationEventType.fainted:
        return Colors.grey.shade700;
      case SimulationEventType.effectivenessMessage:
        return Colors.purple.shade600;
      case SimulationEventType.missed:
        return Colors.amber.shade700;
      case SimulationEventType.protected:
        return Colors.green.shade600;
      default:
        return Colors.grey.shade500;
    }
  }

  IconData _getEventIcon() {
    switch (widget.event.type) {
      case SimulationEventType.moveUsed:
        return Icons.flash_on;
      case SimulationEventType.damageDealt:
        return Icons.favorite;
      case SimulationEventType.fainted:
        return Icons.cancel;
      case SimulationEventType.effectivenessMessage:
        return Icons.info_outline;
      case SimulationEventType.missed:
        return Icons.close;
      case SimulationEventType.protected:
        return Icons.shield;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.event.isEditable && !widget.needsRecalculation;
    final variations = widget.event.variations;
    final koProbability = widget.event.getKnockoutProbability();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: widget.isModified ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getEventColor(),
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              _getEventIcon(),
              color: _getEventColor(),
              size: 20,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.event.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isModified
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.isModified)
                  Chip(
                    label: Text('Modified', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.orange,
                    labelStyle: TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                if (widget.needsRecalculation)
                  Chip(
                    label: Text('Stale', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.grey,
                    labelStyle: TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            subtitle: koProbability != null
                ? Text(
                    koProbability.getDisplayText(),
                    style: TextStyle(
                      fontSize: 11,
                      color: koProbability.willAlwaysKO
                          ? Colors.red
                          : Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
            trailing: canEdit
                ? IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  )
                : null,
          ),
          if (_isExpanded && canEdit) _buildEditControls(variations),
        ],
      ),
    );
  }

  Widget _buildEditControls(EventVariations? variations) {
    if (variations == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modify Outcome:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Damage roll selector
          if (variations.damageRolls != null &&
              variations.damageRolls!.isNotEmpty)
            _buildDamageRollSelector(variations.damageRolls!),

          // Critical hit option
          if (variations.canCrit) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              dense: true,
              title: Text('Force Critical Hit', style: TextStyle(fontSize: 12)),
              value: _forceCrit,
              onChanged: (value) {
                setState(() {
                  _forceCrit = value ?? false;
                });
              },
            ),
          ],

          // Miss option
          if (variations.canMiss) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              title: Text(
                'Force Miss (${(variations.hitChance * 100).toStringAsFixed(1)}% hit chance)',
                style: TextStyle(fontSize: 12),
              ),
              value: _forceMiss,
              onChanged: (value) {
                setState(() {
                  _forceMiss = value ?? false;
                });
              },
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDamageRoll = widget.event.damageAmount;
                    _forceCrit = false;
                    _forceMiss = false;
                  });
                },
                child: Text('Reset'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.play_arrow, size: 16),
                label: Text('Apply & Rerun'),
                onPressed: () {
                  final modification = EventModification(
                    selectedDamageRoll:
                        _selectedDamageRoll != widget.event.damageAmount
                            ? _selectedDamageRoll
                            : null,
                    forceCrit: _forceCrit ? true : null,
                    forceMiss: _forceMiss ? true : null,
                  );
                  widget.onModify(modification);
                  widget.onRerunFromHere();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDamageRollSelector(List<int> rolls) {
    // Get unique sorted rolls
    final uniqueRolls = rolls.toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Damage Roll:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: uniqueRolls.map((roll) {
            final isSelected = roll == _selectedDamageRoll;
            return ChoiceChip(
              label: Text(
                roll.toString(),
                style: TextStyle(fontSize: 11),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedDamageRoll = roll;
                });
              },
              selectedColor: Colors.blue.shade300,
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          'All rolls have equal probability (${(100 / rolls.length).toStringAsFixed(1)}% each)',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
