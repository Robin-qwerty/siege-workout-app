import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exercise Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Database _database;
  Map<String, Map<String, int>> _exerciseCounts =
      {}; // Store exercise counts for today
  Map<String, List<Map<String, dynamic>>> _dailySummaries =
      {}; // Store detailed summary of past days
  String _today =
      DateTime.now().toIso8601String().substring(0, 10); // Store today's date

  // Define exercises with repetitions for each level
  final Map<String, Map<int, String>> _exerciseDetails = {
    'Death in a round': {1: '2 push-ups', 2: '5 push-ups'},
    'Choked a 1v1': {1: '5 burpees', 2: '10 burpees'},
    'Team kill': {1: '8 burpees', 2: '15 burpees'},
    'Lost a match': {1: '10 sit-ups', 2: '15 sit-ups'},
    'Negative K/D at the end of a match': {1: '10 squats', 2: '15 squats'},
    'Death from C4': {1: '10 jumping jacks', 2: '15 jumping jacks'},
    'Death from Kapkan or Frost trap': {1: '15 sec plank', 2: '25 sec plank'},
    'Death from a Shield Operator': {1: '10 jumping jacks', 2: '15 jumping jacks'},
    'Death from a Sniper': {1: '10 mountain climbers', 2: '15 mountain climbers'},
    'Lose to an Ace (one enemy kills all)': {1: '15 squats', 2: '25 squats'},
    'Falling off the map or from a height': {1: '5 burpees', 2: '10 burpees'},
  };

  final Map<String, Map<int, int>> _exerciseRepetitions = {
    'Death in a round': {1: 2, 2: 5},
    'Choked a 1v1': {1: 5, 2: 10},
    'Team kill': {1: 8, 2: 15},
    'Lost a match': {1: 10, 2: 15},
    'Negative K/D at the end of a match': {1: 10, 2: 15},
    'Death from C4': {1: 10, 2: 15},
    'Death from Kapkan or Frost trap': {1: 15, 2: 25},
    'Death from a Shield Operator': {1: 10, 2: 15},
    'Death from a Sniper': {1: 10, 2: 15},
    'Lose to an Ace (one enemy kills all)': {1: 15, 2: 25},
    'Falling off the map or from a height': {1: 5, 2: 10},
  };

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'exercise_tracker.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE exercises(id INTEGER PRIMARY KEY, exercise TEXT, level INTEGER, date TEXT, count INTEGER)',
        );
      },
      version: 1,
    );
    _loadExerciseCounts(); // Load exercise counts on startup
    _loadDailySummaries(); // Load daily summaries on startup
  }

  Future<void> _loadExerciseCounts() async {
    var result = await _database.rawQuery(
        'SELECT exercise, level, SUM(count) as count FROM exercises WHERE date = ? GROUP BY exercise, level',
        [_today]);

    Map<String, Map<String, int>> exerciseCounts = {};
    for (var row in result) {
      String exercise = row['exercise'] as String;
      int level = row['level'] as int;
      int count = row['count'] as int;

      // Print each exercise name retrieved from the database
      print(
          'Database contains exercise: $exercise, Level: $level, Count: $count');

      if (!exerciseCounts.containsKey(exercise)) {
        exerciseCounts[exercise] = {'level1': 0, 'level2': 0};
      }

      exerciseCounts[exercise]!['level$level'] = count;
    }

    setState(() {
      _exerciseCounts = exerciseCounts;
    });
  }

  Future<void> _loadDailySummaries() async {
    var result = await _database.rawQuery(
        'SELECT date, exercise, level, SUM(count) as total FROM exercises GROUP BY date, exercise, level ORDER BY date DESC');

    Map<String, List<Map<String, dynamic>>> dailySummaries = {};

    for (var row in result) {
      String date = row['date'] as String;
      String exercise = row['exercise'] as String;
      int level = row['level'] as int;
      int count = row['total'] as int;

      if (!dailySummaries.containsKey(date)) {
        dailySummaries[date] = [];
      }

      dailySummaries[date]!.add({
        'exercise': exercise,
        'level': level,
        'count': count,
      });
    }

    setState(() {
      _dailySummaries = dailySummaries;
    });
  }

  Future<void> _incrementExercise(String exercise, int level) async {
    var result = await _database.rawQuery(
        'SELECT * FROM exercises WHERE exercise = ? AND level = ? AND date = ?',
        [exercise, level, _today]);

    if (result.isEmpty) {
      await _database.insert('exercises', {
        'exercise': exercise, // Store the event name, e.g. 'Lost a match'
        'level': level,
        'date': _today,
        'count': 1,
      });
    } else {
      int currentCount = result.first['count'] as int;
      await _database.update(
        'exercises',
        {'count': currentCount + 1},
        where: 'id = ?',
        whereArgs: [result.first['id']],
      );
    }

    _loadExerciseCounts(); // Reload data after increment
    _loadDailySummaries(); // Reload daily summary after increment
  }

  Future<void> _decrementExercise(String exercise, int level) async {
    var result = await _database.rawQuery(
        'SELECT * FROM exercises WHERE exercise = ? AND level = ? AND date = ?',
        [exercise, level, _today]);

    if (result.isNotEmpty) {
      int currentCount = result.first['count'] as int;
      if (currentCount > 0) {
        await _database.update(
          'exercises',
          {'count': currentCount - 1},
          where: 'id = ?',
          whereArgs: [result.first['id']],
        );
      }
    }

    _loadExerciseCounts(); // Reload data after decrement
    _loadDailySummaries(); // Reload daily summary after decrement
  }

  Future<int> _getExerciseCount(String event, int level) async {
    return _exerciseCounts[event]?['level$level'] ?? 0;
  }

  int _calculateTotal(String event, int level, int count) {
    // Print the event and level that are being processed
    print('Looking for event: "$event" at level $level');

    // Check if the event exists in the map
    if (!_exerciseRepetitions.containsKey(event)) {
      print('Event not found in repetitions map: "$event"');
      return 0;
    }

    // Get repetitions per exercise and calculate total
    int repetitionsPerExercise = _exerciseRepetitions[event]?[level] ?? 0;
    int total = repetitionsPerExercise * count;

    // Print out the calculations
    print(
        'Found event: "$event", Level: $level, Count: $count, Reps per Exercise: $repetitionsPerExercise, Total Reps: $total');

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exercise Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Exercises'),
              Tab(text: 'Summary'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _exerciseTable(),
            _dailySummary(),
          ],
        ),
      ),
    );
  }

  Widget _exerciseTable() {
    final exercises = _exerciseDetails.entries.map((entry) {
      return {
        'event': entry.key,
        'level1': entry.value[1],
        'level2': entry.value[2],
      };
    }).toList();

    return ListView.builder(
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        var exercise = exercises[index];
        return Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: Text(
              exercise['event']!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _exerciseRow(exercise['event']!, 1), // Level 1
                const SizedBox(height: 8),
                _exerciseRow(exercise['event']!, 2), // Level 2
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _exerciseRow(String event, int level) {
    // Print the event and level being processed
    print('Rendering exercise row for event: "$event" at Level $level');

    return FutureBuilder<int>(
      future: _getExerciseCount(event, level), // Use event name
      builder: (context, snapshot) {
        int count = snapshot.data ?? 0;
        bool isToday =
            _today == DateTime.now().toIso8601String().substring(0, 10);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                'Level $level: ${_exerciseDetails[event]?[level]}'), // Show level info and exercise
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: isToday
                      ? () => _decrementExercise(event, level)
                      : null, // Disable if not today
                ),
                Text('$count'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: isToday
                      ? () => _incrementExercise(event, level)
                      : null, // Disable if not today
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _dailySummary() {
    return ListView.builder(
      itemCount: _dailySummaries.length,
      itemBuilder: (context, index) {
        String date = _dailySummaries.keys.elementAt(index);
        List<Map<String, dynamic>> exercisesForDate = _dailySummaries[date]!;
        bool isToday = date == _today; // Highlight today's date

        return Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16.0),
            title: Text(
              'Date: $date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isToday ? Colors.blue : Colors.black,
              ),
            ),
            initiallyExpanded: isToday,
            children: [
              ...exercisesForDate.map((exerciseData) {
                String event = exerciseData['exercise'];
                int level = exerciseData['level'];
                int count = exerciseData['count'];
                int total = _calculateTotal(event, level, count);

                // Fetch exercise description from _exerciseDetails
                String description = _exerciseDetails[event]?[level] ??
                    'Description not available';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  title: Text(
                    '$event (Lv $level)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Count: $count',
                          style: const TextStyle(fontSize: 14)),
                      Text('Total Reps: $total',
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
