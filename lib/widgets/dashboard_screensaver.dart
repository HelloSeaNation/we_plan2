import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../event_model.dart';

/// Quotes from Mel Robbins' "The Let Them Theory"
const List<String> _inspirationalQuotes = [
  // Core Let Them quotes
  "Let them. And watch how your life changes.",
  "Let them judge you. Let them misunderstand you. Let them gossip about you.",
  "When you stop trying to control everyone around you, you free yourself.",
  "Let them walk away. Anyone who wants to leave, let them.",
  "Your peace is more important than proving your point.",
  "Let them have their opinion. Their opinion is not your responsibility.",
  "You cannot control what other people do, but you can control how you respond.",
  "Let them be mad. Let them be disappointed. That's their choice.",
  "Stop abandoning yourself to try to hold on to someone else.",
  "Let them think what they want to think. You know the truth.",
  "The moment you stop chasing, you start attracting.",
  "Let them go. If they come back, they're yours. If they don't, they never were.",
  "Your energy is precious. Stop wasting it on people who don't deserve it.",
  "Let them talk. While they're busy talking, you're busy growing.",
  "Not everyone is meant to stay in your life forever. Let them go.",
  "You teach people how to treat you by what you allow.",
  "Let them doubt you. Then show them what you're capable of.",
  "Stop explaining yourself. Those who matter don't need it, and those who need it don't matter.",
  "Let them make their own mistakes. It's not your job to save everyone.",
  "The best thing you can do for yourself is stop forcing things that aren't meant to be.",
  "Let them see you walk away. Some lessons are taught by absence.",
  "Your worth is not determined by someone's inability to see it.",
  "Let them choose someone else. You'll find someone who chooses you.",
  "Stop holding on to what hurts. Let it go and let it heal.",
  "Let them underestimate you. That's their first mistake.",
  "You can't pour from an empty cup. Take care of yourself first.",
  "Let them live their life. You focus on living yours.",
  "The right people will find you when you stop looking in the wrong places.",
  "Let them go through their own journey. You focus on yours.",
  "Sometimes letting go is the strongest thing you can do.",

  // Boundaries and self-respect
  "Let them not invite you. You don't want to be somewhere you're not wanted.",
  "Let them ignore your text. The right people will always make time for you.",
  "Let them cancel plans. Their absence creates space for better things.",
  "You are not responsible for other people's happiness.",
  "Let them spread rumors. The truth always reveals itself.",
  "Your silence is powerful. Let them wonder.",
  "Let them move on. You were never meant to hold anyone hostage.",
  "Stop shrinking yourself to fit places you've outgrown.",
  "Let them not understand your growth. It wasn't meant for them to understand.",
  "The less you respond to negativity, the more peaceful your life becomes.",
  "Let them take credit. Your integrity is worth more than recognition.",
  "Stop waiting for apologies you'll never receive. Heal anyway.",
  "Let them forget your birthday. Those who care will always remember.",
  "You don't need closure from someone who doesn't respect you.",
  "Let them think they won. You know what you walked away with - your peace.",
  "Stop proving yourself to people who are committed to misunderstanding you.",
  "Let them be intimidated by your growth. Keep growing anyway.",
  "Your healing doesn't need their permission or participation.",
  "Let them call you difficult. Boundaries often look that way to those who benefit from you having none.",
  "The best apology is changed behavior. Let them show you, not tell you.",
  "Let them miss you. Absence teaches value better than presence ever could.",
  "Stop dimming your light because it blinds people who refuse to grow.",
  "Let them think you're too much. The right people will never have enough of you.",
  "You don't owe anyone an explanation for protecting your peace.",
  "Let them have the last word. You have the last laugh - a peaceful life.",
  "Stop begging people to stay. Let them go and watch who comes back.",
  "Your vibe attracts your tribe. Let the wrong ones self-select out.",
  "Let them be surprised by your success. Work in silence.",
  "Not everyone deserves access to you. Let them earn it.",
  "Let them question your choices. You don't need their approval to live your life.",

  // Relationships and letting go
  "Let them love you the wrong way. Then let them go find someone else to love wrong.",
  "Let them keep their version of you. You know who you really are.",
  "Stop trying to fix people who don't want to be fixed.",
  "Let them blame you. Their accountability is not your burden.",
  "You don't have to attend every argument you're invited to.",
  "Let them be upset. Their emotions are theirs to manage.",
  "Stop setting yourself on fire to keep others warm.",
  "Let them say you've changed. Growth looks like change to those who haven't.",
  "You can't make someone value you by giving them more.",
  "Let them feel how they feel. Feelings aren't facts.",
  "Stop explaining your boundaries. 'No' is a complete sentence.",
  "Let them find out without you. Some experiences aren't meant to be shared.",
  "Your loyalty should be earned, not given freely to everyone.",
  "Let them believe their own lies. The truth doesn't need defending.",
  "Stop trying to be everything to everyone. Be something to yourself first.",
  "Let them see your boundaries as walls. They're actually doors with locks.",
  "You can love people and still let them go.",
  "Let them think you're cold. You're just no longer burning yourself to keep them warm.",
  "Stop carrying grudges. Let them go and feel the weight lift.",
  "Let them wonder why you're so happy. You don't owe anyone your story.",

  // Self-worth and confidence
  "Let them overlook you. The right eyes will always find you.",
  "Stop apologizing for being yourself.",
  "Let them be uncomfortable with your confidence. That's their problem.",
  "You were not born to be liked by everyone. Let them dislike you.",
  "Let them think you're lucky. They don't see the work.",
  "Stop minimizing your accomplishments to make others comfortable.",
  "Let them compare you to others. You're not in competition with anyone.",
  "Your value doesn't decrease based on someone's inability to see your worth.",
  "Let them call you selfish for choosing yourself.",
  "Stop seeking validation from people who never validate themselves.",
  "Let them misinterpret your kindness. Keep being kind anyway.",
  "You are allowed to outgrow anyone, including the old version of yourself.",
  "Let them be jealous. Success is the best response.",
  "Stop asking for permission to be great.",
  "Let them doubt your dreams. Dreams don't need witnesses.",
  "You don't have to prove your pain to anyone.",
  "Let them think you have it easy. They don't know your battles.",
  "Stop lowering your standards to accommodate those who refuse to raise theirs.",
  "Let them label you. Labels are for packages, not people.",
  "You are not asking for too much. You're asking the wrong people.",

  // Peace and healing
  "Let them trigger you. Then do the work to heal that wound.",
  "Stop revisiting places and people that broke you.",
  "Let them keep their apologies. Heal without them.",
  "Peace is not found in controlling others. It's found in letting them be.",
  "Let them think peace means weakness. You know better.",
  "Stop expecting different results from people who keep showing you who they are.",
  "Let them live with the consequences of losing you.",
  "Your peace is non-negotiable. Let them understand that.",
  "Let them wonder what happened to the old you. That version had to leave.",
  "Stop watering dead flowers. Some things aren't meant to grow.",
  "Let them be angry at your peace. It disturbs their chaos.",
  "You don't have to be friends with everyone you forgive.",
  "Let them hold onto the past. Your future doesn't need their baggage.",
  "Stop giving power to those who misuse it.",
  "Let them think silence is agreement. Sometimes silence is just peace.",
  "Your serenity is your superpower. Guard it fiercely.",
  "Let them create drama. You stay in your calm.",
  "Stop chasing closure. Sometimes the door closes and that's it.",
  "Let them write the ending. You're already in the next chapter.",
  "Peace costs you people, places, and things. It's still worth it.",

  // Growth and change
  "Let them stay the same while you evolve.",
  "Stop apologizing for growing into someone others can't recognize.",
  "Let them mourn the old you. You're busy building the new one.",
  "Change isn't betrayal. Let them adjust or let them go.",
  "Let them be confused by your transformation.",
  "Stop waiting for everyone to be ready. Start anyway.",
  "Let them think change is impossible. Keep proving them wrong.",
  "Your growth will cost you relationships. Grow anyway.",
  "Let them stay comfortable. Comfort zones are dream killers.",
  "Stop looking back. You're not going that way.",
  "Let them resist your evolution. Evolve anyway.",
  "New levels bring new devils. Let them reveal themselves.",
  "Let them think the butterfly misses being a caterpillar.",
  "Stop explaining your plot twists. Not everyone needs to understand your story.",
  "Let them keep the old memories. You're making new ones.",
  "Growth is lonely. Let them stay behind if they must.",
  "Let them question your path. Your journey isn't for them to understand.",
  "Stop waiting for a sign. You are the sign.",
  "Let them call your dreams unrealistic. Dreamers change the world.",
  "Your potential is not determined by others' limitations.",

  // Strength and resilience
  "Let them see you fall. More importantly, let them see you rise.",
  "Stop hiding your scars. They're proof you survived.",
  "Let them think you're broken. Broken crayons still color.",
  "Strength isn't about not falling. It's about getting back up.",
  "Let them doubt your comeback. Surprise them.",
  "Stop explaining your setbacks. They're setups for comebacks.",
  "Let them count you out. Underdogs often win.",
  "Your struggles don't define you. How you rise does.",
  "Let them see your tears. Vulnerability takes courage.",
  "Stop pretending to be okay. It's okay to not be okay.",
  "Let them think they broke you. Watch yourself rebuild.",
  "Rock bottom can be a solid foundation. Build from there.",
  "Let them see you struggle. They'll appreciate your success more.",
  "Stop carrying pain that isn't yours.",
  "Let them throw stones. Use them to build your empire.",
  "Your trials are training for your testimony.",
  "Let them watch your resurrection. Some things must die to live again.",
  "Stop surviving when you were born to thrive.",
  "Let them see your fight. Warriors are made in battle.",
  "Every storm runs out of rain. Let them watch you weather it.",

  // Moving forward
  "Let them stay stuck in yesterday while you chase tomorrow.",
  "Stop mourning versions of people who never existed.",
  "Let them replay the past. You're pressing play on the future.",
  "Forward is the only direction that matters.",
  "Let them dwell on what was. You focus on what will be.",
  "Stop giving yesterday the power to ruin today.",
  "Let them live in regret. You live in gratitude.",
  "The rear-view mirror is small for a reason. Let them stay behind you.",
  "Let them question your direction. You know your destination.",
  "Stop rewriting history. Write new stories instead.",
  "Let them keep score. Life isn't a competition.",
  "Your next chapter can be anything. Let them watch you write it.",
  "Let them see you close doors. Watch what opens.",
  "Stop trying to go back. You've already graduated from that class.",
  "Let them reminisce. You revolutionize.",
  "New beginnings are often disguised as painful endings.",
  "Let them stay in the same place. Your feet were made for walking.",
  "Stop circling the same mountain. Cross to the other side.",
  "Let them replay the same story. Yours has new seasons.",
  "The best is yet to come. Let them watch it unfold.",

  // Self-love and care
  "Let them call it selfish. Self-love is survival.",
  "Stop putting yourself last on your own list.",
  "Let them think you're too focused on yourself. You are your best investment.",
  "Loving yourself isn't vanity. It's sanity.",
  "Let them struggle to love you. Love yourself harder.",
  "Stop seeking love you won't give yourself.",
  "Let them think self-care is lazy. Rest is productive.",
  "Your relationship with yourself sets the tone for all others.",
  "Let them not prioritize you. Prioritize yourself.",
  "Stop waiting to be chosen. Choose yourself.",
  "Let them forget you exist. Remember that you matter.",
  "Self-respect is the foundation. Build on it.",
  "Let them take you for granted. Never take yourself for granted.",
  "Stop abandoning yourself to be accepted by others.",
  "Let them leave. Your own company is good enough.",
  "The most important relationship is the one you have with yourself.",
  "Let them not see your value. Know it anyway.",
  "Stop breaking your own heart by expecting too much from others.",
  "Let them not celebrate you. Throw your own party.",
  "You are enough. Let them disagree.",
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
  String? _weatherCode; // Store weather code for icon lookup
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
            _weatherCode = weatherCode; // Store code for icon lookup
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

  /// Get weather icon data based on weather code
  IconData _getWeatherIcon(String code) {
    final weatherCode = int.tryParse(code) ?? 0;
    if (weatherCode == 113) return Icons.wb_sunny_rounded; // Sunny
    if (weatherCode == 116) return Icons.wb_cloudy; // Partly cloudy
    if (weatherCode == 119 || weatherCode == 122) return Icons.cloud; // Cloudy
    if (weatherCode >= 176 && weatherCode <= 263) return Icons.grain; // Rain
    if (weatherCode >= 266 && weatherCode <= 299) return Icons.grain; // Light rain
    if (weatherCode >= 302 && weatherCode <= 356) return Icons.beach_access; // Heavy rain (umbrella)
    if (weatherCode >= 359 && weatherCode <= 395) return Icons.thunderstorm; // Thunderstorm
    if (weatherCode >= 200 && weatherCode <= 232) return Icons.thunderstorm; // Thunderstorm
    if (weatherCode >= 600 && weatherCode <= 622) return Icons.ac_unit; // Snow
    if (weatherCode >= 371 && weatherCode <= 392) return Icons.ac_unit; // Snow
    if (weatherCode == 143 || weatherCode == 248 || weatherCode == 260) return Icons.foggy; // Fog
    return Icons.wb_sunny_rounded; // Default

  }

  /// Get weather icon color based on weather code
  Color _getWeatherIconColor(String code) {
    final weatherCode = int.tryParse(code) ?? 0;
    if (weatherCode == 113) return Colors.amber; // Sunny - yellow
    if (weatherCode == 116) return Colors.amber[300]!; // Partly cloudy
    if (weatherCode == 119 || weatherCode == 122) return Colors.grey[400]!; // Cloudy
    if (weatherCode >= 176 && weatherCode <= 356) return Colors.lightBlue[300]!; // Rain
    if (weatherCode >= 359 && weatherCode <= 395) return Colors.purple[300]!; // Thunderstorm
    if (weatherCode >= 200 && weatherCode <= 232) return Colors.purple[300]!; // Thunderstorm
    if (weatherCode >= 600 && weatherCode <= 622) return Colors.lightBlue[100]!; // Snow
    if (weatherCode >= 371 && weatherCode <= 392) return Colors.lightBlue[100]!; // Snow
    if (weatherCode == 143 || weatherCode == 248 || weatherCode == 260) return Colors.grey[300]!; // Fog
    return Colors.amber; // Default
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
          Icon(
            _getWeatherIcon(_weatherCode ?? '113'),
            size: 48,
            color: _getWeatherIconColor(_weatherCode ?? '113'),
          ),
          const SizedBox(width: 16),
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

    // Format date for upcoming events (e.g., "Thu 1st Jan")
    String? dateStr;
    if (showDate) {
      final eventDate = _parseDate(event.date);
      final dayFormat = DateFormat('EEE'); // Day name (Thu)
      final monthFormat = DateFormat('MMM'); // Month name (Jan)
      final dayNum = eventDate.day;
      final suffix = _getDaySuffix(dayNum);
      dateStr = '${dayFormat.format(eventDate)} $dayNum$suffix ${monthFormat.format(eventDate)}';
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
