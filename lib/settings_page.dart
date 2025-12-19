import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'share_setup_screen.dart';

import 'firestore_service.dart';
import 'services/kiosk_service.dart';
import 'utils/responsive.dart';

class SettingsPage extends StatefulWidget {
  final String? currentDeviceName;
  final String? deviceFingerprint;
  final Color? currentColor;
  final bool isFirstTime;

  const SettingsPage({
    super.key,
    this.currentDeviceName,
    this.deviceFingerprint,
    this.currentColor,
    this.isFirstTime = false,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  bool _isSaving = false;

  // Kiosk mode settings
  bool _kioskEnabled = false;
  int _inactivityTimeout = KioskService.defaultInactivityTimeout;
  bool _hideDeleteEdit = false;
  bool _screensaverEnabled = false;
  int _screensaverTimeout = KioskService.defaultScreensaverTimeout;
  final TextEditingController _screensaverImageUrlController =
      TextEditingController();
  final TextEditingController _screensaverFolderPathController =
      TextEditingController();
  final TextEditingController _dakboardUrlController = TextEditingController();
  bool _useFolder = false;
  bool _useDakboard = false;
  int _rotationInterval = KioskService.defaultRotationInterval;

  final List<int> _timeoutOptions = [1, 2, 5, 10, 15, 30];
  final List<int> _rotationOptions = [5, 10, 15, 30, 60]; // seconds

  final List<Color> _colorOptions = [
    Colors.orange,
    const Color(0xFF27B174),
    Colors.indigoAccent,
    Colors.lightBlueAccent,
    Colors.purple,
    const Color(0xFFFF80AB),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentDeviceName ?? '',
    );
    _selectedColor = widget.currentColor ?? Colors.blue;
    _loadSavedColor();
    _loadKioskSettings();
  }

  Future<void> _loadKioskSettings() async {
    final kioskService = KioskService();
    await kioskService.initialize();
    setState(() {
      _kioskEnabled = kioskService.isEnabled;
      _inactivityTimeout = kioskService.inactivityTimeoutMinutes;
      _hideDeleteEdit = kioskService.hideDeleteEdit;
      _screensaverEnabled = kioskService.screensaverEnabled;
      _screensaverTimeout = kioskService.screensaverTimeoutMinutes;
      _screensaverImageUrlController.text = kioskService.screensaverImageUrl;
      _screensaverFolderPathController.text =
          kioskService.screensaverFolderPath;
      _useFolder = kioskService.useFolder;
      _useDakboard = kioskService.useDakboard;
      _dakboardUrlController.text = kioskService.dakboardUrl;
      _rotationInterval = kioskService.rotationIntervalSeconds;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _screensaverImageUrlController.dispose();
    _screensaverFolderPathController.dispose();
    _dakboardUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final oldColorValue = prefs.getInt('color_value');
    final newColorValue = _selectedColor.value;

    await prefs.setString('device_name', _nameController.text);
    await prefs.setInt('color_value', _selectedColor.value);

    // Update all existing events if color changed
    if (oldColorValue != newColorValue) {
      try {
        await FirestoreService.updateAllEventColors(newColorValue);
      } catch (e) {
        debugPrint('Error updating event colors: $e');
        // Don't fail the whole operation if color update fails
      }
    }

    // Save kiosk settings
    if (!widget.isFirstTime) {
      await KioskService().updateSettings(
        enabled: _kioskEnabled,
        inactivityTimeoutMinutes: _inactivityTimeout,
        hideDeleteEdit: _hideDeleteEdit,
        screensaverEnabled: _screensaverEnabled,
        screensaverTimeoutMinutes: _screensaverTimeout,
        screensaverImageUrl: _screensaverImageUrlController.text.trim(),
        screensaverFolderPath: _screensaverFolderPathController.text.trim(),
        rotationIntervalSeconds: _rotationInterval,
        useFolder: _useFolder,
        useDakboard: _useDakboard,
        dakboardUrl: _dakboardUrlController.text.trim(),
      );
    }

    if (widget.isFirstTime) {
      await prefs.setBool('first_time', false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShareSetupScreen()),
      );
    } else {
      if (!mounted) return;
      Navigator.pop(context, {
        'deviceName': _nameController.text,
        'color': _selectedColor,
        'kioskEnabled': _kioskEnabled,
        'kioskSettingsChanged': true,
      });
    }
  }

  Future<void> _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColorValue = prefs.getInt('color_value');

    if (savedColorValue != null) {
      setState(() {
        _selectedColor = Color(savedColorValue);
      });
    }
  }

  void _selectColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.isFirstTime
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  if (widget.isFirstTime) ...[
                    Center(
                      child: Image.asset(
                        'assets/welcome_image.png', // Replace with your own asset
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.calendar_month,
                              size: 120,
                              color: Colors.blue,
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Welcome to We Plan Calendar!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Customize your device identity to get started',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ] else
                    const SizedBox(height: 16),

                  // Device name section
                  _buildSectionTitle('Name'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: theme.primaryColor,
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                        prefixIcon: const Icon(Icons.person_outline),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Theme color section
                  _buildSectionTitle(
                    widget.isFirstTime ? 'Select Theme Color' : 'Theme Color',
                  ),
                  const SizedBox(height: 16),

                  // Color grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isLargeScreen =
                          Responsive.isTablet(context) ||
                          Responsive.isDesktop(context);
                      final spacing = isLargeScreen ? 20.0 : 16.0;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _colorOptions.length,
                        itemBuilder: (context, index) {
                          final color = _colorOptions[index];
                          final isSelected = _selectedColor == color;

                          return GestureDetector(
                            onTap: () => _selectColor(color),
                            child: Container(
                              // Ensure minimum touch target size
                              constraints: BoxConstraints(
                                minWidth: isLargeScreen ? 56 : 48,
                                minHeight: isLargeScreen ? 56 : 48,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: isLargeScreen ? 4 : 3,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: isLargeScreen ? 12 : 8,
                                            spreadRadius: isLargeScreen ? 3 : 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: isLargeScreen ? 28 : 24,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 48),
                  _buildSectionTitle('Preview'),
                  const SizedBox(height: 20),
                  // Preview section
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: _selectedColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _selectedColor.withOpacity(0.2),
                            theme.cardColor,
                          ],
                          stops: const [0.02, 0.1],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Left colored indicator
                                Container(width: 4, height: 50),
                                const SizedBox(width: 25),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.deviceFingerprint != null
                                            ? 'Event Example'
                                            : 'Event Example',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _nameController.text.isNotEmpty
                                                ? _nameController.text
                                                : 'Your Name',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Kiosk Mode section (only show when not first time)
                  if (!widget.isFirstTime) ...[
                    const SizedBox(height: 48),
                    _buildSectionTitle('Kiosk Mode'),
                    const SizedBox(height: 8),
                    Text(
                      'Optimize for wall-mounted displays and touchscreens',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    // Kiosk mode toggle
                    _buildKioskToggle(
                      icon: Icons.tv,
                      title: 'Enable Kiosk Mode',
                      subtitle: 'Auto-return to today after inactivity',
                      value: _kioskEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _kioskEnabled = value);
                      },
                    ),

                    // Inactivity timeout (only show when kiosk enabled)
                    if (_kioskEnabled) ...[
                      const SizedBox(height: 16),
                      _buildTimeoutSelector(
                        icon: Icons.timer_outlined,
                        title: 'Auto-return timeout',
                        value: _inactivityTimeout,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _inactivityTimeout = value);
                        },
                      ),

                      const SizedBox(height: 16),
                      _buildKioskToggle(
                        icon: Icons.lock_outline,
                        title: 'Hide Delete/Edit',
                        subtitle: 'Prevent event modifications',
                        value: _hideDeleteEdit,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _hideDeleteEdit = value);
                        },
                      ),

                      const SizedBox(height: 16),
                      _buildKioskToggle(
                        icon: Icons.brightness_2_outlined,
                        title: 'Enable Screensaver',
                        subtitle: 'Dim screen after extended inactivity',
                        value: _screensaverEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _screensaverEnabled = value);
                        },
                      ),

                      if (_screensaverEnabled) ...[
                        const SizedBox(height: 16),
                        _buildTimeoutSelector(
                          icon: Icons.bedtime_outlined,
                          title: 'Screensaver timeout',
                          value: _screensaverTimeout,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _screensaverTimeout = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildImageUrlInput(),
                      ],
                    ],
                  ],

                  const SizedBox(height: 40),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.isFirstTime ? 'Get Started' : 'Save',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildKioskToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isLargeScreen =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 20 : 16,
            vertical: isLargeScreen ? 16 : 12,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: value ? _selectedColor : Colors.grey[400],
                size: isLargeScreen ? 28 : 24,
              ),
              SizedBox(width: isLargeScreen ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 13 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: _selectedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeoutSelector({
    required IconData icon,
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    final isLargeScreen =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 20 : 16,
          vertical: isLargeScreen ? 12 : 8,
        ),
        child: Row(
          children: [
            Icon(icon, color: _selectedColor, size: isLargeScreen ? 28 : 24),
            SizedBox(width: isLargeScreen ? 16 : 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isLargeScreen ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 12 : 8),
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: value,
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: _selectedColor),
                style: TextStyle(
                  color: _selectedColor,
                  fontWeight: FontWeight.w600,
                  fontSize: isLargeScreen ? 15 : 14,
                ),
                items: _timeoutOptions.map((minutes) {
                  return DropdownMenuItem<int>(
                    value: minutes,
                    child: Text('$minutes min'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUrlInput() {
    final theme = Theme.of(context);
    final isLargeScreen =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    // Determine which mode is selected
    int selectedMode = _useDakboard ? 2 : (_useFolder ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _useDakboard
                      ? Icons.dashboard_outlined
                      : (_useFolder
                          ? Icons.photo_library_outlined
                          : Icons.image_outlined),
                  color: _selectedColor,
                  size: isLargeScreen ? 28 : 24,
                ),
                SizedBox(width: isLargeScreen ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screensaver Content',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _useDakboard
                            ? 'Display Dakboard dashboard'
                            : (_useFolder
                                ? 'Multiple images will rotate automatically'
                                : 'Single image display'),
                        style: TextStyle(
                          fontSize: isLargeScreen ? 13 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Toggle buttons for Image / Slideshow / Dakboard
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Single Image option
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _useFolder = false;
                          _useDakboard = false;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isLargeScreen ? 12 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: selectedMode == 0
                              ? _selectedColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: isLargeScreen ? 20 : 18,
                              color: selectedMode == 0
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Image',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: selectedMode == 0
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Slideshow option
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _useFolder = true;
                          _useDakboard = false;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isLargeScreen ? 12 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: selectedMode == 1
                              ? _selectedColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: isLargeScreen ? 20 : 18,
                              color: selectedMode == 1
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Slideshow',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: selectedMode == 1
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Dakboard option
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _useFolder = false;
                          _useDakboard = true;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isLargeScreen ? 12 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: selectedMode == 2
                              ? _selectedColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dashboard_outlined,
                              size: isLargeScreen ? 20 : 18,
                              color: selectedMode == 2
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dakboard',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: selectedMode == 2
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Single image URL input
            if (selectedMode == 0) ...[
              Text(
                'Image URL',
                style: TextStyle(
                  fontSize: isLargeScreen ? 13 : 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _screensaverImageUrlController,
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isLargeScreen ? 14 : 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _selectedColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isLargeScreen ? 14 : 10,
                  ),
                  prefixIcon: Icon(Icons.link, color: Colors.grey[400]),
                ),
                style: TextStyle(fontSize: isLargeScreen ? 14 : 12),
                keyboardType: TextInputType.url,
              ),
              // Preview image if URL is provided
              if (_screensaverImageUrlController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Image.network(
                      _screensaverImageUrlController.text,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: _selectedColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.grey[400],
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Invalid image URL',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],

            // Multiple images / folder path input
            if (selectedMode == 1) ...[
              Text(
                'Image URLs (comma-separated) or folder path',
                style: TextStyle(
                  fontSize: isLargeScreen ? 13 : 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _screensaverFolderPathController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'https://example.com/img1.jpg, https://example.com/img2.jpg\nor /path/to/images/folder',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isLargeScreen ? 14 : 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _selectedColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isLargeScreen ? 14 : 10,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.folder_outlined, color: Colors.grey[400]),
                  ),
                ),
                style: TextStyle(fontSize: isLargeScreen ? 14 : 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For web: Enter comma-separated image URLs\nFor Raspberry Pi: Enter local folder path (e.g., /home/pi/images)',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),

              // Rotation interval selector
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.rotate_right,
                    color: _selectedColor,
                    size: isLargeScreen ? 24 : 20,
                  ),
                  SizedBox(width: isLargeScreen ? 12 : 8),
                  Expanded(
                    child: Text(
                      'Rotation interval',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 14 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 12 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: _rotationInterval,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: _selectedColor),
                      style: TextStyle(
                        color: _selectedColor,
                        fontWeight: FontWeight.w600,
                        fontSize: isLargeScreen ? 15 : 14,
                      ),
                      items: _rotationOptions.map((seconds) {
                        return DropdownMenuItem<int>(
                          value: seconds,
                          child: Text('$seconds sec'),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _rotationInterval = newValue);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],

            // Dakboard URL input
            if (selectedMode == 2) ...[
              Text(
                'Dakboard URL',
                style: TextStyle(
                  fontSize: isLargeScreen ? 13 : 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dakboardUrlController,
                decoration: InputDecoration(
                  hintText: 'https://dakboard.com/app/screenPredefined?p=YOUR_ID',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isLargeScreen ? 14 : 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _selectedColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isLargeScreen ? 14 : 10,
                  ),
                  prefixIcon: Icon(Icons.dashboard_outlined, color: Colors.grey[400]),
                ),
                style: TextStyle(fontSize: isLargeScreen ? 14 : 12),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enter your Dakboard private URL from the Dakboard app settings. The dashboard will display in full screen when screensaver activates.',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
