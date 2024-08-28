import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exercise Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ExerciseTab(),
    );
  }
}

class ExerciseTab extends StatefulWidget {
  const ExerciseTab({Key? key}) : super(key: key);

  @override
  _ExerciseTabState createState() => _ExerciseTabState();
}

class _ExerciseTabState extends State<ExerciseTab>
    with SingleTickerProviderStateMixin {
  late Database database;
  late TabController _tabController;

  final List<Map<String, dynamic>> exerciseTable = [
    {"event": "Death in a round", "level1": "2 Pushups", "level2": "5 Pushups"},
    {"event": "Negative K/D", "level1": "10 Squats", "level2": "15 Squats"},
    {"event": "Lost a match", "level1": "15 Situps", "level2": "20 Situps"},
    {
      "event": "Death from C4",
      "level1": "5 Jumping Jacks",
      "level2": "10 Jumping Jacks"
    },
    {
      "event": "Death from Shield Operator",
      "level1": "5 Pushups",
      "level2": "10 Pushups"
    },
    {
      "event": "Death from Sniper",
      "level1": "10 Mountain Climbers",
      "level2": "15 Mountain Climbers"
    },
    {"event": "Choked a 1v1", "level1": "10 Burpees", "level2": "15 Burpees"},
    {
      "event": "Falling",
      "level1": "5 Bicycle Crunches",
      "level2": "10 Bicycle Crunches"
    },
    {
      "event": "Dying to Kapkan or Frost",
      "level1": "20 Sec Plank",
      "level2": "30 Sec Plank"
    },
    {"event": "Team Kill", "level1": "10 Squats", "level2": "20 Squats"},
  ];

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _initDatabase() async {
    print('Initializing database...');
    database = await openDatabase(
      join(await getDatabasesPath(), 'exercise_tracker.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE exercise_counts(id INTEGER PRIMARY KEY, event TEXT, level1_count INTEGER, level2_count INTEGER, date TEXT)",
        );
      },
      version: 1,
    );
    print('Database initialized');

    await _populateDatabase();
    await printDatabase();

    setState(() {});
  }

  Future<void> _populateDatabase() async {
    for (var entry in exerciseTable) {
      await database?.insert(
        'exercise_counts',
        {
          'event': entry['event'],
          'level1_count': 0,
          'level2_count': 0,
          'date': DateTime.now()
              .toIso8601String()
              .split('T')[0], // Default to today
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> printDatabase() async {
    final List<Map<String, dynamic>> allRows =
        await database?.query('exercise_counts') ?? [];
    for (var row in allRows) {
      print(row);
    }
  }

  Future<void> _incrementCounter(String event, String level) async {
    if (database == null) return; // Check if the database is initialized

    final List<Map<String, dynamic>> result = await database!.query(
      'exercise_counts',
      where: "event = ? AND date = ?",
      whereArgs: [event, DateTime.now().toIso8601String().split('T')[0]],
    );

    if (result.isEmpty)
      return; // Handle the case where no matching row is found

    final Map<String, dynamic> row = result.first;

    int newLevel1Count = row['level1_count'];
    int newLevel2Count = row['level2_count'];

    if (level == 'level1') {
      newLevel1Count++;
    } else {
      newLevel2Count++;
    }

    await database!.update(
      'exercise_counts',
      {
        'level1_count': newLevel1Count,
        'level2_count': newLevel2Count,
      },
      where: "event = ? AND date = ?",
      whereArgs: [event, DateTime.now().toIso8601String().split('T')[0]],
    );

    setState(() {});
  }

  Future<void> _decrementCounter(String event, String level) async {
    if (database == null) return; // Check if the database is initialized

    final List<Map<String, dynamic>> result = await database!.query(
      'exercise_counts',
      where: "event = ? AND date = ?",
      whereArgs: [event, DateTime.now().toIso8601String().split('T')[0]],
    );

    if (result.isEmpty)
      return; // Handle the case where no matching row is found

    final Map<String, dynamic> row = result.first;

    int newLevel1Count = row['level1_count'];
    int newLevel2Count = row['level2_count'];

    if (level == 'level1') {
      newLevel1Count = (newLevel1Count > 0) ? newLevel1Count - 1 : 0;
    } else {
      newLevel2Count = (newLevel2Count > 0) ? newLevel2Count - 1 : 0;
    }

    await database!.update(
      'exercise_counts',
      {
        'level1_count': newLevel1Count,
        'level2_count': newLevel2Count,
      },
      where: "event = ? AND date = ?",
      whereArgs: [event, DateTime.now().toIso8601String().split('T')[0]],
    );

    setState(() {});
  }

  Future<int> _getCounter(String event, String level) async {
    final Map<String, dynamic> row = await database.query(
      'exercise_counts',
      where: "event = ? AND date = ?",
      whereArgs: [event, DateTime.now().toIso8601String().split('T')[0]],
    ).then((result) => result.first);

    return level == 'level1' ? row['level1_count'] : row['level2_count'];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exercise Tracker'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Exercise Table'),
              Tab(text: 'Daily Summary'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            FutureBuilder(
              future: _getTableData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: exerciseTable.length,
                  itemBuilder: (context, index) {
                    String event = exerciseTable[index]['event'];
                    String level1 = exerciseTable[index]['level1'];
                    String level2 = exerciseTable[index]['level2'];

                    return Card(
                      child: ListTile(
                        title: Text(event),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(level1),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () async {
                                        await _decrementCounter(
                                            event, 'level1');
                                      },
                                      icon: const Icon(Icons.remove),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await _incrementCounter(
                                            event, 'level1');
                                      },
                                      child: FutureBuilder(
                                        future: _getCounter(event, 'level1'),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const CircularProgressIndicator();
                                          }
                                          return Text('+ ${snapshot.data}');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(level2),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () async {
                                        await _decrementCounter(
                                            event, 'level2');
                                      },
                                      icon: const Icon(Icons.remove),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await _incrementCounter(
                                            event, 'level2');
                                      },
                                      child: FutureBuilder(
                                        future: _getCounter(event, 'level2'),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const CircularProgressIndicator();
                                          }
                                          return Text('+ ${snapshot.data}');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            FutureBuilder(
              future: _getDailySummary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data as List<Map<String, dynamic>>;
                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return ListTile(
                      title: Text(item['event']),
                      subtitle: Text(
                        'Level 1: ${item['level1_count']}, Level 2: ${item['level2_count']}',
                      ),
                      trailing: Text(item['date']),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getTableData() async {
    return database.query('exercise_counts',
        where: "date = ?",
        whereArgs: [DateTime.now().toIso8601String().split('T')[0]]);
  }

  Future<List<Map<String, dynamic>>> _getDailySummary() async {
    return database.query('exercise_counts', groupBy: 'date');
  }
}
