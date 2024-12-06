import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class CustomAppointment extends Appointment {
  @override
  final String? id;
  final List<String> reminders;

  CustomAppointment({
    required this.id,
    required super.startTime,
    required super.endTime,
    required super.subject,
    super.notes,
    Color color = Colors.blue,
    super.isAllDay,
    super.recurrenceRule,
    this.reminders = const [],
  }) : super(
          color: color.withOpacity(0.8),
        );
}

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  _CalendarState createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  String userId = '';
  late EventDataSource _dataSource;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeFirebaseMessaging();
    _initializeNotifications();
    _getUserId();
    _dataSource = EventDataSource([]); // Initialize with an empty list
    _loadEventsFromFirestore();
  }

  // Initialize Firebase Messaging for Notifications
  void _initializeFirebaseMessaging() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification tapped: ${message.notification?.title}");
    });

    String? token = await _firebaseMessaging.getToken();
    print("FCM Token: $token");
  }

  void _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await _notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        print('Notification payload: ${response.payload}');
        // Notification payload received
      }
    },
  );
}


  // Show Foreground Notifications
  void _showForegroundNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel_id',
      'Default Channel',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    _notificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
    );
  }

  void _getUserId() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
        _firebaseMessaging.subscribeToTopic(userId);
      });
    }
  }

  Future<void> _loadEventsFromFirestore() async {
    try {
      final events = await FirestoreService().getAllUserEvents(userId);
      final calendarEvents = events.docs.map((doc) {
        final eventData = doc.data() as Map<String, dynamic>;
        return CustomAppointment(
          id: doc.id,
          startTime: _convertToLocalTime(_convertToDateTime(eventData['startTime'])),
          endTime: _convertToLocalTime(_convertToDateTime(eventData['endTime'])),
          subject: eventData['eventName'] ?? 'Unnamed Event',
          notes: eventData['description'] ?? '',
          color: Color(eventData['eventColor'] ?? Colors.blue.value),
          isAllDay: eventData['isAllDay'] ?? false,
          recurrenceRule: _validateRecurrenceRule(eventData['recurrenceRule']),
          reminders: List<String>.from(eventData['reminders'] ?? []),
        );
      }).toList();

      setState(() {
        _dataSource.updateAppointments(calendarEvents);
      });
    } catch (e) {
      print("Error loading events: $e");
    }
  }

  DateTime _convertToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else {
      throw Exception('Invalid date type: $value');
    }
  }

  DateTime _convertToLocalTime(DateTime dateTime) {
    return dateTime.toLocal();
  }

  String? _validateRecurrenceRule(String? rule) {
    if (rule == null || rule.isEmpty) return null;

    try {
      final RegExp regex = RegExp(
        r'^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(;INTERVAL=\d+)?(;BYDAY=(MO|TU|WE|TH|FR|SA|SU)(,MO|,TU|,WE|,TH|,FR|,SA|,SU)*)?$',
      );
      if (regex.hasMatch(rule)) {
        return rule;
      } else {
        print("Invalid recurrence rule: $rule");
        return null;
      }
    } catch (e) {
      print("Error validating recurrence rule: $e");
      return null;
    }
  }

void _showAddEventDialog({String? eventId, Map<String, dynamic>? eventData}) {
  final eventNameController = TextEditingController(text: eventData?['eventName'] ?? '');
  final eventDescriptionController = TextEditingController(text: eventData?['description'] ?? '');
  bool isAllDay = eventData?['isAllDay'] ?? false;

  DateTime startTime = _convertToLocalTime(
      _convertToDateTime(eventData?['startTime'] ?? DateTime.now()));
  DateTime endTime = _convertToLocalTime(
      _convertToDateTime(eventData?['endTime'] ?? startTime.add(const Duration(hours: 1))));

  Color eventColor = Color(eventData?['eventColor'] ?? Colors.blue.value);
  String? recurrenceRule = eventData?['recurrenceRule'];
  List<String> reminders = List<String>.from(eventData?['reminders'] ?? []);

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(eventId == null ? 'Add New Event' : 'Edit Event'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Name
                  TextField(
                    controller: eventNameController,
                    decoration: const InputDecoration(hintText: 'Enter event name'),
                  ),
                  const SizedBox(height: 16),
                  // Event Description
                  TextField(
                    controller: eventDescriptionController,
                    decoration: const InputDecoration(hintText: 'Enter event description'),
                  ),
                  const SizedBox(height: 16),
                  // All Day Event Switch
                  SwitchListTile(
                    title: const Text('All Day Event'),
                    value: isAllDay,
                    onChanged: (value) {
                      setDialogState(() {
                        isAllDay = value;
                      });
                    },
                  ),
                  // Date Picker
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('MM/dd/yyyy').format(startTime)),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: startTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setDialogState(() {
                          startTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            startTime.hour,
                            startTime.minute,
                          );
                          endTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            endTime.hour,
                            endTime.minute,
                          );
                        });
                      }
                    },
                  ),
                  // Start Time Picker
                  if (!isAllDay)
                    ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(DateFormat('hh:mm a').format(startTime)),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startTime),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            startTime = DateTime(
                              startTime.year,
                              startTime.month,
                              startTime.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                    ),
                  // End Time Picker
                  if (!isAllDay)
                    ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(DateFormat('hh:mm a').format(endTime)),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(endTime),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            endTime = DateTime(
                              endTime.year,
                              endTime.month,
                              endTime.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                    ),
                  // Task Color Picker
                  ListTile(
                    title: const Text('Event Color'),
                    trailing: CircleAvatar(backgroundColor: eventColor),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Pick Event Color'),
                            content: BlockPicker(
                              pickerColor: eventColor,
                              onColorChanged: (color) {
                                setDialogState(() {
                                  eventColor = color;
                                });
                              },
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Done'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  // Reminder List
                  const SizedBox(height: 10),
                  const Text('Reminders', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8.0,
                    children: reminders.map((reminder) {
                      return Chip(
                        label: Text(reminder),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () {
                          setDialogState(() {
                            reminders.remove(reminder);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  // Add Reminder
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Add Reminder'),
                    items: [
                      '10 minutes before',
                      '30 minutes before',
                      '1 hour before',
                      '1 day before',
                    ]
                        .map((reminder) =>
                            DropdownMenuItem(value: reminder, child: Text(reminder)))
                        .toList(),
                    onChanged: (selected) {
                      if (selected != null && !reminders.contains(selected)) {
                        setDialogState(() {
                          reminders.add(selected);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Recurrence Rule
                  DropdownButtonFormField<String>(
                    value: recurrenceRule,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      const DropdownMenuItem(value: 'FREQ=DAILY', child: Text('Daily')),
                      const DropdownMenuItem(value: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
                          child: Text('Weekly')),
                      const DropdownMenuItem(value: 'FREQ=MONTHLY', child: Text('Monthly')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        recurrenceRule = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Recurrence Rule'),
                  ),
                ],
              ),
            ),
            actions: [
              // Delete Button
              if (eventId != null)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: const Text('Are you sure you want to delete this event?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirestoreService().deleteEvent(userId: userId, eventId: eventId);
                      final deletedEvent = _dataSource.appointments?.cast<CustomAppointment>().firstWhere(
                        (appointment) =>
                          appointment.id == eventId,
                        orElse: () => CustomAppointment(
                          id: null,
                          startTime: DateTime.now(),
                          endTime: DateTime.now(),
                          subject: 'Temporary Event',
                        ), // Avoid exception
                      );

                    if (deletedEvent != null) {
                      setState(() {
                        _dataSource.appointments?.remove(deletedEvent);
                        _dataSource.notifyListeners(
                          CalendarDataSourceAction.remove,
                          [deletedEvent],
                        );
                      });
                    }

                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (eventNameController.text.isNotEmpty) {
                    final newEvent = CustomAppointment(
                      id: eventId,
                      startTime: startTime,
                      endTime: endTime,
                      subject: eventNameController.text,
                      notes: eventDescriptionController.text,
                      color: eventColor,
                      isAllDay: isAllDay,
                      recurrenceRule: recurrenceRule,
                      reminders: reminders,
                    );

                    if (eventId == null) {
                      FirestoreService().addEvent(
                        userId: userId,
                        eventName: newEvent.subject,
                        eventDate: startTime,
                        description: newEvent.notes,
                        startTime: newEvent.startTime,
                        endTime: newEvent.endTime,
                        isAllDay: newEvent.isAllDay,
                        eventColor: newEvent.color.value,
                        recurrenceRule: newEvent.recurrenceRule,
                      );
                      _dataSource.updateAppointments([..._dataSource.appointments!, newEvent]);
                    } else {
                      FirestoreService().updateEvent(
                        userId: userId,
                        eventId: eventId,
                        eventName: newEvent.subject,
                        eventDate: startTime,
                        description: newEvent.notes,
                        startTime: newEvent.startTime,
                        endTime: newEvent.endTime,
                        isAllDay: newEvent.isAllDay,
                        eventColor: newEvent.color.value,
                        recurrenceRule: newEvent.recurrenceRule,
                      );
                      final index = _dataSource.appointments!
                          .indexWhere((e) => e is CustomAppointment && e.id == eventId);
                      if (index != -1) _dataSource.appointments![index] = newEvent;
                    }
                    Navigator.of(context).pop();
                  }
                },
                child: Text(eventId == null ? 'Add Event' : 'Save Changes'),
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
        title: const Text('Calendar'),
        backgroundColor: const Color.fromARGB(255, 70, 93, 123),
      ),
      body: SfCalendar(
        view: CalendarView.month,
        dataSource: _dataSource,
        monthViewSettings: const MonthViewSettings(
          showAgenda: true,
          agendaViewHeight: 150,
          agendaStyle: AgendaStyle(
            appointmentTextStyle: TextStyle(fontSize: 12, color: Colors.black),
          ),
        ),
        onTap: (details) {
          if (details.appointments != null && details.appointments!.isNotEmpty) {
            final appointment = details.appointments!.first;
            if (appointment is CustomAppointment) {
              _showAddEventDialog(eventId: appointment.id, eventData: {
                'eventName': appointment.subject,
                'description': appointment.notes,
                'isAllDay': appointment.isAllDay,
                'startTime': appointment.startTime,
                'endTime': appointment.endTime,
                'eventColor': appointment.color.value,
                'recurrenceRule': appointment.recurrenceRule,
                'reminders': appointment.reminders,
              });
            } else {
              print('Error: Appointment is not a CustomAppointment');
            }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<CustomAppointment> appointments) {
    this.appointments = appointments;
  }

  @override
  CustomAppointment getAppointment(int index) {
    return appointments![index] as CustomAppointment;
  }

  void updateAppointments(List<CustomAppointment> newAppointments) {
    appointments!.clear();
    appointments!.addAll(newAppointments);
    notifyListeners(CalendarDataSourceAction.reset, newAppointments);
  }
} 