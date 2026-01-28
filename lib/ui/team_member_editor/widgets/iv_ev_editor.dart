import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IvEvEditor extends StatefulWidget {
  final String statName;
  final int ivValue;
  final int evValue;
  final int baseStatValue;
  final int level;
  final int totalEvs;
  final double natureMultiplier;
  final Function(int iv, int ev) onChanged;

  const IvEvEditor({
    super.key,
    required this.statName,
    required this.ivValue,
    required this.evValue,
    required this.baseStatValue,
    required this.level,
    required this.totalEvs,
    required this.natureMultiplier,
    required this.onChanged,
  });

  @override
  State<IvEvEditor> createState() => _IvEvEditorState();
}

class _IvEvEditorState extends State<IvEvEditor> {
  late TextEditingController _evController;
  late TextEditingController _ivController;

  @override
  void initState() {
    super.initState();
    _evController = TextEditingController(text: widget.evValue.toString());
    _ivController = TextEditingController(text: widget.ivValue.toString());
  }

  @override
  void didUpdateWidget(IvEvEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evValue != widget.evValue) {
      _evController.text = widget.evValue.toString();
    }
    if (oldWidget.ivValue != widget.ivValue) {
      _ivController.text = widget.ivValue.toString();
    }
  }

  @override
  void dispose() {
    _evController.dispose();
    _ivController.dispose();
    super.dispose();
  }

  void _updateEv(int newValue) {
    // Calculate remaining EVs (excluding current stat's EVs)
    final otherEvs = widget.totalEvs - widget.evValue;
    final maxAllowed = 510 - otherEvs;

    // Clamp between 0-252 and respecting total EV limit
    final clampedValue = newValue.clamp(0, maxAllowed.clamp(0, 252));

    if (clampedValue != widget.evValue) {
      widget.onChanged(widget.ivValue, clampedValue);
    }
  }

  void _updateIv(int newValue) {
    final clampedValue = newValue.clamp(0, 31);
    if (clampedValue != widget.ivValue) {
      widget.onChanged(clampedValue, widget.evValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine stat label color based on nature multiplier
    Color statLabelColor;
    if (widget.natureMultiplier > 1.0) {
      statLabelColor = theme.colorScheme.primary; // Boosted stat (1.1x)
    } else if (widget.natureMultiplier < 1.0) {
      statLabelColor = theme.colorScheme.secondary; // Reduced stat (0.9x)
    } else {
      statLabelColor = theme.colorScheme.onSurface; // Neutral (1.0x)
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Stat name
          SizedBox(
            width: 28,
            child: Text(
              widget.statName,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: statLabelColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // EV input
          SizedBox(
            width: 50,
            child: TextField(
              controller: _evController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: '0',
              ),
              onChanged: (value) {
                final intValue = int.tryParse(value) ?? 0;
                _updateEv(intValue);
              },
            ),
          ),

          // EV slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                inactiveTrackColor:
                    theme.colorScheme.onSurfaceVariant.withAlpha(40),
              ),
              child: Slider(
                value: widget.evValue.toDouble(),
                min: 0,
                max: 252,
                divisions: 252,
                onChanged: (value) {
                  _updateEv(value.toInt());
                },
              ),
            ),
          ),

          // IV input
          SizedBox(
            width: 45,
            child: TextField(
              controller: _ivController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: '31',
              ),
              onChanged: (value) {
                final intValue = int.tryParse(value) ?? 31;
                _updateIv(intValue);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
