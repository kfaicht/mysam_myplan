import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ToDoList extends StatefulWidget {
  const ToDoList({super.key});

  @override
  _TodoPageState createState() => _TodoPageState();
}

class _TodoPageState extends State<ToDoList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String userId;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _tasks = [];
  List<String> priorityOptions = ['High', 'Medium', 'Low'];
  List<String> estimatedTimeOptions = ['Short', 'Normal', 'Long'];
  List<Map<String, dynamic>> classes = []; // Includes className and color

  @override
  void initState() {
    super.initState();
    userId = _auth.currentUser!.uid;
    _initializeNotifications();
    _loadTasks();
    _loadClasses();
  }

  /// Initialize notifications for tasks.
  Future<void> _initializeNotifications() async {
    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitSettings);

    await _notificationsPlugin.initialize(initializationSettings);

    // Schedule notifications for tasks due today
    _checkTasksDueToday();
  }

  /// Check tasks due today and notify the user.
  Future<void> _checkTasksDueToday() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(Duration(days: 1));

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('dueDate', isLessThan: Timestamp.fromDate(todayEnd))
        .get();

    if (snapshot.docs.isNotEmpty) {
      for (var doc in snapshot.docs) {
        final task = doc.data() as Map<String, dynamic>;
        await _showNotification(task['taskName'], task['dueDate'].toDate());
      }
    }
  }

  /// Show notification for a specific task.
  Future<void> _showNotification(String taskName, DateTime dueDate) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_channel_id',
      'Task Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      taskName.hashCode, // Unique ID for each notification
      'Task Reminder',
      'You have a task "$taskName" due today at ${DateFormat.jm().format(dueDate)}',
      notificationDetails,
    );
  }

  //Load tasks from Firestore and apply sorting logic.
  Future<void> _loadTasks() async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .get();

    setState(() {
      _tasks = snapshot.docs.map((doc) {
        return {
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        };
      }).toList();

      // sorting logic
      _tasks.sort((a, b) {
        // 1. Closest or most overdue date first
        int dateComparison =
            a['dueDate'].toDate().compareTo(b['dueDate'].toDate());
        if (dateComparison != 0) return dateComparison;

        // 2. Time for the day
        int timeComparison =
            a['dueTime'].toDate().compareTo(b['dueTime'].toDate());
        if (timeComparison != 0) return timeComparison;

        // 3. Priority: High > Medium > Low
        int priorityComparison =
            priorityOptions.indexOf(a['priority'] ?? 'Low')
                .compareTo(priorityOptions.indexOf(b['priority'] ?? 'Low'));
        if (priorityComparison != 0) return priorityComparison;

        // 4. Estimated Time: Long > Normal > Short
        int lengthComparison =
            estimatedTimeOptions.indexOf(b['estimatedTime'] ?? 'Short')
                .compareTo(estimatedTimeOptions.indexOf(a['estimatedTime'] ?? 'Short'));
        return lengthComparison;
      });
    });
  }

  /// Load classes from Firestore for dropdown options.
  Future<void> _loadClasses() async {
    QuerySnapshot classSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('classes')
        .get();

    setState(() {
      classes = classSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'className': data['className'],
          'classColor': Color(data['classColor']),
        };
      }).toList();
    });
  }

  Future<void> _deleteTask(String taskId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .delete();

    _loadTasks();
  }

  Future<void> _updateTask(
    String taskId,
    String taskName,
    DateTime dueDate,
    DateTime dueTime,
    bool isComplete,
    String? priority,
    String? estimatedTime,
    String? className,
    Color taskColor,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'taskName': taskName,
      'dueDate': Timestamp.fromDate(dueDate),
      'dueTime': Timestamp.fromDate(dueTime),
      'isComplete': isComplete,
      'priority': priority,
      'estimatedTime': estimatedTime,
      'className': className,
      'taskColor': taskColor.value,
    });

    _loadTasks();
  }

  Future<void> _addTask(
    String taskName,
    DateTime dueDate,
    DateTime dueTime,
    bool isComplete,
    String? priority,
    String? estimatedTime,
    String? className,
    Color taskColor,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add({
      'taskName': taskName,
      'dueDate': Timestamp.fromDate(dueDate),
      'dueTime': Timestamp.fromDate(dueTime),
      'isComplete': isComplete,
      'priority': priority,
      'estimatedTime': estimatedTime,
      'className': className,
      'taskColor': taskColor.value,
    });

    _loadTasks();
  }

  DateTime _convertToCentralTime(DateTime dateTime) {
    return dateTime.toUtc().add(Duration(hours: -6)).toLocal();
  }

  void _showTaskDialog({Map<String, dynamic>? task}) {
    String taskName = task?['taskName'] ?? '';
    DateTime dueDate = task?['dueDate']?.toDate() ?? DateTime.now();
    DateTime dueTime = task?['dueTime']?.toDate() ??
        DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59);
    bool isComplete = task?['isComplete'] ?? false;
    String? priority = task?['priority'];
    String? estimatedTime = task?['estimatedTime'];
    String? className = task?['className'];
    Color taskColor = task != null ? Color(task['taskColor']) : Colors.blue;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task == null ? 'Add Task' : 'Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) {
                        taskName = value;
                      },
                      decoration: InputDecoration(labelText: 'Task Name'),
                      controller: TextEditingController(text: taskName),
                    ),
                    ListTile(
                      title: Text('Due Date'),
                      subtitle: Text('${dueDate.toLocal()}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null && picked != dueDate) {
                          setDialogState(() {
                            dueDate = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text('Due Time'),
                      subtitle: Text(DateFormat.jm().format(dueTime)),
                      trailing: Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                              hour: dueTime.hour, minute: dueTime.minute),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            dueTime = DateTime(dueDate.year, dueDate.month,
                                dueDate.day, pickedTime.hour, pickedTime.minute);
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: InputDecoration(labelText: 'Priority'),
                      onChanged: (newValue) {
                        setDialogState(() {
                          priority = newValue;
                        });
                      },
                      items: priorityOptions
                          .map((priority) => DropdownMenuItem<String>(
                                value: priority,
                                child: Text(priority),
                              ))
                          .toList(),
                    ),
                    DropdownButtonFormField<String>(
                      value: estimatedTime,
                      decoration: InputDecoration(labelText: 'Estimated Time'),
                      onChanged: (newValue) {
                        setDialogState(() {
                          estimatedTime = newValue;
                        });
                      },
                      items: estimatedTimeOptions
                          .map((time) => DropdownMenuItem<String>(
                                value: time,
                                child: Text(time),
                              ))
                          .toList(),
                    ),
                    DropdownButtonFormField<String>(
                      value: className,
                      decoration: InputDecoration(labelText: 'Class'),
                      onChanged: (newValue) {
                        setDialogState(() {
                          className = newValue;
                          if (className != null &&
                              className != 'Personal' &&
                              className != 'None') {
                            final selectedClass = classes.firstWhere(
                                (cls) => cls['className'] == className);
                            taskColor = selectedClass['classColor'];
                          }
                        });
                      },
                      items: [
                        DropdownMenuItem<String>(
                            value: 'None', child: Text('None')),
                        DropdownMenuItem<String>(
                            value: 'Personal', child: Text('Personal')),
                        ...classes.map((cls) => DropdownMenuItem<String>(
                              value: cls['className'],
                              child: Text(cls['className']),
                            )),
                      ],
                    ),
                    if (className == null ||
                        className == 'Personal' ||
                        className == 'None')
                      ListTile(
                        title: Text('Task Color'),
                        trailing: CircleAvatar(backgroundColor: taskColor),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Pick a color'),
                                content: BlockPicker(
                                  pickerColor: taskColor,
                                  onColorChanged: (color) {
                                    setDialogState(() {
                                      taskColor = color;
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
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (taskName.isNotEmpty) {
                      if (task == null) {
                        _addTask(
                          taskName,
                          dueDate,
                          dueTime,
                          isComplete,
                          priority,
                          estimatedTime,
                          className,
                          taskColor,
                        );
                      } else {
                        _updateTask(
                          task['id'],
                          taskName,
                          dueDate,
                          dueTime,
                          isComplete,
                          priority,
                          estimatedTime,
                          className,
                          taskColor,
                        );
                      }

                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(task == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List'),
      ),
      body: _tasks.isEmpty
          ? Center(child: Text('No tasks available.'))
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                DateTime dueDateCST =
                    _convertToCentralTime(task['dueDate'].toDate());
                DateTime dueTimeCST =
                    _convertToCentralTime(task['dueTime'].toDate());
                final taskColor = Color(task['taskColor']);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  color: taskColor.withOpacity(0.2),
                  child: ListTile(
                    title: Text(task['taskName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Due: ${DateFormat('MM/dd/yyyy').format(dueDateCST)} at ${DateFormat.jm().format(dueTimeCST)}'),
                        Text('Priority: ${task['priority'] ?? 'N/A'}'),
                        Text('Class: ${task['className'] ?? 'N/A'}'),
                      ],
                    ),
                    leading: IconButton(
                      icon: Icon(Icons.check),
                      onPressed: () => _deleteTask(task['id']),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _showTaskDialog(task: task),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: Icon(Icons.add),
      ),
    );
  }
}
