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
  final bool isFilterMode;
  final String? filterCategory;

  const StorageScreen({
    super.key,
    this.path,
    this.title,
    this.isFilterMode = false,
    this.filterCategory,
  });

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<FileProvider>();
      
      if (widget.isFilterMode && widget.filterCategory != null) {
        // Deep scan mode for category filtering
        await provider.scanAllDirectoriesForCategory(widget.filterCategory!);
      } else if (widget.path != null) {
        await provider.loadFiles(widget.path!);
      } else if (provider.files.isEmpty) {
        await provider.init();
      }
      
      // Check if widget is still mounted before starting animation
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileProvider>();
    final isSelectionMode = provider.selectedEntities.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF1A1E2E)),
                onPressed: () => provider.clearSelection(),
              )
            : IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1A1E2E)),
                ),
                onPressed: () {
                  if (widget.isFilterMode) {
                    provider.clearCategoryFilter();
                  }
                  Navigator.pop(context);
                },
              ),
        title: isSelectionMode
            ? Text(
                '${provider.selectedEntities.length} selected',
                style: const TextStyle(
                  color: Color(0xFF1A1E2E),
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        actions: _buildAppBarActions(provider, isSelectionMode),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSelectionMode) _buildHeader(provider),
          
          // Scanning indicator
          if (provider.isScanning)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Scanning all directories...',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                color: const Color(0xFF6366F1),
                onRefresh: () async {
                  if (widget.isFilterMode && widget.filterCategory != null) {
                    await provider.refreshCategoryIndex(widget.filterCategory!);
                  } else {
                    await provider.loadFiles(provider.currentPath);
                  }
                },
                child: provider.files.isEmpty && !provider.isScanning
                    ? _buildEmptyState()
                    : (provider.isGridView 
                        ? _buildGrid(provider) 
                        : _buildList(provider)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : widget.isFilterMode
              ? null
              : FloatingActionButton(
                  onPressed: () => _showCreateFolderDialog(context, provider),
                  backgroundColor: const Color(0xFF6366F1),
                  elevation: 8,
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
    );
  }

  List<Widget> _buildAppBarActions(FileProvider provider, bool isSelectionMode) {
    if (isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: Color(0xFF1A1E2E)),
          onPressed: () => provider.copySelected(),
        ),
        IconButton(
          icon: const Icon(Icons.content_cut_rounded, color: Color(0xFF1A1E2E)),
          onPressed: () => provider.cutSelected(),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
          onPressed: () => _showDeleteConfirm(context, null, provider),
        ),
        const SizedBox(width: 8),
      ];
    }

    return [
      if (provider.hasClipboard)
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.paste_rounded, color: Color(0xFF10B981)),
            onPressed: () => provider.paste(),
            tooltip: 'Paste',
          ),
        ),
      Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            provider.isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
            color: const Color(0xFF1A1E2E),
          ),
          onPressed: () => provider.toggleView(),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: PopupMenuButton<SortOption>(
          onSelected: (option) => provider.setSortOption(option),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, 50),
          itemBuilder: (context) => [
            _buildSortMenuItem(SortOption.name, 'Name', Icons.sort_by_alpha_rounded),
            _buildSortMenuItem(SortOption.size, 'Size', Icons.data_usage_rounded),
            _buildSortMenuItem(SortOption.date, 'Date', Icons.calendar_today_rounded),
          ],
          icon: const Icon(Icons.sort_rounded, color: Color(0xFF1A1E2E)),
        ),
      ),
    ];
  }

  PopupMenuItem<SortOption> _buildSortMenuItem(SortOption option, String label, IconData icon) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildHeader(FileProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? 'Storage',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1E2E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.isFilterMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 14,
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${provider.files.length} files found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              provider.currentPath,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => provider.setSearchQuery(value),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search files...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: const Color(0xFF6366F1).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No files found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isFilterMode
                ? 'No ${widget.filterCategory?.toLowerCase() ?? ''} files in storage'
                : 'This folder is empty',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(FileProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.05,
      ),
      itemCount: provider.files.length,
      itemBuilder: (context, index) {
        final entity = provider.files[index];
        final isSelected = provider.selectedEntities.contains(entity);
        return _buildGridItem(entity, provider, isSelected);
      },
    );
  }

  Widget _buildGridItem(FileEntity entity, FileProvider provider, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (provider.selectedEntities.isNotEmpty) {
            provider.toggleSelection(entity);
          } else {
            _onEntityTap(context, entity, provider);
          }
        },
        onLongPress: () => provider.toggleSelection(entity),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: const Color(0xFF6366F1), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isSelected ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getIconColor(entity).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIcon(entity),
                          color: _getIconColor(entity),
                          size: 24,
                        ),
                      ),
                      if (provider.selectedEntities.isEmpty)
                        _buildMoreMenu(entity, provider),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    entity.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1E2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entity.isDirectory ? 'Folder' : _formatSize(entity.size),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(FileProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: provider.files.length,
      itemBuilder: (context, index) {
        final entity = provider.files[index];
        final isSelected = provider.selectedEntities.contains(entity);
        return _buildListItem(entity, provider, isSelected);
      },
    );
  }

  Widget _buildListItem(FileEntity entity, FileProvider provider, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (provider.selectedEntities.isNotEmpty) {
              provider.toggleSelection(entity);
            } else {
              _onEntityTap(context, entity, provider);
            }
          },
          onLongPress: () => provider.toggleSelection(entity),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: const Color(0xFF6366F1), width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getIconColor(entity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIcon(entity),
                        color: _getIconColor(entity),
                        size: 22,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1E2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatSize(entity.size)}  •  ${DateFormat('MMM d, yyyy').format(entity.modified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.selectedEntities.isEmpty)
                  _buildMoreMenu(entity, provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(FileEntity entity, FileProvider provider) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            break;
          case 'cut':
            provider.toggleSelection(entity);
            provider.cutSelected();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cut to clipboard'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            break;
          case 'share':
            if (!entity.isDirectory) {
              Share.shareXFiles([XFile(entity.path)]);
            }
            break;
          case 'safe':
            try {
              await provider.moveToSafeFolder(entity);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Moved to Safe Folder')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to move file')),
                );
              }
            }
            break;
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        _buildPopupMenuItem('rename', 'Rename', Icons.edit_rounded),
        _buildPopupMenuItem('copy', 'Copy', Icons.copy_rounded),
        _buildPopupMenuItem('cut', 'Cut', Icons.content_cut_rounded),
        _buildPopupMenuItem('delete', 'Delete', Icons.delete_outline_rounded, isDestructive: true),
        if (!entity.isDirectory)
          _buildPopupMenuItem('share', 'Share', Icons.share_rounded),
        _buildPopupMenuItem('safe', 'Move to Safe Folder', Icons.lock_outline_rounded),
      ],
      icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400], size: 20),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String label,
    IconData icon, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? const Color(0xFFEF4444) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _onEntityTap(BuildContext context, FileEntity entity, FileProvider provider) {
    if (entity.isDirectory) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StorageScreen(
            path: entity.path,
            title: entity.name,
          ),
        ),
      );
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
    if (entity.isDirectory) return Icons.folder_rounded;
    switch (entity.extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.videocam_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
        return Icons.music_note_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getIconColor(FileEntity entity) {
    if (entity.isDirectory) return const Color(0xFFF59E0B);
    switch (entity.extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return const Color(0xFFF43F5E);
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return const Color(0xFF8B5CF6);
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
        return const Color(0xFF10B981);
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
      case 'txt':
        return const Color(0xFF3B82F6);
      case 'apk':
        return const Color(0xFF22C55E);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showCreateFolderDialog(BuildContext context, FileProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Folder name',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createFolder(controller.text);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FileEntity entity, FileProvider provider) {
    final controller = TextEditingController(text: entity.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != entity.name) {
                provider.renameEntity(entity, controller.text);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, FileEntity? entity, FileProvider provider) {
    final name = entity?.name ?? '${provider.selectedEntities.length} items';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (entity != null) {
                provider.deleteEntity(entity);
              } else {
                provider.deleteSelected();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
