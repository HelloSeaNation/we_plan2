import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'share_setup_screen.dart';

import 'firestore_service.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    setState(() {
      _selectedColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar:
          widget.isFirstTime
              ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
              : AppBar(
                title: const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isFirstTime) ...[
                  Center(
                    child: Image.asset(
                      'assets/welcome_image.png', // Replace with your own asset
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
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
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _colorOptions.length,
                  itemBuilder: (context, index) {
                    final color = _colorOptions[index];
                    final isSelected = _selectedColor == color;

                    return GestureDetector(
                      onTap: () => _selectColor(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                  : null,
                        ),
                        child:
                            isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                      ),
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
                              Container(
                                width: 4,
                                height: 50,
                              ),
                              const SizedBox(width: 25),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    child:
                        _isSaving
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
                              widget.isFirstTime
                                  ? 'Get Started'
                                  : 'Save',
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
}
