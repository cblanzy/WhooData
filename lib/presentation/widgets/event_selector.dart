import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/data/providers/database_providers.dart';
import 'package:whoodata/presentation/widgets/add_event_dialog.dart';

/// Smart event selector widget
/// - When tapped (not typing): Shows modal with all events, today's events at top
/// - When typing: Shows autocomplete dropdown
class EventSelector extends ConsumerStatefulWidget {
  const EventSelector({
    required this.controller,
    this.onSelected,
    super.key,
  });

  final TextEditingController controller;
  final void Function(String eventName)? onSelected;

  @override
  ConsumerState<EventSelector> createState() => _EventSelectorState();
}

class _EventSelectorState extends ConsumerState<EventSelector> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _showEventPicker() async {
    final eventsDao = ref.read(eventsDaoProvider);
    final allEvents = await eventsDao.getAllEvents();
    final todaysEvents = await eventsDao.getTodaysEvents();

    if (!mounted) return;

    final selected = await showModalBottomSheet<Event>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _EventPickerSheet(
            allEvents: allEvents,
            todaysEvents: todaysEvents,
            scrollController: scrollController,
          );
        },
      ),
    );

    if (selected != null) {
      widget.controller.text = selected.name;
      widget.onSelected?.call(selected.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(allEventsProvider);

    return eventsAsync.when(
      data: (events) {
        return Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            final matchingEvents = events
                .map((e) => e.name)
                .where(
                  (name) => name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                )
                .toList();

            // Add "Create Event" option if no exact match
            final exactMatch = matchingEvents.any(
              (name) => name.toLowerCase() == textEditingValue.text.toLowerCase(),
            );
            if (!exactMatch && textEditingValue.text.isNotEmpty) {
              matchingEvents.add('+ Create Event: ${textEditingValue.text}');
            }
            return matchingEvents;
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (selection) async {
            // Check if user selected the "Create Event" option
            if (selection.startsWith('+ Create Event: ')) {
              final eventName = selection.substring('+ Create Event: '.length);
              final createdEventName = await showDialog<String>(
                context: context,
                builder: (context) => AddEventDialog(initialName: eventName),
              );
              if (createdEventName != null) {
                widget.controller.text = createdEventName;
                widget.onSelected?.call(createdEventName);
              }
            } else {
              widget.controller.text = selection;
              widget.onSelected?.call(selection);
            }
          },
          fieldViewBuilder: (context, controller, focusNode, _) {
            // Sync with external controller
            widget.controller.text = controller.text;

            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Event',
                border: const OutlineInputBorder(),
                hintText: 'Tap to select or type to search',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    // Hide keyboard and show modal picker
                    focusNode.unfocus();
                    _showEventPicker();
                  },
                ),
              ),
              onTap: () {
                // If field is empty when tapped, show modal picker
                if (controller.text.isEmpty) {
                  focusNode.unfocus();
                  _showEventPicker();
                }
              },
            );
          },
        );
      },
      loading: () => TextField(
        controller: widget.controller,
        decoration: const InputDecoration(
          labelText: 'Event',
          border: OutlineInputBorder(),
        ),
      ),
      error: (_, __) => TextField(
        controller: widget.controller,
        decoration: const InputDecoration(
          labelText: 'Event',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _EventPickerSheet extends StatefulWidget {
  const _EventPickerSheet({
    required this.allEvents,
    required this.todaysEvents,
    required this.scrollController,
  });

  final List<Event> allEvents;
  final List<Event> todaysEvents;
  final ScrollController scrollController;

  @override
  State<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<_EventPickerSheet> {
  String _searchQuery = '';

  List<Event> get _filteredEvents {
    if (_searchQuery.isEmpty) {
      return widget.allEvents;
    }
    return widget.allEvents
        .where(
          (event) =>
              event.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<Event> get _todaysFilteredEvents {
    return widget.todaysEvents
        .where(
          (event) =>
              _searchQuery.isEmpty ||
              event.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Select Event',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search events',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                autofocus: true,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Event list
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            children: [
              // Today's events section
              if (_todaysFilteredEvents.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.today,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Today\'s Events',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                ..._todaysFilteredEvents.map(
                  (event) => ListTile(
                    leading: Icon(
                      Icons.event,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(event.name),
                    subtitle: Text(dateFormat.format(event.eventDate)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(event),
                  ),
                ),
                const Divider(),
              ],

              // Other events section
              if (_filteredEvents.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    _todaysFilteredEvents.isEmpty
                        ? 'All Events'
                        : 'Other Events',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ..._filteredEvents
                    .where((event) => !_todaysFilteredEvents.contains(event))
                    .map(
                      (event) => ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(event.name),
                        subtitle: Text(dateFormat.format(event.eventDate)),
                        onTap: () => Navigator.of(context).pop(event),
                      ),
                    ),
              ],

              // No events message
              if (_filteredEvents.isEmpty && _searchQuery.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No events found',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            final eventName = await showDialog<String>(
                              context: context,
                              builder: (context) => AddEventDialog(
                                initialName: _searchQuery,
                              ),
                            );
                            if (eventName != null && mounted) {
                              // Pop with the created event name
                              Navigator.of(context).pop(Event(
                                id: '',
                                name: eventName,
                                eventDate: DateTime.now(),
                                createdAt: DateTime.now(),
                              ));
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: Text('Create "$_searchQuery"'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Create New Event button at bottom
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final eventName = await showDialog<String>(
                      context: context,
                      builder: (context) => AddEventDialog(
                        initialName: _searchQuery.isNotEmpty ? _searchQuery : null,
                      ),
                    );
                    if (eventName != null && mounted) {
                      // Pop with the created event name
                      Navigator.of(context).pop(Event(
                        id: '',
                        name: eventName,
                        eventDate: DateTime.now(),
                        createdAt: DateTime.now(),
                      ));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Event'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
