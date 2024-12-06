import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; 
import 'package:intl/intl.dart';

class ClassSchedulePage extends StatefulWidget {
  const ClassSchedulePage({super.key});

  @override
  _ClassSchedulePageState createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
  }

  // Show dialog for adding/editing a class
  void _showAddClassDialog({Map<String, dynamic>? classInfo, String? classId}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String courseCode = classInfo?['courseCode'] ?? '';
    String className = classInfo?['className'] ?? '';
    DateTime? startTime = classInfo?['startTime']?.toDate();
    DateTime? endTime = classInfo?['endTime']?.toDate();
    List<String> selectedDays = List<String>.from(classInfo?['selectedDays'] ?? []);
    Color classColor = Color(classInfo?['classColor'] ?? Colors.blue.value);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(classInfo == null ? 'Add Class' : 'Edit Class'), //add and edit title
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(labelText: 'Course Code'), //enter course code
                      onChanged: (value) => courseCode = value,
                      controller: TextEditingController(text: courseCode),
                    ),
                    TextField(
                      decoration: InputDecoration(labelText: 'Class Name'), //enter class name
                      onChanged: (value) => className = value,
                      controller: TextEditingController(text: className),
                    ),
                    TextButton(
                      onPressed: () async {
                        final pickedTime = await showTimePicker( //pick date
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startTime ?? DateTime.now()),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            startTime = DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                      child: Text(
                        startTime != null
                            ? 'Start Time: ${DateFormat.jm().format(startTime!)}'
                            : 'Select Start Time',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(endTime ?? DateTime.now()),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            endTime = DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                      child: Text(
                        endTime != null
                            ? 'End Time: ${DateFormat.jm().format(endTime!)}'
                            : 'Select End Time',
                      ),
                    ),
                    Wrap(
                      spacing: 8.0,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                        return ChoiceChip(
                          label: Text(day),
                          selected: selectedDays.contains(day),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                      ListTile(
                        title: Text('Class Color'),
                        trailing: CircleAvatar(backgroundColor: classColor),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Pick a color'),
                                content: BlockPicker(
                                  pickerColor: classColor,
                                  onColorChanged: (color) {
                                    setDialogState(() {
                                      classColor = color;
                                    });
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Done'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (courseCode.isNotEmpty &&
                        className.isNotEmpty &&
                        startTime != null &&
                        endTime != null &&
                        selectedDays.isNotEmpty) {
                      if (classInfo == null) {
                        await _addClass(user.uid, courseCode, className, startTime!, endTime!,
                            selectedDays, classColor.value);
                      } else {
                        await _updateClass(user.uid, classId!, courseCode, className, startTime!,
                            endTime!, selectedDays, classColor.value);
                      }
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(classInfo == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add a new class
  Future<void> _addClass(String userId, String courseCode, String className, DateTime startTime,
      DateTime endTime, List<String> selectedDays, int classColor) async {
    final classRef = await _firestore.collection('users').doc(userId).collection('classes').add({
      'courseCode': courseCode,
      'className': className,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'selectedDays': selectedDays,
      'classColor': classColor,
    });

    await _addRecurringEvents(userId, classRef.id, courseCode, className, startTime, endTime,
        selectedDays, classColor);
  }

 Future<void> _addRecurringEvents(
  String userId,
  String classId,
  String courseCode,
  String className,
  DateTime startTime,
  DateTime endTime,
  List<String> selectedDays,
  int classColor,
) async {
  final dayMapping = {
    'Mon': DateTime.monday,
    'Tue': DateTime.tuesday,
    'Wed': DateTime.wednesday,
    'Thu': DateTime.thursday,
    'Fri': DateTime.friday,
    'Sat': DateTime.saturday,
    'Sun': DateTime.sunday,
  };

  // Get the next 12 weeks of occurrences
  final today = DateTime.now();
  final occurrences = <Map<String, dynamic>>[];

  for (int week = 0; week < 12; week++) {
    for (final day in selectedDays) {
      final targetDay = dayMapping[day];
      if (targetDay == null) continue;

      // Calculate the date for this week's occurrence of the day
      final occurrenceDate = today.add(Duration(days: (targetDay - today.weekday + 7) % 7 + week * 7));
      
      // Create event data for this occurrence
      final eventStartTime = DateTime(
        occurrenceDate.year,
        occurrenceDate.month,
        occurrenceDate.day,
        startTime.hour,
        startTime.minute,
      );
      final eventEndTime = DateTime(
        occurrenceDate.year,
        occurrenceDate.month,
        occurrenceDate.day,
        endTime.hour,
        endTime.minute,
      );

      occurrences.add({
        'classId': classId,
        'eventName': '$courseCode - $className',
        'startTime': Timestamp.fromDate(eventStartTime),
        'endTime': Timestamp.fromDate(eventEndTime),
        'eventColor': classColor,
      });
    }
  }

  // Write all occurrences to Firestore in a batch
  final batch = _firestore.batch();
  final eventsRef = _firestore.collection('users').doc(userId).collection('events');
  for (final occurrence in occurrences) {
    batch.set(eventsRef.doc(), occurrence);
  }

  await batch.commit();
}


  // Update a class
  Future<void> _updateClass(String userId, String classId, String courseCode, String className,
      DateTime startTime, DateTime endTime, List<String> selectedDays, int classColor) async {
    await _firestore.collection('users').doc(userId).collection('classes').doc(classId).update({
      'courseCode': courseCode,
      'className': className,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'selectedDays': selectedDays,
      'classColor': classColor,
    });
    await _addRecurringEvents(
        userId, classId, courseCode, className, startTime, endTime, selectedDays, classColor);
  }

  // Delete a class
  Future<void> _deleteClass(String classId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('classes')
        .doc(classId)
        .delete();
    final events = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .where('classId', isEqualTo: classId)
        .get();
    for (var doc in events.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Schedule')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('classes')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No classes added.'));
          }

          final classes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classInfo = classes[index];
              final classId = classInfo.id;
              final data = classInfo.data() as Map<String, dynamic>;
              final classColor =
                  Color(data['classColor'] ?? Colors.blue.value); // Default to blue if color not set

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                child: ListTile(
                  tileColor: classColor.withOpacity(0.2), // Apply color with transparency
                  title: Text(
                    '${data['courseCode']} - ${data['className']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Time: ${DateFormat.jm().format(data['startTime'].toDate())} - ${DateFormat.jm().format(data['endTime'].toDate())}\n'
                    'Days: ${List<String>.from(data['selectedDays']).join(', ')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black),
                        onPressed: () => _showAddClassDialog(
                          classInfo: data,
                          classId: classId,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteClass(classId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClassDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
