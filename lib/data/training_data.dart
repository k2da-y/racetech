class TrainingData {

  static List<Map<String, dynamic>> getQuests(String activity) {

    switch (activity) {

      case "Cycling":
        return [
          {"title": "Easy Ride", "desc": "5km ride", "diff": "Easy"},
          {"title": "Warm Up", "desc": "10 min cycling", "diff": "Easy"},

          {"title": "Endurance Ride", "desc": "20km ride", "diff": "Medium"},
          {"title": "Speed Ride", "desc": "Maintain 25km/h", "diff": "Medium"},

          {"title": "Long Ride", "desc": "50km ride", "diff": "Hard"},
          {"title": "Hill Climb", "desc": "Uphill challenge", "diff": "Hard"},
        ];

      case "Trail Run":
        return [
          {"title": "Easy Trail", "desc": "3km trail", "diff": "Easy"},
          {"title": "Nature Walk", "desc": "Light trail walk", "diff": "Easy"},

          {"title": "Trail Endurance", "desc": "10km trail", "diff": "Medium"},
          {"title": "Elevation Run", "desc": "Hill run", "diff": "Medium"},

          {"title": "Extreme Trail", "desc": "20km trail", "diff": "Hard"},
          {"title": "Mountain Run", "desc": "High elevation", "diff": "Hard"},
        ];

      case "Marathon":
        return [
          {"title": "Short Run", "desc": "5km run", "diff": "Easy"},
          {"title": "Jogging", "desc": "20 min jog", "diff": "Easy"},

          {"title": "Long Run", "desc": "15km run", "diff": "Medium"},
          {"title": "Pace Training", "desc": "Maintain pace", "diff": "Medium"},

          {"title": "Half Marathon", "desc": "21km run", "diff": "Hard"},
          {"title": "Full Marathon Prep", "desc": "30km run", "diff": "Hard"},
        ];

      case "Duathlon":
        return [
          {"title": "Run + Bike", "desc": "2km + 5km", "diff": "Easy"},
          {"title": "Light Combo", "desc": "Short duathlon", "diff": "Easy"},

          {"title": "Duathlon Set", "desc": "5km + 20km", "diff": "Medium"},
          {"title": "Brick Training", "desc": "Run-Bike-Run", "diff": "Medium"},

          {"title": "Full Duathlon", "desc": "10km + 40km", "diff": "Hard"},
          {"title": "Race Simulation", "desc": "Full set", "diff": "Hard"},
        ];

      default: // Running
        return [
          {"title": "Easy Run", "desc": "3km run", "diff": "Easy"},
          {"title": "Walk + Run", "desc": "Intervals", "diff": "Easy"},

          {"title": "5KM Challenge", "desc": "Complete 5km", "diff": "Medium"},
          {"title": "Speed Run", "desc": "Sprint intervals", "diff": "Medium"},

          {"title": "10KM Run", "desc": "Long run", "diff": "Hard"},
          {"title": "Endurance Run", "desc": "Non-stop run", "diff": "Hard"},
        ];
    }
  }
}