import 'package:flutter/material.dart';

import '../utils/event_category_registration.dart';
import '../utils/event_schedule_formatter.dart';
import '../utils/event_distance_formatter.dart';
import '../utils/event_gear_formatter.dart';
import '../utils/event_trail_difficulty_formatter.dart';
import '../utils/qualification_notes.dart';
import 'category_checkpoint_map.dart';

class EventDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool canJoin;
  final String statusLabel;
  final String actionLabel;
  final String availabilityMessage;
  final Future<void> Function() onJoin;

  const EventDetailsSheet({
    super.key,
    required this.event,
    required this.canJoin,
    required this.statusLabel,
    required this.actionLabel,
    required this.availabilityMessage,
    required this.onJoin,
  });

  List<Map<String, dynamic>> get categories {
    return ((event["categories"] as List?) ?? [])
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();
  }

  String get categorySectionLabel {
    final apiLabel = (event["category_label"] ?? "").toString().trim();
    if (apiLabel.isNotEmpty) return apiLabel;

    final eventType = (event["event"] ?? "").toString().toLowerCase();
    if (eventType.contains("cycling")) return "Ride Categories";
    if (eventType.contains("hiking")) {
      return "Hiking Routes / Registration Options";
    }
    if (eventType.contains("marathon") || eventType.contains("trail run")) {
      return "Race Categories";
    }
    if (eventType.contains("triathlon") || eventType.contains("duathlon")) {
      return "Competition Categories";
    }
    return "Categories";
  }

  List<Map<String, String>> get typeDetailItems {
    final explicit =
        event["type_detail_items"] ??
        event["detail_items"] ??
        event["formatted_detail_items"];
    final parsed = _detailItemsFrom(explicit);
    if (parsed.isNotEmpty) {
      return parsed
          .where(
            (item) =>
                !isGearDetailLabel(item["label"]) &&
                !isTrailDifficultyDetailLabel(item["label"]),
          )
          .toList();
    }

    return _detailItemsFrom(event["type_details"])
        .where(
          (item) =>
              !isGearDetailLabel(item["label"]) &&
              !isTrailDifficultyDetailLabel(item["label"]),
        )
        .toList();
  }

  List<Map<String, String>> _detailItemsFrom(dynamic source) {
    if (source is Map) {
      final nestedItems = source["items"];
      if (nestedItems is List) return _detailItemsFrom(nestedItems);

      return source.entries
          .map(
            (entry) => {
              "label": _humanizeKey(entry.key.toString()),
              "value": _formatDetailValue(entry.value),
            },
          )
          .where((item) => item["value"]!.isNotEmpty)
          .toList();
    }

    if (source is! List) return const [];

    return source
        .whereType<Map>()
        .map((item) {
          final label =
              item["label"] ?? item["name"] ?? item["title"] ?? item["key"];
          final value =
              item["formatted_value"] ??
              item["display_value"] ??
              item["value"] ??
              item["text"];
          return {
            "label": label?.toString().trim() ?? "",
            "value": _formatDetailValue(value),
          };
        })
        .where((item) => item["label"]!.isNotEmpty && item["value"]!.isNotEmpty)
        .toList();
  }

  String _formatDetailValue(dynamic value) {
    if (value == null) return "";
    if (value is bool) return value ? "Yes" : "No";
    if (value is List) {
      return value
          .map(_formatDetailValue)
          .where((item) => item.isNotEmpty)
          .join(", ");
    }
    if (value is Map) {
      return value.entries
          .map((entry) {
            final formatted = _formatDetailValue(entry.value);
            return formatted.isEmpty
                ? ""
                : "${_humanizeKey(entry.key.toString())}: $formatted";
          })
          .where((item) => item.isNotEmpty)
          .join(" • ");
    }
    return value.toString().trim();
  }

  String _humanizeKey(String key) {
    final words = key
        .replaceAllMapped(
          RegExp(r"([a-z0-9])([A-Z])"),
          (match) => "${match.group(1)} ${match.group(2)}",
        )
        .replaceAll(RegExp(r"[_-]+"), " ")
        .trim();
    if (words.isEmpty) return "Detail";
    return words
        .split(RegExp(r"\s+"))
        .map(
          (word) => word.isEmpty
              ? word
              : "${word[0].toUpperCase()}${word.substring(1)}",
        )
        .join(" ");
  }

  String categorySummary(Map<String, dynamic> category) {
    final distance = category["distance_km"];
    final slots = category["slots_remaining"];
    final price = (category["price_amount"] ?? "").toString();
    final currency = (category["price_currency"] ?? "PHP").toString();
    final isFree =
        category["is_free"] == true ||
        (int.tryParse((category["price_cents"] ?? 0).toString()) ?? 0) == 0;
    final parts = [
      (category["name"] ?? "Category").toString(),
      if (distance != null) "${distance}km",
      isFree ? "Free" : "$currency $price",
      if (slots != null) "$slots slots",
    ];

    return parts.join(" - ");
  }

  @override
  Widget build(BuildContext context) {
    final title = event["title"].toString();
    final description = (event["description"] ?? "").toString().trim();
    final venue = (event["venue"] ?? "").toString().trim();
    final eventCategories = categories;
    final detailItems = typeDetailItems;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        height: 180,
                        child: _EventBannerImage(
                          bannerUrl: (event["banner_url"] ?? "").toString(),
                          assetPath: (event["image"] ?? "assets/map.jpg")
                              .toString(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event["event"].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _DetailStatusChip(label: statusLabel, active: canJoin),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EventDetailMetaRow(
                      date: event["date"].toString(),
                      time: event["time"].toString(),
                      participants: "${event["participants"]}",
                    ),
                    if (venue.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _EventDetailLine(
                        icon: Icons.location_on_outlined,
                        label: venue,
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const _EventDetailSectionTitle("Overview"),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (detailItems.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const _EventDetailSectionTitle("Event Details"),
                      const SizedBox(height: 10),
                      _EventTypeDetails(items: detailItems),
                    ],
                    if (eventCategories.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _EventDetailSectionTitle(categorySectionLabel),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: eventCategories.map((category) {
                          return _CategoryChip(
                            label: categorySummary(category),
                            schedule: categoryScheduleLabel(
                              category,
                              eventStartDate: event["event_start_date"],
                              eventEndDate: event["event_end_date"],
                              legacyEventDate: event["legacy_event_date"],
                              eventStartTime: event["time"],
                              eventEndTime: event["end_time"],
                            ),
                            segmentDistances: categorySegmentDistanceLabel(
                              category,
                              eventType: event["event"],
                              eventTypeDetails: event["type_details"],
                              eventTypeDetailItems: event["type_detail_items"],
                            ),
                            gear: categoryGearLabel(
                              category,
                              eventType: event["event"],
                              eventTypeDetails: event["type_details"],
                              eventTypeDetailItems: event["type_detail_items"],
                            ),
                            trailDifficulty: categoryTrailDifficultyLabel(
                              category,
                              eventType: event["event"],
                              eventTypeDetails: event["type_details"],
                              eventTypeDetailItems: event["type_detail_items"],
                            ),
                            qualificationNotes: categoryQualificationNotes(
                              category,
                            ),
                            checkpointMapUrl: categoryCheckpointMapUrl(
                              category,
                            ),
                            statusLabel: categoryStatusLabel(category),
                            conflictReason: categoryConflictReason(category),
                            isAvailable: categoryCanRegister(category),
                            isJoined: categoryIsJoined(category),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      _EventDetailSectionTitle(categorySectionLabel),
                      const SizedBox(height: 10),
                      _EventNotice(
                        icon: Icons.flag_outlined,
                        message:
                            "No ${categorySectionLabel.toLowerCase()} are listed for this event.",
                        color: Color(0xFF64748B),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _EventNotice(
                      icon: canJoin
                          ? Icons.info_outline
                          : Icons.lock_outline_rounded,
                      message: availabilityMessage,
                      color: canJoin
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canJoin ? onJoin : null,
                icon: Icon(canJoin ? Icons.arrow_forward_rounded : Icons.lock),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: canJoin
                      ? const Color(0xFF2563EB)
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventBannerImage extends StatelessWidget {
  final String bannerUrl;
  final String assetPath;

  const _EventBannerImage({required this.bannerUrl, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    if (bannerUrl.trim().isNotEmpty) {
      return Image.network(
        bannerUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _EventImageFallback(assetPath: assetPath),
      );
    }

    return _EventImageFallback(assetPath: assetPath);
  }
}

class _EventImageFallback extends StatelessWidget {
  final String assetPath;

  const _EventImageFallback({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF0F172A),
          child: const Center(
            child: Icon(Icons.event_outlined, color: Colors.white, size: 46),
          ),
        );
      },
    );
  }
}

class _DetailStatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _DetailStatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF16A34A) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EventDetailMetaRow extends StatelessWidget {
  final String date;
  final String time;
  final String participants;

  const _EventDetailMetaRow({
    required this.date,
    required this.time,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EventDetailMetaTile(
            icon: Icons.calendar_month_outlined,
            label: "Date",
            value: date,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _EventDetailMetaTile(
            icon: Icons.schedule_outlined,
            label: "Time",
            value: time,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _EventDetailMetaTile(
            icon: Icons.groups_2_outlined,
            label: "Joined",
            value: participants,
          ),
        ),
      ],
    );
  }
}

class _EventDetailMetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EventDetailMetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 19),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventDetailLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventDetailSectionTitle extends StatelessWidget {
  final String text;

  const _EventDetailSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EventTypeDetails extends StatelessWidget {
  final List<Map<String, String>> items;

  const _EventTypeDetails({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _EventTypeDetailRow(
              label: items[index]["label"]!,
              value: items[index]["value"]!,
            ),
            if (index != items.length - 1)
              const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Color(0xFFE2E8F0),
              ),
          ],
        ],
      ),
    );
  }
}

class _EventTypeDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _EventTypeDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.route_outlined,
              color: Color(0xFF2563EB),
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EventNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String schedule;
  final String segmentDistances;
  final String gear;
  final String trailDifficulty;
  final String qualificationNotes;
  final String checkpointMapUrl;
  final String statusLabel;
  final String conflictReason;
  final bool isAvailable;
  final bool isJoined;

  const _CategoryChip({
    required this.label,
    required this.schedule,
    required this.segmentDistances,
    required this.gear,
    required this.trailDifficulty,
    required this.qualificationNotes,
    required this.checkpointMapUrl,
    required this.statusLabel,
    required this.conflictReason,
    required this.isAvailable,
    required this.isJoined,
  });

  @override
  Widget build(BuildContext context) {
    final color = isJoined
        ? const Color(0xFF2563EB)
        : isAvailable
        ? const Color(0xFF16A34A)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isJoined
                    ? Icons.verified_outlined
                    : isAvailable
                    ? Icons.check_circle_outline
                    : Icons.lock_outline_rounded,
                color: color,
                size: 15,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (schedule.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined, color: color, size: 14),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    schedule,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (segmentDistances.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              segmentDistances,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ],
          if (gear.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              gear,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
          if (trailDifficulty.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              trailDifficulty,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (qualificationNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Qualification notes\n$qualificationNotes",
              softWrap: true,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
          if (checkpointMapUrl.isNotEmpty) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: 280,
              child: CategoryCheckpointMap(imageUrl: checkpointMapUrl),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            statusLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (conflictReason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              conflictReason,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
