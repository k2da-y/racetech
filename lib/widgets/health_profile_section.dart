import 'package:flutter/material.dart';
import '../utils/health_profile.dart';

class HealthProfileSection extends StatelessWidget {
  final HealthProfile profile;
  final TextEditingController height, weight, date;
  final Map<String, String> errors;
  final bool enabled;
  final bool hasChanges;
  final String syncMessage;
  final bool syncWarning;
  const HealthProfileSection({
    super.key,
    required this.profile,
    required this.height,
    required this.weight,
    required this.date,
    this.errors = const {},
    this.enabled = true,
    this.hasChanges = false,
    this.syncMessage = '',
    this.syncWarning = false,
  });

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final existing = DateTime.tryParse(date.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: existing != null && !existing.isAfter(now) ? existing : now,
      firstDate: existing != null && existing.year < 1900
          ? existing
          : DateTime(1900),
      lastDate: now,
    );
    if (picked != null && context.mounted) {
      date.text = picked.toIso8601String().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Private health measurements. Optional and not used for registration eligibility.',
      ),
      const SizedBox(height: 16),
      if (syncMessage.isNotEmpty) ...[
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: syncWarning ? Colors.orange.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: syncWarning
                    ? Colors.orange.shade300
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  syncWarning ? Icons.sync_problem : Icons.cloud_off,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(syncMessage)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      for (final field in [
        (height, 'Height (cm)', 'height'),
        (weight, 'Weight (kg)', 'weight'),
      ]) ...[
        TextField(
          key: ValueKey('health-${field.$3}'),
          controller: field.$1,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '${field.$2} — optional',
            errorText: errors[field.$3],
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
      ],
      TextField(
        key: const Key('health-date'),
        controller: date,
        enabled: enabled,
        readOnly: true,
        onTap: () => pickDate(context),
        decoration: InputDecoration(
          labelText: 'Measurement date — optional',
          helperText:
              'Leave blank to use the server date for new measurements.',
          errorText: errors['date'],
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: 'Clear measurement date',
            onPressed: enabled ? date.clear : null,
            icon: const Icon(Icons.clear),
          ),
        ),
      ),
      TextButton(
        onPressed: enabled
            ? () {
                height.clear();
                weight.clear();
                date.clear();
              }
            : null,
        child: const Text('Clear measurements'),
      ),
      const Divider(),
      if (hasChanges)
        const Text(
          'Unsaved changes. Save to calculate a private on-device preview.',
        ),
      if (profile.bmi != null)
        Text(
          'BMI: ${profile.bmi!.toStringAsFixed(1)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      Text(profile.message),
      if (profile.measuredAt.isNotEmpty)
        Text('Measured on ${profile.measuredAt}'),
      const SizedBox(height: 12),
      Text(profile.disclaimer),
    ],
  );
}
