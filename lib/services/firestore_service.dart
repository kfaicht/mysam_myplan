import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add an event with recurrence options and color
  Future<void> addEvent({
    required String userId,
    required String eventName,
    required DateTime eventDate,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool isAllDay = false,
    List<String> reminders = const [],
    int eventColor = 0xFFFFFFFF, // Default to transparent
    String? recurrenceRule, // Recurrence rule for events 
  }) async {
    await _db.collection('users').doc(userId).collection('events').add({
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'description': description ?? '',
      'isAllDay': isAllDay,
      'startTime': isAllDay ? null : Timestamp.fromDate(startTime!),
      'endTime': isAllDay ? null : Timestamp.fromDate(endTime!),
      'reminders': reminders,
      'eventColor': eventColor, // Store event color
      'recurrenceRule': recurrenceRule, 
    });
  }

  // Update an event with new recurrence options and color
  Future<void> updateEvent({
    required String userId,
    required String eventId,
    required String eventName,
    required DateTime eventDate,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool isAllDay = false,
    List<String> reminders = const [],
    int eventColor = 0xFFFFFFFF, // Default to transparent
    String? recurrenceRule, // Recurrence rule for events
  }) async {
    await _db.collection('users').doc(userId).collection('events').doc(eventId).update({
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'description': description ?? '',
      'isAllDay': isAllDay,
      'startTime': isAllDay ? null : Timestamp.fromDate(startTime!),
      'endTime': isAllDay ? null : Timestamp.fromDate(endTime!),
      'reminders': reminders,
      'eventColor': eventColor, // Update event color
      'recurrenceRule': recurrenceRule, // Update recurrence rule if applicable
    });
  }

  // Fetch all events for a specific user
Future<QuerySnapshot> getAllUserEvents(String userId) async {
  try {
    return await _db.collection('users').doc(userId).collection('events').get();
  } catch (e) {
    rethrow; // Rethrow to let the caller handle the error
  }
}

 Future<void> deleteEvent({required String userId, required String eventId}) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  // Add a recurring class with associated events
  Future<void> addClass({
    required String userId,
    required String courseCode,
    required String className,
    String? room,
    required String professor,
    required DateTime startTime,
    required DateTime endTime,
    List<String> selectedDays = const [],
    bool isOnline = false,
    int classColor = 0xFFFFFFFF, // Default to transparent
  }) async {
    DocumentReference classRef = _db.collection('users').doc(userId).collection('classes').doc();
    await classRef.set({
      'courseCode': courseCode,
      'className': className,
      'room': room,
      'professor': professor,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'days': selectedDays,
      'isOnline': isOnline,
      'classColor': classColor,
    });

    // Add recurring events for the class
    await _addRecurringClassEvents(
      userId: userId,
      classId: classRef.id,
      courseCode: courseCode,
      className: className,
      startTime: startTime,
      endTime: endTime,
      selectedDays: selectedDays,
    );
  }

  // Add recurring events for a class
  Future<void> _addRecurringClassEvents({
    required String userId,
    required String classId,
    required String courseCode,
    required String className,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> selectedDays,
  }) async {
    for (String day in selectedDays) {
      DateTime eventDate = _getNextOccurrence(day, startTime);

      // Add event with recurrence rule
      await _db.collection('users').doc(userId).collection('events').add({
        'classId': classId,
        'eventName': '$className ($courseCode)',
        'description': '$className scheduled on $day',
        'startTime': Timestamp.fromDate(eventDate),
        'endTime': Timestamp.fromDate(eventDate.add(endTime.difference(startTime))),
        'isAllDay': false,
        'eventColor': 0xFFFFFFFF, // Default class color
        'recurrenceRule': 'FREQ=WEEKLY;BYDAY=${_getRRuleDay(day)}',
      });
    }
  }

  // Update a class and its recurring events
  Future<void> updateClass({
    required String userId,
    required String classId,
    required String courseCode,
    required String className,
    String? room,
    required String professor,
    required DateTime startTime,
    required DateTime endTime,
    List<String> selectedDays = const [],
    bool isOnline = false,
    int classColor = 0xFFFFFFFF, // Default to transparent
  }) async {
    await _db.collection('users').doc(userId).collection('classes').doc(classId).update({
      'courseCode': courseCode,
      'className': className,
      'room': room,
      'professor': professor,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'days': selectedDays,
      'isOnline': isOnline,
      'classColor': classColor,
    });

    // Update recurring events for the class
    await _updateRecurringClassEvents(
      userId: userId,
      classId: classId,
      courseCode: courseCode,
      className: className,
      startTime: startTime,
      endTime: endTime,
      selectedDays: selectedDays,
    );
  }

  // Update recurring events for a class
  Future<void> _updateRecurringClassEvents({
    required String userId,
    required String classId,
    required String courseCode,
    required String className,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> selectedDays,
  }) async {
    // Delete existing events
    final eventsQuery = await _db
        .collection('users')
        .doc(userId)
        .collection('events')
        .where('classId', isEqualTo: classId)
        .get();
    for (var doc in eventsQuery.docs) {
      await doc.reference.delete();
    }

    // Add updated events
    await _addRecurringClassEvents(
      userId: userId,
      classId: classId,
      courseCode: courseCode,
      className: className,
      startTime: startTime,
      endTime: endTime,
      selectedDays: selectedDays,
    );
  }

  // Delete a class and its recurring events
  Future<void> deleteClass(String userId, String classId) async {
    // Delete the class
    await _db.collection('users').doc(userId).collection('classes').doc(classId).delete();

    // Delete associated events
    final eventsQuery = await _db
        .collection('users')
        .doc(userId)
        .collection('events')
        .where('classId', isEqualTo: classId)
        .get();
    for (var doc in eventsQuery.docs) {
      await doc.reference.delete();
    }
  }

  // Helper method: Get the next occurrence of a day
  DateTime _getNextOccurrence(String day, DateTime startTime) {
    int weekday = _getWeekdayFromString(day);
    DateTime eventDate = startTime;

    while (eventDate.weekday != weekday) {
      eventDate = eventDate.add(Duration(days: 1));
    }
    return eventDate;
  }

  // Helper method: Convert day string to weekday number
  int _getWeekdayFromString(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        throw ArgumentError('Invalid day: $day');
    }
  }

  // Helper method: Convert day string to RRule day abbreviation
  String _getRRuleDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'MO';
      case 'tuesday':
        return 'TU';
      case 'wednesday':
        return 'WE';
      case 'thursday':
        return 'TH';
      case 'friday':
        return 'FR';
      case 'saturday':
        return 'SA';
      case 'sunday':
        return 'SU';
      default:
        throw ArgumentError('Invalid day: $day');
    }
  }
}
