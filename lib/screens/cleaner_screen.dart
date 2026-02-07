
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/file_provider.dart';
import '../models/file_entity.dart';
import 'package:path/path.dart' as p;

class CleanerScreen extends StatefulWidget {
  const CleanerScreen({super.key});

  @override
  State<CleanerScreen> createState() => _CleanerScreenState();
}

class _CleanerScreenState extends State<CleanerScreen> {
  bool _isScanning = true;
  List<FileEntity> _largeFiles = [];
  List<FileEntity> _junkFiles = [];
  int _totalBytesToClean = 0;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    
    // Simulating scan delay and logic
    // In a real app, this would be a proper background service or a more robust recursive scan
    // We will leverage the existing FileProvider to some extent or do a quick scan of known paths
    
    final provider = context.read<FileProvider>();
    final rootPath = provider.currentPath.isEmpty ? '/storage/emulated/0' : provider.currentPath;
    
    final largeFiles = <FileEntity>[];
    final junkFiles = <FileEntity>[];
    
    // Simple recursive scan (limited depth/scope for demo performance)
    await _scanDir(Directory(rootPath), largeFiles, junkFiles);

    if (mounted) {
      setState(() {
        _largeFiles = largeFiles;
        _junkFiles = junkFiles;
        _isScanning = false;
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    int total = 0;
    for (var f in _largeFiles) {
      total += f.size;
    }
    for (var f in _junkFiles) {
      total += f.size;
    }
    _totalBytesToClean = total;
  }

  Future<void> _scanDir(Directory dir, List<FileEntity> large, List<FileEntity> junk) async {
    try {
      final entities = await dir.list(followLinks: false).toList();
      for (var entity in entities) {
        if (entity is File) {
          try {
            final size = await entity.length();
            final name = p.basename(entity.path);
            
            // Large files > 100MB
            if (size > 100 * 1024 * 1024) {
              large.add(FileEntity.fromEntity(entity));
            }
            
            // Junk files (tmp, log, .thumbnails)
            if (name.endsWith('.tmp') || name.endsWith('.log') || name == '.thumbnails') {
              junk.add(FileEntity.fromEntity(entity));
            }
          } catch (e) {
            // ignore
          }
        } else if (entity is Directory) {
           final name = p.basename(entity.path);
           if (!name.startsWith('.') && name != 'Android') {
             try {
               if (['Download', 'Documents', 'DCIM', 'Movies'].contains(name)) {
                  await _scanRecursive(entity, large, junk);
               }
             } catch (e) {
               // ignore
             }
           }
        }
        
        // Yield to UI thread occasionally
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      debugPrint('Error scanning dir: $e');
    }
  }

  Future<void> _scanRecursive(Directory dir, List<FileEntity> large, List<FileEntity> junk) async {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
             final size = await entity.length();
             if (size > 100 * 1024 * 1024) {
               large.add(FileEntity.fromEntity(entity));
             }
             final ext = p.extension(entity.path).toLowerCase();
             final name = p.basename(entity.path);
             if (ext == '.tmp' || ext == '.log' || name == '.thumbnails') {
               junk.add(FileEntity.fromEntity(entity));
             }
          } catch (e) {
            // ignore
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Cleaner', style: TextStyle(color: Color(0xFF1A1E2E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1E2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSummaryCard(),
                   const SizedBox(height: 24),
                   if (_junkFiles.isNotEmpty) ...[
                     _buildSectionTitle('Junk Files'),
                     const SizedBox(height: 12),
                     _buildFileList(_junkFiles, true),
                     const SizedBox(height: 24),
                   ],
                   if (_largeFiles.isNotEmpty) ...[
                     _buildSectionTitle('Large Files'),
                     const SizedBox(height: 12),
                     _buildFileList(_largeFiles, false),
                   ],
                   if (_largeFiles.isEmpty && _junkFiles.isEmpty)
                     const Center(
                       child: Text(
                         'Your storage is clean!',
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey),
                       ),
                     ),
                ],
              ),
            ),
       bottomNavigationBar: (_largeFiles.isNotEmpty || _junkFiles.isNotEmpty) 
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: () {
                     // Implement clean action (delete files)
                     // Using a dialog to confirm
                     _showCleanDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: const Text('Clean Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
           BoxShadow(
             color: const Color(0xFF10B981).withValues(alpha: 0.3),
             blurRadius: 16,
             offset: const Offset(0, 8),
           ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.cleaning_services_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _formatBytes(_totalBytesToClean),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Can be cleaned',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1E2E),
      ),
    );
  }

  Widget _buildFileList(List<FileEntity> files, bool isJunk) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length > 5 ? 5 : files.length, // Show max 5
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isJunk ? Colors.orange.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isJunk ? Icons.delete_outline_rounded : Icons.file_present_rounded,
              color: isJunk ? Colors.orange : Colors.blue,
            ),
          ),
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_formatBytes(file.size), style: TextStyle(color: Colors.grey[600])),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: () {
               setState(() {
                 files.removeAt(index);
                 _calculateTotal();
               });
            },
          ),
        );
      },
    );
  }

  void _showCleanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Clean'),
        content: const Text('Are you sure you want to delete these files? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performClean();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performClean() async {
    setState(() => _isScanning = true);
    
    // Delete files
    for (var file in _largeFiles) {
       try { await file.entity.delete(); } catch(e) { debugPrint("Error deleting file: $e"); }
    }
    for (var file in _junkFiles) {
       try { await file.entity.delete(); } catch(e) { debugPrint("Error deleting file: $e"); }
    }
    
    // Rescan
    await _startScan();
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Cleanup complete!')),
       );
    }
  }
}
