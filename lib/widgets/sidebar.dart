import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../models/storage_location.dart';
import '../screens/storage_screen.dart';

class Sidebar extends StatefulWidget {
  final VoidCallback? onLocationSelected;
  
  const Sidebar({super.key, this.onLocationSelected});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  Map<String, int> _storageInfo = {'total': 0, 'used': 0, 'free': 0};
  bool _isLoadingStorage = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    final provider = context.read<FileProvider>();
    final info = await provider.getStorageInfo('/storage/emulated/0');
    if (mounted) {
      setState(() {
        _storageInfo = info;
        _isLoadingStorage = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 GB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  Color _getProgressBarColor(double percentage) {
    if (percentage >= 0.9) return const Color(0xFFEF4444); // Red for >90%
    if (percentage >= 0.75) return const Color(0xFFF59E0B); // Orange for >75%
    return const Color(0xFF6366F1); // Default purple/indigo
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileProvider>();
    final locations = provider.storageLocations;
    final usedPercentage = _storageInfo['total']! > 0 
        ? _storageInfo['used']! / _storageInfo['total']! 
        : 0.0;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1E2E),
            const Color(0xFF2D3447),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'File Manager',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Storage Locations Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'STORAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            // Main Storages (Internal & SD)
            ...locations.where((l) => 
              l.iconType == IconType.internalStorage || 
              l.iconType == IconType.sdCard
            ).map((location) => _buildStorageItem(context, location, isMainStorage: true)),
            
            const SizedBox(height: 20),
            
            // Quick Access Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'QUICK ACCESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            // Folder Locations
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: locations
                    .where((l) => 
                      l.iconType != IconType.internalStorage && 
                      l.iconType != IconType.sdCard
                    )
                    .map((location) => _buildLocationItem(context, location))
                    .toList(),
              ),
            ),
            
            // Storage Info Footer
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: _isLoadingStorage 
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Storage Used',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(usedPercentage * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getProgressBarColor(usedPercentage).withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: usedPercentage,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(_getProgressBarColor(usedPercentage)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatSize(_storageInfo['used']!)} / ${_formatSize(_storageInfo['total']!)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItem(BuildContext context, StorageLocation location, {bool isMainStorage = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StorageScreen(
                  path: location.path,
                  title: location.name,
                ),
              ),
            );
            widget.onLocationSelected?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getGradientForIcon(location.iconType),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _getGradientForIcon(location.iconType)[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconForType(location.iconType),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMainStorage)
                        Text(
                          location.isRemovable ? 'Removable' : 'Internal',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationItem(BuildContext context, StorageLocation location) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StorageScreen(
                  path: location.path,
                  title: location.name,
                ),
              ),
            );
            widget.onLocationSelected?.call();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForIcon(location.iconType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIconForType(location.iconType),
                    color: _getColorForIcon(location.iconType),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(IconType type) {
    switch (type) {
      case IconType.internalStorage:
        return Icons.phone_android_rounded;
      case IconType.sdCard:
        return Icons.sd_card_rounded;
      case IconType.download:
        return Icons.download_rounded;
      case IconType.dcim:
        return Icons.camera_alt_rounded;
      case IconType.documents:
        return Icons.description_rounded;
      case IconType.music:
        return Icons.music_note_rounded;
      case IconType.movies:
        return Icons.movie_rounded;
      case IconType.pictures:
        return Icons.photo_library_rounded;
      case IconType.bluetooth:
        return Icons.bluetooth_rounded;
      case IconType.custom:
        return Icons.folder_rounded;
    }
  }

  Color _getColorForIcon(IconType type) {
    switch (type) {
      case IconType.internalStorage:
        return const Color(0xFF6366F1);
      case IconType.sdCard:
        return const Color(0xFF10B981);
      case IconType.download:
        return const Color(0xFF3B82F6);
      case IconType.dcim:
        return const Color(0xFFF59E0B);
      case IconType.documents:
        return const Color(0xFFEF4444);
      case IconType.music:
        return const Color(0xFF8B5CF6);
      case IconType.movies:
        return const Color(0xFFEC4899);
      case IconType.pictures:
        return const Color(0xFF14B8A6);
      case IconType.bluetooth:
        return const Color(0xFF3B82F6);
      case IconType.custom:
        return const Color(0xFF6B7280);
    }
  }

  List<Color> _getGradientForIcon(IconType type) {
    switch (type) {
      case IconType.internalStorage:
        return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
      case IconType.sdCard:
        return [const Color(0xFF10B981), const Color(0xFF34D399)];
      default:
        return [_getColorForIcon(type), _getColorForIcon(type).withOpacity(0.8)];
    }
  }
}
