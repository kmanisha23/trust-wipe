import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/wipe_provider.dart';
import '../theme/app_theme.dart';
import 'drive_wipe_tab.dart';
import 'file_shredder_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WipeProvider>(context);

    final tabs = [
      DriveWipeTab(provider: provider),
      FileShredderTab(provider: provider),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Navigation Side Rail
          NavigationRail(
            backgroundColor: AppTheme.obsidian,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 24),
                // Glowing Cyber Shield Logo
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cyberIndigo.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cyberIndigo.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: AppTheme.cyberCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TRUSTWIPE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppTheme.cyberCyan,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Elevation Badge
                      Icon(
                        provider.isAdmin ? Icons.gpp_good : Icons.gpp_maybe,
                        color: provider.isAdmin ? AppTheme.successEmerald : AppTheme.dangerRose,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.isAdmin ? 'ADMIN' : 'STANDARD',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: provider.isAdmin ? AppTheme.successEmerald : AppTheme.dangerRose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.storage_outlined, color: AppTheme.textSecondary),
                selectedIcon: Icon(Icons.storage, color: AppTheme.cyberIndigo),
                label: Text('Drive Wipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary),
                selectedIcon: Icon(Icons.delete_sweep, color: AppTheme.cyberIndigo),
                label: Text('File Shredder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),

          // Divider line between rail and main content
          const VerticalDivider(thickness: 1, width: 1, color: AppTheme.cardBorder),

          // Main Display Window
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warning bar if not elevated
                if (!provider.isAdmin)
                  Container(
                    color: AppTheme.dangerRose.withOpacity(0.9),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'NOT RUNNING AS ADMINISTRATOR: Drive access and file overwrite loops will be blocked by Windows UAC.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Top Header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  color: AppTheme.obsidian,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedIndex == 0 
                            ? 'DRIVE SANITIZATION TELEMETRY' 
                            : 'TARGETED FILE SHREDDER SYSTEM',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: AppTheme.successEmerald),
                          const SizedBox(width: 8),
                          Text(
                            provider.isAdmin ? 'SECURE MODE ACTIVE' : 'LOCKED - RUN AS ADMIN',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1, height: 1, color: AppTheme.cardBorder),

                // Active Tab Content View
                Expanded(
                  child: Container(
                    color: AppTheme.darkSlate,
                    child: tabs[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
