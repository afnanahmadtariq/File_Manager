import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import 'storage_screen.dart';
import '../models/file_entity.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Recent', style: TextStyle(fontSize: 28, color: Colors.grey, fontWeight: FontWeight.w300)),
                  const SizedBox(width: 10),
                  const Text('Storage', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageScreen()));
                    }, 
                    icon: const Icon(Icons.search, size: 28)
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildStorageUsage(),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCategoryGrid(context),
                      const SizedBox(height: 30),
                      _buildActionCard(Icons.brush_outlined, 'Cleaner', Colors.green),
                      const SizedBox(height: 16),
                      _buildActionCard(Icons.lock_outline, 'Safe Folder', Colors.deepPurpleAccent),
                      const SizedBox(height: 30),
                      _buildRecentFilesList(context, provider),
                      const SizedBox(height: 20),
                      _buildStaticFolders(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud_outlined), label: 'Cloud'),
        ],
      ),
    );
  }

  Widget _buildStorageUsage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Internal Storage', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('75% used', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.75,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          const Text('96 GB / 128 GB', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    final provider = context.read<FileProvider>();
    final categories = [
      {'icon': Icons.description_outlined, 'label': 'Docs', 'color': Colors.orangeAccent},
      {'icon': Icons.image_outlined, 'label': 'Images', 'color': Colors.redAccent},
      {'icon': Icons.videocam_outlined, 'label': 'Videos', 'color': Colors.indigoAccent},
      {'icon': Icons.music_note_outlined, 'label': 'Music', 'color': Colors.lightGreenAccent},
      {'icon': Icons.view_in_ar_outlined, 'label': 'Archives', 'color': Colors.blueAccent},
      {'icon': Icons.android_outlined, 'label': 'APKs', 'color': Colors.greenAccent},
      {'icon': Icons.swap_vert_outlined, 'label': 'Shared', 'color': Colors.lightBlueAccent},
      {'icon': Icons.grid_view_outlined, 'label': 'More', 'color': Colors.blueGrey},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 20,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return InkWell(
          onTap: () {
            provider.setCategoryFilter(cat['label'] as String);
            Navigator.push(context, MaterialPageRoute(builder: (_) => StorageScreen(title: cat['label'] as String)));
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (cat['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(cat['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecentFilesList(BuildContext context, FileProvider provider) {
    if (provider.recentFiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...provider.recentFiles.map((file) => ListTile(
          onTap: () => provider.openFile(file.path),
          contentPadding: EdgeInsets.zero,
          leading: Icon(_getIcon(file), color: _getIconColor(file)),
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(DateFormat('dd/MM/yy').format(file.modified)),
        )),
      ],
    );
  }

  Widget _buildStaticFolders(BuildContext context) {
    final folders = [
      {'name': 'Download', 'path': '/storage/emulated/0/Download', 'items': '13 items', 'date': '07/08/22 11:27 AM'},
      {'name': 'Telegram', 'path': '/storage/emulated/0/Telegram', 'items': '4 items', 'date': '05/08/22 19:16 PM'},
    ];

    return Column(
      children: folders.map((folder) => ListTile(
        onTap: () {
           Navigator.push(context, MaterialPageRoute(builder: (_) => StorageScreen(path: folder['path'], title: folder['name'])));
        },
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder, color: Colors.amber),
        ),
        title: Text(folder['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${folder['items']}  |  ${folder['date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      )).toList(),
    );
  }

  IconData _getIcon(FileEntity entity) {
    switch (entity.extension) {
      case 'jpg': case 'jpeg': case 'png': return Icons.image_outlined;
      case 'mp4': return Icons.videocam_outlined;
      case 'mp3': return Icons.music_note_outlined;
      case 'pdf': return Icons.description_outlined;
      case 'apk': return Icons.android_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Color _getIconColor(FileEntity entity) {
    switch (entity.extension) {
      case 'jpg': case 'jpeg': case 'png': return Colors.redAccent;
      case 'mp4': return Colors.indigoAccent;
      case 'mp3': return Colors.lightGreenAccent;
      case 'pdf': return Colors.orangeAccent;
      case 'apk': return Colors.greenAccent;
      default: return Colors.blueGrey;
    }
  }
}
