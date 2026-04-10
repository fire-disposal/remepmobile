import 'dart:collection';

import 'package:flutter/material.dart';

import 'app_event.dart';

class EventQuery {
  const EventQuery({this.source, this.level, this.keyword});

  final AppEventSource? source;
  final AppEventLevel? level;
  final String? keyword;
}

class GlobalEventStore extends ChangeNotifier {
  GlobalEventStore({this.maxEvents = 400});

  final int maxEvents;
  final Queue<AppEvent> _events = Queue<AppEvent>();

  List<AppEvent> get events => List.unmodifiable(_events);

  void append(AppEvent event) {
    _events.addFirst(event);
    while (_events.length > maxEvents) {
      _events.removeLast();
    }
    notifyListeners();
  }

  List<AppEvent> query(EventQuery query) {
    return _events.where((event) {
      final sourceOk = query.source == null || event.source == query.source;
      final levelOk = query.level == null || event.level == query.level;
      final keyword = query.keyword?.trim();
      final keywordOk = keyword == null ||
          keyword.isEmpty ||
          event.title.contains(keyword) ||
          event.message.contains(keyword);
      return sourceOk && levelOk && keywordOk;
    }).toList(growable: false);
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }
}
