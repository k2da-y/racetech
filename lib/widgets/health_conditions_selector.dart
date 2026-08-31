import 'package:flutter/material.dart';

class HealthConditionsSelector extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String title;

  const HealthConditionsSelector({
    super.key,
    required this.controller,
    this.enabled = true,
    this.title = "Health notes",
  });

  @override
  State<HealthConditionsSelector> createState() =>
      _HealthConditionsSelectorState();
}

class _HealthConditionsSelectorState extends State<HealthConditionsSelector> {
  static const List<String> conditions = [
    "Asthma",
    "Hypertension",
    "Diabetes",
    "Heart condition",
    "Allergies",
    "Arthritis",
    "Epilepsy",
    "Anxiety or panic disorder",
  ];

  final Set<String> selectedConditions = {};
  final otherController = TextEditingController();
  bool noneSelected = false;
  bool expanded = false;
  bool applyingControllerValue = false;

  @override
  void initState() {
    super.initState();
    parseControllerValue();
    widget.controller.addListener(handleControllerChanged);
    otherController.addListener(updateControllerValue);
  }

  @override
  void didUpdateWidget(covariant HealthConditionsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(handleControllerChanged);
      widget.controller.addListener(handleControllerChanged);
      parseControllerValue();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(handleControllerChanged);
    otherController.dispose();
    super.dispose();
  }

  void handleControllerChanged() {
    if (applyingControllerValue) return;
    parseControllerValue();
  }

  void parseControllerValue() {
    final rawValue = widget.controller.text.trim();
    final normalized = rawValue.toLowerCase();
    final parsedConditions = <String>{};

    for (final condition in conditions) {
      if (normalized.contains(condition.toLowerCase())) {
        parsedConditions.add(condition);
      }
    }

    final parsedNone =
        normalized == "none" || normalized == "none of the above";
    var parsedOther = rawValue;

    for (final condition in conditions) {
      parsedOther = parsedOther.replaceAll(
        RegExp(RegExp.escape(condition), caseSensitive: false),
        "",
      );
    }

    parsedOther = parsedOther
        .replaceAll(RegExp(r"\bother\s*:", caseSensitive: false), "")
        .replaceAll(
          RegExp(r"\bnone( of the above)?\b", caseSensitive: false),
          "",
        )
        .replaceAll(RegExp(r"[,;|]+"), " ")
        .trim();

    if (parsedNone || parsedConditions.isNotEmpty) {
      parsedOther = parsedOther.trim();
    }

    setState(() {
      noneSelected = parsedNone;
      selectedConditions
        ..clear()
        ..addAll(parsedNone ? const <String>{} : parsedConditions);
      if (otherController.text != parsedOther) {
        otherController.text = parsedOther;
      }
    });
  }

  void updateControllerValue() {
    if (!mounted) return;

    final values = <String>[
      if (noneSelected)
        "None of the above"
      else ...[
        ...conditions.where(selectedConditions.contains),
        if (otherController.text.trim().isNotEmpty)
          "Other: ${otherController.text.trim()}",
      ],
    ];

    applyingControllerValue = true;
    widget.controller.text = values.join(", ");
    applyingControllerValue = false;
  }

  void toggleCondition(String condition, bool selected) {
    setState(() {
      noneSelected = false;
      if (selected) {
        selectedConditions.add(condition);
      } else {
        selectedConditions.remove(condition);
      }
    });
    updateControllerValue();
  }

  void toggleNone(bool selected) {
    setState(() {
      noneSelected = selected;
      if (selected) {
        selectedConditions.clear();
        otherController.clear();
      }
    });
    updateControllerValue();
  }

  String get summaryText {
    if (noneSelected) return "None of the above";

    final selectedCount =
        selectedConditions.length +
        (otherController.text.trim().isEmpty ? 0 : 1);

    if (selectedCount == 0) {
      return "Select medical conditions";
    }

    if (selectedCount == 1) {
      if (selectedConditions.isNotEmpty) return selectedConditions.first;
      return "Other condition";
    }

    return "$selectedCount selected";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.enabled
                ? () => setState(() => expanded = !expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_information_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          summaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                ...conditions.map(
                  (condition) => CheckboxListTile(
                    value: selectedConditions.contains(condition),
                    enabled: widget.enabled,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      condition,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) =>
                        toggleCondition(condition, value ?? false),
                  ),
                ),
                TextField(
                  controller: otherController,
                  enabled: widget.enabled && !noneSelected,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: "Other condition",
                    hintText: "Optional",
                    prefixIcon: Icon(Icons.edit_note_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 2),
                CheckboxListTile(
                  value: noneSelected,
                  enabled: widget.enabled,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "None of the above",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => toggleNone(value ?? false),
                ),
              ],
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}
