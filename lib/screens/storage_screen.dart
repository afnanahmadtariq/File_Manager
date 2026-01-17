import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../models/file_entity.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class StorageScreen extends StatefulWidget {
  final String? path;
  final String? title;

  const StorageScreen({super.key, this.path, this.title});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.path != null) {
        context.read<FileProvider>().loadFiles(widget.path!);
      } else if (context.read<FileProvider>().files.isEmpty) {
        context.read<FileProvider>().init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileProvider>();
    final isSelectionMode = provider.selectedEntities.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => provider.clearSelection())
            : IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => Navigator.pop(context)),
        title: isSelectionMode ? Text('${provider.selectedEntities.length} selected') : null,
        actions: [
          if (isSelectionMode) ...[
            IconButton(icon: const Icon(Icons.copy), onPressed: () => provider.copySelected()),
            IconButton(icon: const Icon(Icons.content_cut), onPressed: () => provider.cutSelected()),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _showDeleteConfirm(context, null, provider)),
          ] else ...[
            if (provider.hasClipboard)
              IconButton(
                icon: const Icon(Icons.paste),
                onPressed: () => provider.paste(),
                tooltip: 'Paste',
              ),
            IconButton(
              icon: Icon(provider.isGridView ? Icons.list : Icons.grid_view),
              onPressed: () => provider.toggleView(),
            ),
            PopupMenuButton<SortOption>(
              onSelected: (option) => provider.setSortOption(option),
              itemBuilder: (context) => [
                const PopupMenuItem(value: SortOption.name, child: Text('Sort by Name')),
                const PopupMenuItem(value: SortOption.size, child: Text('Sort by Size')),
                const PopupMenuItem(value: SortOption.date, child: Text('Sort by Date')),
              ],
              icon: const Icon(Icons.sort),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title ?? 'Storage', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(provider.currentPath, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => provider.setSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadFiles(provider.currentPath),
              child: provider.files.isEmpty 
                  ? const Center(child: Text('No files found'))
                  : (provider.isGridView ? _buildGrid(provider) : _buildList(provider)),
            ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode ? null : FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, provider),
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGrid(FileProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: provider.files.length,
      itemBuilder: (context, index) {
        final entity = provider.files[index];
        final isSelected = provider.selectedEntities.contains(entity);
        return InkWell(
          onTap: () {
            if (provider.selectedEntities.isNotEmpty) {
              provider.toggleSelection(entity);
            } else {
              _onEntityTap(context, entity, provider);
            }
          },
          onLongPress: () => provider.toggleSelection(entity),
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _buildGridItem(entity, provider),
              if (isSelected)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFF4A90E2), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridItem(FileEntity entity, FileProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: provider.selectedEntities.contains(entity) ? Border.all(color: const Color(0xFF4A90E2), width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconColor(entity).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIcon(entity), color: _getIconColor(entity)),
              ),
              if (provider.selectedEntities.isEmpty) _buildMoreMenu(entity, provider),
            ],
          ),
          const Spacer(),
          Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(entity.isDirectory ? 'Folder' : _formatSize(entity.size), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildList(FileProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: provider.files.length,
      itemBuilder: (context, index) {
        final entity = provider.files[index];
        final isSelected = provider.selectedEntities.contains(entity);
        return ListTile(
          onTap: () {
            if (provider.selectedEntities.isNotEmpty) {
              provider.toggleSelection(entity);
            } else {
              _onEntityTap(context, entity, provider);
            }
          },
          onLongPress: () => provider.toggleSelection(entity),
          contentPadding: EdgeInsets.zero,
          leading: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getIconColor(entity).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIcon(entity), color: _getIconColor(entity)),
              ),
              if (isSelected)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Color(0xFF4A90E2), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
          title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${_formatSize(entity.size)}  |  ${DateFormat('dd/MM/yy').format(entity.modified)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: provider.selectedEntities.isEmpty ? _buildMoreMenu(entity, provider) : null,
          selected: isSelected,
          selectedTileColor: const Color(0xFF4A90E2).withOpacity(0.05),
        );
      },
    );
  }

  Widget _buildMoreMenu(FileEntity entity, FileProvider provider) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'delete':
            _showDeleteConfirm(context, entity, provider);
            break;
          case 'rename':
            _showRenameDialog(context, entity, provider);
            break;
          case 'copy':
            provider.toggleSelection(entity);
            provider.copySelected();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
            break;
          case 'cut':
            provider.toggleSelection(entity);
            provider.cutSelected();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cut to clipboard')));
            break;
          case 'share':
            if (!entity.isDirectory) {
              Share.shareXFiles([XFile(entity.path)]);
            }
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        const PopupMenuItem(value: 'cut', child: Text('Cut')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
        if (!entity.isDirectory) const PopupMenuItem(value: 'share', child: Text('Share')),
      ],
      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
    );
  }

  void _onEntityTap(BuildContext context, FileEntity entity, FileProvider provider) {
    if (entity.isDirectory) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StorageScreen(path: entity.path, title: entity.name)));
    } else {
      provider.openFile(entity.path);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _getIcon(FileEntity entity) {
    if (entity.isDirectory) return Icons.folder;
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
    if (entity.isDirectory) return Colors.amber;
    switch (entity.extension) {
      case 'jpg': case 'jpeg': case 'png': return Colors.redAccent;
      case 'mp4': return Colors.indigoAccent;
      case 'mp3': return Colors.lightGreenAccent;
      case 'pdf': return Colors.orangeAccent;
      case 'apk': return Colors.greenAccent;
      default: return Colors.blueGrey;
    }
  }

  void _showCreateFolderDialog(BuildContext context, FileProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Folder name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (controller.text.isNotEmpty) {
              provider.createFolder(controller.text);
            }
            Navigator.pop(context);
          }, child: const Text('Create')),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FileEntity entity, FileProvider provider) {
    final controller = TextEditingController(text: entity.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (controller.text.isNotEmpty && controller.text != entity.name) {
              provider.renameEntity(entity, controller.text);
            }
            Navigator.pop(context);
          }, child: const Text('Rename')),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, FileEntity? entity, FileProvider provider) {
    final name = entity?.name ?? '${provider.selectedEntities.length} items';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (entity != null) {
              provider.deleteEntity(entity);
            } else {
              provider.deleteSelected();
            }
            Navigator.pop(context);
          }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
