import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class TrainingModulePage extends StatefulWidget {
  const TrainingModulePage({super.key});

  @override
  State<TrainingModulePage> createState() => _TrainingModulePageState();
}

class _TrainingModulePageState extends State<TrainingModulePage> {
  String selectedActivity = "";
  bool isLoading = true;
  List<Map<String, dynamic>> modules = [];

  Future<void> loadTrainingModules() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList("activities") ?? [];
    final loadedModules = await ApiService().getTrainingModules();

    if (!mounted) return;

    setState(() {
      selectedActivity = activities.isNotEmpty ? activities.first : "Running";
      modules = loadedModules;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadTrainingModules();
  }

  String displayDifficulty(String difficulty) {
    switch (difficulty) {
      case "beginner":
        return "Beginner";
      case "intermediate":
        return "Intermediate";
      case "advanced":
        return "Advanced";
      default:
        return difficulty.isEmpty ? "General" : difficulty;
    }
  }

  Color difficultyColor(String difficulty) {
    switch (difficulty) {
      case "beginner":
        return Colors.green;
      case "intermediate":
        return Colors.orange;
      case "advanced":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData typeIcon(String type) {
    switch (type) {
      case "warmup":
        return Icons.directions_run_outlined;
      case "safety":
        return Icons.health_and_safety_outlined;
      case "guideline":
        return Icons.menu_book_outlined;
      case "program":
        return Icons.fitness_center_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  Widget moduleCard(Map<String, dynamic> module) {
    final title = (module["title"] ?? "Untitled Module").toString();
    final description = (module["description"] ?? "").toString();
    final content = (module["content"] ?? "").toString();
    final type = (module["type"] ?? "").toString();
    final difficulty = (module["difficulty_level"] ?? "").toString();
    final duration = module["duration"];
    final color = difficultyColor(difficulty);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeIcon(type), color: color),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(displayDifficulty(difficulty)),
                visualDensity: VisualDensity.compact,
              ),
              if (duration != null)
                Chip(
                  label: Text("$duration min"),
                  visualDensity: VisualDensity.compact,
                ),
              if (type.isNotEmpty)
                Chip(label: Text(type), visualDensity: VisualDensity.compact),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text("Training: $selectedActivity")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : modules.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No training modules available yet.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => isLoading = true);
                await loadTrainingModules();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  return moduleCard(modules[index]);
                },
              ),
            ),
    );
  }
}
