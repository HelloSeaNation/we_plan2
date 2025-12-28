import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../event_model.dart';

/// Inspirational quotes for the dashboard screensaver
const List<String> _inspirationalQuotes = [
  "The best time to plant a tree was 20 years ago. The second best time is now.",
  "Your time is limited, don't waste it living someone else's life.",
  "The only way to do great work is to love what you do.",
  "Believe you can and you're halfway there.",
  "In the middle of difficulty lies opportunity.",
  "The future belongs to those who believe in the beauty of their dreams.",
  "It does not matter how slowly you go as long as you do not stop.",
  "Everything you've ever wanted is on the other side of fear.",
  "Success is not final, failure is not fatal: it is the courage to continue that counts.",
  "The only impossible journey is the one you never begin.",
  "What you get by achieving your goals is not as important as what you become.",
  "Life is what happens when you're busy making other plans.",
  "The purpose of our lives is to be happy.",
  "Get busy living or get busy dying.",
  "You only live once, but if you do it right, once is enough.",
  "Many of life's failures are people who did not realize how close they were to success.",
  "The way to get started is to quit talking and begin doing.",
  "If life were predictable it would cease to be life, and be without flavor.",
  "Life is really simple, but we insist on making it complicated.",
  "The greatest glory in living lies not in never falling, but in rising every time we fall.",
  "Your present circumstances don't determine where you can go; they merely determine where you start.",
  "The secret of getting ahead is getting started.",
  "Don't watch the clock; do what it does. Keep going.",
  "Everything has beauty, but not everyone sees it.",
  "The best revenge is massive success.",
  "Life shrinks or expands in proportion to one's courage.",
  "What lies behind us and what lies before us are tiny matters compared to what lies within us.",
  "Happiness is not something ready made. It comes from your own actions.",
  "If you want to live a happy life, tie it to a goal, not to people or things.",
  "The mind is everything. What you think you become.",
];

/// Custom dashboard screensaver that displays clock, date, and upcoming events
class DashboardScreensaver extends StatefulWidget {
  final List<CachedEvent> upcomingEvents;
  final String? backgroundImageUrl;
  final List<String>? backgroundImages; // List of image URLs for slideshow
  final int rotationIntervalSeconds; // Interval between image changes
  final Color accentColor;
  final VoidCallback? onTap;
  final String? weatherLocation; // City name for weather (e.g., "Auckland")

  const DashboardScreensaver({
    super.key,
    required this.upcomingEvents,
    this.backgroundImageUrl,
    this.backgroundImages,
    this.rotationIntervalSeconds = 10,
    this.accentColor = Colors.blue,
    this.onTap,
    this.weatherLocation,
  });

  @override
  State<DashboardScreensaver> createState() => _DashboardScreensaverState();
}

class _DashboardScreensaverState extends State<DashboardScreensaver> {
  late Timer _timer;
  Timer? _imageRotationTimer;
  Timer? _quoteRotationTimer;
  Timer? _weatherRefreshTimer;
  DateTime _currentTime = DateTime.now();
  bool _hasNavigatedBack = false;
  int _currentImageIndex = 0;
  String? _currentBackgroundImage;
  String _currentQuote = '';
  final Random _random = Random();

  // Weather state
  String? _weatherTemp;
  String? _weatherCondition;
  String? _weatherIcon;
  String? _weatherBackgroundUrl;
  String? _weatherFeelsLike;
  String? _weatherHigh;
  String? _weatherLow;
  bool _weatherLoading = false;

  @override
  void initState() {
    super.initState();

    // Set initial background image
    _updateCurrentBackgroundImage();

    // Set initial quote
    _currentQuote = _inspirationalQuotes[_random.nextInt(_inspirationalQuotes.length)];

    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    // Start image rotation if we have multiple images
    _startImageRotation();

    // Start quote rotation every 20 seconds
    _startQuoteRotation();

    // Fetch weather if location is provided
    if (widget.weatherLocation != null && widget.weatherLocation!.isNotEmpty) {
      _fetchWeather();
      // Refresh weather every 30 minutes
      _weatherRefreshTimer = Timer.periodic(
        const Duration(minutes: 30),
        (_) => _fetchWeather(),
      );
    }
  }

  Future<void> _fetchWeather() async {
    if (widget.weatherLocation == null || widget.weatherLocation!.isEmpty) return;

    setState(() => _weatherLoading = true);

    try {
      // Using wttr.in API - free, no API key needed
      final url = 'https://wttr.in/${Uri.encodeComponent(widget.weatherLocation!)}?format=j1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_condition'][0];
        final weatherCode = current['weatherCode'];

        // Get today's forecast for high/low
        final forecast = data['weather']?[0];
        final maxTemp = forecast?['maxtempC'];
        final minTemp = forecast?['mintempC'];

        if (mounted) {
          setState(() {
            _weatherTemp = '${current['temp_C']}°C';
            _weatherCondition = current['weatherDesc'][0]['value'];
            _weatherIcon = _getWeatherEmoji(weatherCode);
            _weatherBackgroundUrl = _getWeatherBackgroundUrl(weatherCode);
            _weatherFeelsLike = current['FeelsLikeC'] != null ? '${current['FeelsLikeC']}°' : null;
            _weatherHigh = maxTemp != null ? '$maxTemp°' : null;
            _weatherLow = minTemp != null ? '$minTemp°' : null;
            _weatherLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      if (mounted) {
        setState(() => _weatherLoading = false);
      }
    }
  }

  String _getWeatherEmoji(String code) {
    final weatherCode = int.tryParse(code) ?? 0;
    if (weatherCode == 113) return '☀️'; // Sunny
    if (weatherCode == 116) return '⛅'; // Partly cloudy
    if (weatherCode == 119 || weatherCode == 122) return '☁️'; // Cloudy
    if (weatherCode >= 176 && weatherCode <= 263) return '🌧️'; // Rain
    if (weatherCode >= 266 && weatherCode <= 299) return '🌧️'; // Light rain
    if (weatherCode >= 302 && weatherCode <= 356) return '🌧️'; // Heavy rain
    if (weatherCode >= 359 && weatherCode <= 395) return '⛈️'; // Thunderstorm
    if (weatherCode >= 200 && weatherCode <= 232) return '⛈️'; // Thunderstorm
    if (weatherCode >= 600 && weatherCode <= 622) return '❄️'; // Snow
    if (weatherCode >= 371 && weatherCode <= 392) return '❄️'; // Snow
    if (weatherCode == 143 || weatherCode == 248 || weatherCode == 260) return '🌫️'; // Fog
    return '🌤️'; // Default
  }

  /// Get weather-themed background image URL based on weather code
  String? _getWeatherBackgroundUrl(String code) {
    final weatherCode = int.tryParse(code) ?? 0;

    // Free high-quality weather background images from Unsplash
    if (weatherCode == 113) {
      // Sunny - bright blue sky
      return 'https://images.unsplash.com/photo-1601297183305-6df142704ea2?w=1920&q=80';
    }
    if (weatherCode == 116) {
      // Partly cloudy
      return 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=1920&q=80';
    }
    if (weatherCode == 119 || weatherCode == 122) {
      // Cloudy/Overcast
      return 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=1920&q=80';
    }
    if ((weatherCode >= 176 && weatherCode <= 356) ||
        (weatherCode >= 359 && weatherCode <= 395)) {
      // Rain/Thunderstorm
      return 'https://images.unsplash.com/photo-1519692933481-e162a57d6721?w=1920&q=80';
    }
    if ((weatherCode >= 600 && weatherCode <= 622) ||
        (weatherCode >= 371 && weatherCode <= 392)) {
      // Snow
      return 'https://images.unsplash.com/photo-1478265409131-1f65c88f965c?w=1920&q=80';
    }
    if (weatherCode == 143 || weatherCode == 248 || weatherCode == 260) {
      // Fog/Mist
      return 'https://images.unsplash.com/photo-1487621167193-286a54d2d73f?w=1920&q=80';
    }
    // Default - nice sky
    return 'https://images.unsplash.com/photo-1517483000871-1dbf64a6e1c6?w=1920&q=80';
  }

  void _startQuoteRotation() {
    _quoteRotationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted) {
          setState(() {
            _currentQuote = _inspirationalQuotes[_random.nextInt(_inspirationalQuotes.length)];
          });
        }
      },
    );
  }

  void _updateCurrentBackgroundImage() {
    if (widget.backgroundImages != null && widget.backgroundImages!.isNotEmpty) {
      _currentBackgroundImage = widget.backgroundImages![_currentImageIndex % widget.backgroundImages!.length];
    } else {
      _currentBackgroundImage = widget.backgroundImageUrl;
    }
  }

  /// Get the effective background URL - weather background takes priority
  String? _getEffectiveBackground() {
    // If weather location is set and we have a weather background, use it
    if (widget.weatherLocation != null &&
        widget.weatherLocation!.isNotEmpty &&
        _weatherBackgroundUrl != null) {
      return _weatherBackgroundUrl;
    }
    // Otherwise fall back to user-provided background
    return _currentBackgroundImage;
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
    _quoteRotationTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    // Use Listener for raw pointer events - more reliable on Raspberry Pi
    return Listener(
      onPointerDown: (_) => _handleTap(),
      onPointerUp: (_) => _handleTap(),
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        onTap: _handleTap,
        onPanDown: (_) => _handleTap(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background image - weather background takes priority, then user images
            if (_getEffectiveBackground() != null)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: SizedBox.expand(
                    key: ValueKey(_getEffectiveBackground()),
                    child: Image.network(
                      _getEffectiveBackground()!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    ),
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

            // Weather widget (top-right corner)
            if (widget.weatherLocation != null && widget.weatherLocation!.isNotEmpty)
              Positioned(
                top: 40,
                right: 32,
                child: SafeArea(
                  child: _buildWeather(),
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
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 24), // Left padding
        // Left side: Clock, Date, Weather, and Quote
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClock(),
              const SizedBox(height: 4),
              _buildDate(),
              const SizedBox(height: 32),
              _buildQuote(),
            ],
          ),
        ),

        // Divider
        Container(
          width: 1,
          height: 250,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          color: Colors.white24,
        ),

        // Right side: Events
        Expanded(
          flex: 2,
          child: _buildEventsSection(),
        ),
        const SizedBox(width: 16), // Right padding
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
        const SizedBox(height: 28),
        _buildQuote(),
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
            fontSize: 144,
            fontWeight: FontWeight.w200,
            color: Colors.white,
            letterSpacing: -4,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              secondsFormat.format(_currentTime),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              amPmFormat.format(_currentTime),
              style: TextStyle(
                fontSize: 36,
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
        fontSize: 32,
        fontWeight: FontWeight.w300,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }

  Widget _buildQuote() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(_currentQuote),
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '"$_currentQuote"',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w300,
            color: Colors.white.withOpacity(0.9),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildWeather() {
    if (_weatherLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    if (_weatherTemp == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _weatherIcon ?? '🌤️',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _weatherTemp!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                  if (_weatherHigh != null && _weatherLow != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '↑$_weatherHigh',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[300],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '↓$_weatherLow',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.lightBlue[300],
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  if (_weatherCondition != null)
                    Text(
                      _weatherCondition!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  if (_weatherFeelsLike != null) ...[
                    Text(
                      ' · Feels $_weatherFeelsLike',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
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
            _buildEventGroup('UPCOMING', upcomingEvents.take(3).toList(), showDate: true),
        ],
      ),
    );
  }

  Widget _buildEventGroup(String title, List<CachedEvent> events, {bool showDate = false}) {
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
        ...events.take(4).map((event) => _buildEventCard(event, showDate: showDate)),
      ],
    );
  }

  Widget _buildEventCard(CachedEvent event, {bool showDate = false}) {
    final eventColor = Color(event.colorValue ?? 0xFF2196F3); // Default to blue
    final timeStr = _formatTime(event.startTimeHour, event.startTimeMinute);
    final hasTime = timeStr.isNotEmpty;

    // Format date for upcoming events (e.g., "Mon 30th")
    String? dateStr;
    if (showDate) {
      final eventDate = _parseDate(event.date);
      final dayFormat = DateFormat('EEE');
      final dayNum = eventDate.day;
      final suffix = _getDaySuffix(dayNum);
      dateStr = '${dayFormat.format(eventDate)} $dayNum$suffix';
    }

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
          // Date badge for upcoming events
          if (showDate && dateStr != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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

  /// Get ordinal suffix for day number (1st, 2nd, 3rd, 4th, etc.)
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
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
