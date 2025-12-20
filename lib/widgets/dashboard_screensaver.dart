import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../event_model.dart';

/// Custom dashboard screensaver that displays clock, date, and upcoming events
class DashboardScreensaver extends StatefulWidget {
  final List<CachedEvent> upcomingEvents;
  final String? backgroundImageUrl;
  final List<String>? backgroundImages; // List of image URLs for slideshow
  final int rotationIntervalSeconds; // Interval between image changes
  final Color accentColor;
  final VoidCallback? onTap;

  const DashboardScreensaver({
    super.key,
    required this.upcomingEvents,
    this.backgroundImageUrl,
    this.backgroundImages,
    this.rotationIntervalSeconds = 10,
    this.accentColor = Colors.blue,
    this.onTap,
  });

  @override
  State<DashboardScreensaver> createState() => _DashboardScreensaverState();
}

class _DashboardScreensaverState extends State<DashboardScreensaver> {
  late Timer _timer;
  Timer? _imageRotationTimer;
  DateTime _currentTime = DateTime.now();
  bool _hasNavigatedBack = false;
  int _currentImageIndex = 0;
  String? _currentBackgroundImage;

  @override
  void initState() {
    super.initState();

    // Set initial background image
    _updateCurrentBackgroundImage();

    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    // Start image rotation if we have multiple images
    _startImageRotation();
  }

  void _updateCurrentBackgroundImage() {
    if (widget.backgroundImages != null && widget.backgroundImages!.isNotEmpty) {
      _currentBackgroundImage = widget.backgroundImages![_currentImageIndex % widget.backgroundImages!.length];
    } else {
      _currentBackgroundImage = widget.backgroundImageUrl;
    }
  }

  void _startImageRotation() {
    if (widget.backgroundImages == null || widget.backgroundImages!.length <= 1) return;

    _imageRotationTimer = Timer.periodic(
      Duration(seconds: widget.rotationIntervalSeconds),
      (_) {
        if (mounted) {
          setState(() {
            _currentImageIndex = (_currentImageIndex + 1) % widget.backgroundImages!.length;
            _currentBackgroundImage = widget.backgroundImages![_currentImageIndex];
          });
        }
      },
    );
  }

  void _handleTap() {
    if (_hasNavigatedBack) return;
    _hasNavigatedBack = true;
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _timer.cancel();
    _imageRotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return GestureDetector(
      onTap: _handleTap,
      onPanDown: (_) => _handleTap(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background image (if provided) - supports rotation
            if (_currentBackgroundImage != null &&
                _currentBackgroundImage!.isNotEmpty)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: Image.network(
                    _currentBackgroundImage!,
                    key: ValueKey(_currentBackgroundImage),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black),
                  ),
                ),
              ),

            // Gradient overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: isLandscape
                    ? _buildLandscapeLayout()
                    : _buildPortraitLayout(),
              ),
            ),

            // Tap hint (bottom)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: _FadingHint(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side: Clock and Date
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClock(),
              const SizedBox(height: 8),
              _buildDate(),
            ],
          ),
        ),

        // Divider
        Container(
          width: 1,
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          color: Colors.white24,
        ),

        // Right side: Events
        Expanded(
          flex: 2,
          child: _buildEventsSection(),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        _buildClock(),
        const SizedBox(height: 8),
        _buildDate(),
        const Spacer(flex: 1),
        _buildEventsSection(),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildClock() {
    final timeFormat = DateFormat('h:mm');
    final secondsFormat = DateFormat('ss');
    final amPmFormat = DateFormat('a');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          timeFormat.format(_currentTime),
          style: const TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w200,
            color: Colors.white,
            letterSpacing: -2,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              secondsFormat.format(_currentTime),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              amPmFormat.format(_currentTime),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDate() {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');

    return Text(
      dateFormat.format(_currentTime),
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w300,
        color: Colors.white.withOpacity(0.8),
      ),
    );
  }

  /// Parse ISO8601 date string to DateTime
  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Format time from hour and minute
  String _formatTime(int? hour, int? minute) {
    if (hour == null) return '';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = (minute ?? 0).toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Widget _buildEventsSection() {
    // Get events for today and tomorrow
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    final todayEvents = widget.upcomingEvents.where((e) {
      final eventDate = _parseDate(e.date);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isAtSameMomentAs(today);
    }).toList();

    final tomorrowEvents = widget.upcomingEvents.where((e) {
      final eventDate = _parseDate(e.date);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isAtSameMomentAs(tomorrow);
    }).toList();

    final upcomingEvents = widget.upcomingEvents.where((e) {
      final eventDate = _parseDate(e.date);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isAfter(tomorrow) && eventDay.isBefore(dayAfter.add(const Duration(days: 5)));
    }).toList();

    if (todayEvents.isEmpty && tomorrowEvents.isEmpty && upcomingEvents.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'UPCOMING',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.accentColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No upcoming events',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (todayEvents.isNotEmpty) ...[
            _buildEventGroup('TODAY', todayEvents),
            const SizedBox(height: 20),
          ],
          if (tomorrowEvents.isNotEmpty) ...[
            _buildEventGroup('TOMORROW', tomorrowEvents),
            const SizedBox(height: 20),
          ],
          if (upcomingEvents.isNotEmpty)
            _buildEventGroup('UPCOMING', upcomingEvents.take(3).toList()),
        ],
      ),
    );
  }

  Widget _buildEventGroup(String title, List<CachedEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.accentColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        ...events.take(4).map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildEventCard(CachedEvent event) {
    final eventColor = Color(event.colorValue ?? 0xFF2196F3); // Default to blue
    final timeStr = _formatTime(event.startTimeHour, event.startTimeMinute);
    final hasTime = timeStr.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: eventColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasTime)
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (event.deviceName != null && event.deviceName!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: eventColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                event.deviceName!,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A hint that fades out after a few seconds
class _FadingHint extends StatefulWidget {
  @override
  State<_FadingHint> createState() => _FadingHintState();
}

class _FadingHintState extends State<_FadingHint> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _opacity = 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(seconds: 2),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Tap anywhere to return',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
