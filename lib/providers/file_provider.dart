import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_entity.dart';
import '../models/file_index.dart';
import '../models/storage_location.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:disk_space_plus/disk_space_plus.dart';

enum SortOption { name, size, date, type }

class FileProvider with ChangeNotifier {
  List<FileEntity> _allFiles = [];
  List<FileEntity> _filteredFiles = [];
  List<FileEntity> get files => _filteredFiles;

  List<FileEntity> _recentFiles = [];
  List<FileEntity> get recentFiles => _recentFiles;

  final List<FileEntity> _selectedEntities = [];
  List<FileEntity> get selectedEntities => _selectedEntities;

  String _currentPath = '';
  String get currentPath => _currentPath;

  bool _isGridView = false;
  bool get isGridView => _isGridView;

  SortOption _currentSort = SortOption.name;
  bool _isAscending = true;

  String _searchQuery = '';
  String _categoryFilter = '';
  String get categoryFilter => _categoryFilter;

  List<FileEntity> _clipboardList = [];
  bool _isCut = false;
  bool get hasClipboard => _clipboardList.isNotEmpty;

  // Storage locations
  List<StorageLocation> _storageLocations = [];
  List<StorageLocation> get storageLocations => _storageLocations;

  // Cached indexes
  final Map<String, FileIndex> _cachedIndexes = {};
  
  // Loading state for deep scans
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Debouncing mechanism for notifyListeners
  Timer? _debounceTimer;
  DateTime _lastNotify = DateTime.now();

  /// Clean up resources
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void toggleView() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true;
  }

  Future<void> init() async {
    if (await requestPermissions()) {
      await _loadStorageLocations();
      _currentPath = '/storage/emulated/0';
      if (!Directory(_currentPath).existsSync()) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          _currentPath = directory.path;
        }
      }
      await loadFiles(_currentPath);
      await loadRecentFiles();
      await _loadCachedIndexes();
    }
  }

  Future<void> _loadStorageLocations() async {
    _storageLocations = [];
    
    // Internal Storage
    const internalPath = '/storage/emulated/0';
    if (Directory(internalPath).existsSync()) {
      _storageLocations.add(StorageLocation(
        name: 'Internal Storage',
        path: internalPath,
        iconType: IconType.internalStorage,
      ));
    }

    // Try to find SD Card using path_provider and iterating external directories
    try {
      final List<Directory>? externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (var dir in externalDirs) {
          // Format is typically /storage/UUID/Android/data/com.app/files
          final pathParts = dir.path.split('/');
          if (pathParts.contains('Android')) {
             final androidIndex = pathParts.indexOf('Android');
             if (androidIndex > 2) {
               final rootPath = pathParts.sublist(0, androidIndex).join('/');
               // Check if this is not the internal storage
               if (rootPath != internalPath && rootPath != '/storage/emulated/0') {
                  // Avoid duplicates
                  if (!_storageLocations.any((l) => l.path == rootPath)) {
                    _storageLocations.add(StorageLocation(
                      name: 'SD Card',
                      path: rootPath,
                      iconType: IconType.sdCard,
                      isRemovable: true,
                    ));
                  }
               }
             }
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving external storage: $e');
    }
    
    // Fallback: Check /storage if strictly needed/allowed, but fail silently
    if (_storageLocations.length == 1) { // Only internal found so far
       try {
         final storageDir = Directory('/storage');
         if (storageDir.existsSync()) {
            final mounts = storageDir.listSync();
            for (var mount in mounts) {
               if (mount is Directory) {
                 final name = p.basename(mount.path);
                 if (name != 'emulated' && name != 'self' && RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}$').hasMatch(name)) {
                    _storageLocations.add(StorageLocation(
                      name: 'SD Card ($name)',
                      path: mount.path,
                      iconType: IconType.sdCard,
                      isRemovable: true,
                    ));
                 }
               }
            }
         }
       } catch (e) {
         // Silently ignore permission errors here as recent Android blocks /storage listing
       }
    }

    // Common folders
    final commonFolders = [
      {'name': 'Download', 'path': '/storage/emulated/0/Download', 'icon': IconType.download},
      {'name': 'DCIM', 'path': '/storage/emulated/0/DCIM', 'icon': IconType.dcim},
      {'name': 'Documents', 'path': '/storage/emulated/0/Documents', 'icon': IconType.documents},
      {'name': 'Music', 'path': '/storage/emulated/0/Music', 'icon': IconType.music},
      {'name': 'Movies', 'path': '/storage/emulated/0/Movies', 'icon': IconType.movies},
      {'name': 'Pictures', 'path': '/storage/emulated/0/Pictures', 'icon': IconType.pictures},
      {'name': 'Bluetooth', 'path': '/storage/emulated/0/Bluetooth', 'icon': IconType.bluetooth},
    ];

    for (var folder in commonFolders) {
      final path = folder['path'] as String;
      if (Directory(path).existsSync()) {
        _storageLocations.add(StorageLocation(
          name: folder['name'] as String,
          path: path,
          iconType: folder['icon'] as IconType,
        ));
      }
    }

    notifyListeners();
  }

  /// Isolate-friendly directory listing that returns file paths with metadata
  static List<Map<String, dynamic>> _listDirectorySync(String path) {
    final List<Map<String, dynamic>> results = [];
    try {
      final dir = Directory(path);
      final entities = dir.listSync();
      for (var entity in entities) {
        results.add({
          'path': entity.path,
          'isDirectory': entity is Directory,
        });
      }
    } catch (e) {
      // Permission denied or other error
    }
    return results;
  }

  Future<void> loadFiles(String path) async {
    _currentPath = path;
    _categoryFilter = '';
    _selectedEntities.clear();
    try {
      // Use compute for background processing
      final entityData = await compute(_listDirectorySync, path);
      
      final List<FileEntity> files = [];
      for (var data in entityData) {
        try {
          final entityPath = data['path'] as String;
          final isDir = data['isDirectory'] as bool;
          final entity = isDir ? Directory(entityPath) : File(entityPath);
          files.add(FileEntity.fromEntity(entity));
          
          // Yield control periodically to prevent UI jank
          if (files.length % 50 == 0) {
            await Future.delayed(Duration.zero);
          }
        } catch (e) {
          // Skip inaccessible files
        }
      }
      
      _allFiles = files;
      _applyFilterAndSort();
    } catch (e) {
      debugPrint("Error loading files: $e");
      _allFiles = [];
      _applyFilterAndSort();
    }
  }

  Future<void> loadRecentFiles() async {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        final List<FileEntity> files = [];
        
        // Use streaming to avoid blocking
        await for (var entity in dir.list()) {
          if (entity is File) {
            files.add(FileEntity.fromEntity(entity));
          }
          
          // Yield control periodically
          if (files.length % 50 == 0) {
            await Future.delayed(Duration.zero);
          }
        }
        
        files.sort((a, b) => b.modified.compareTo(a.modified));
        _recentFiles = files.take(10).toList();
      }
    } catch (e) {
      debugPrint("Error loading recent files: $e");
    }
    _debouncedNotify();
  }

  /// Load cached indexes from SharedPreferences
  Future<void> _loadCachedIndexes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('file_index_'));
      for (var key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          final index = FileIndex.fromJsonString(jsonString);
          if (index.isValid) {
            _cachedIndexes[index.category] = index;
          } else {
            // Remove expired index
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached indexes: $e');
    }
  }

  /// Save index to SharedPreferences
  Future<void> _saveIndex(FileIndex index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('file_index_${index.category}', index.toJsonString());
      _cachedIndexes[index.category] = index;
    } catch (e) {
      debugPrint('Error saving index: $e');
    }
  }

  /// Scan all directories for files matching a category filter
  Future<void> scanAllDirectoriesForCategory(String category) async {
    _categoryFilter = category;
    
    // Check if we have a valid cached index
    if (_cachedIndexes.containsKey(category) && _cachedIndexes[category]!.isValid) {
      await _loadFromCachedIndex(category);
      return;
    }

    _isScanning = true;
    _allFiles = [];
    _debouncedNotify(); // Notify immediately when scan starts

    final List<String> rootPaths = ['/storage/emulated/0'];
    
    // Add SD card if exists
    for (var location in _storageLocations) {
      if (location.isRemovable && !rootPaths.contains(location.path)) {
        rootPaths.add(location.path);
      }
    }

    final extensions = _getExtensionsForCategory(category);
    final List<String> allFilePaths = [];

    // Use compute to run heavy scanning in background isolate
    for (var rootPath in rootPaths) {
      try {
        final paths = await compute(_scanDirectorySync, {
          'rootPath': rootPath,
          'extensions': extensions,
        });
        allFilePaths.addAll(paths);
      } catch (e) {
        debugPrint('Error scanning $rootPath: $e');
      }
    }

    // Convert paths to FileEntity objects on main thread (lighter operation)
    final List<FileEntity> foundFiles = [];
    for (var path in allFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          foundFiles.add(FileEntity.fromEntity(file));
        }
        // Yield control periodically to prevent UI jank
        if (foundFiles.length % 100 == 0) {
          await Future.delayed(Duration.zero);
          _debouncedNotify();
        }
      } catch (e) {
        // Skip files that can't be accessed
      }
    }

    _allFiles = foundFiles;
    _isScanning = false;
    
    // Save the index for future use
    final index = FileIndex(
      category: category,
      lastUpdated: DateTime.now(),
      filePaths: foundFiles.map((f) => f.path).toList(),
    );
    await _saveIndex(index);
    
    _applyFilterAndSort();
  }

  Future<void> _loadFromCachedIndex(String category) async {
    final index = _cachedIndexes[category]!;
    final List<FileEntity> files = [];
    
    for (var path in index.filePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          files.add(FileEntity.fromEntity(file));
        }
      } catch (e) {
        // File no longer exists, skip
      }
    }
    
    _allFiles = files;
    _applyFilterAndSort();
  }

  List<String> _getExtensionsForCategory(String category) {
    switch (category) {
      case 'Docs':
        return ['pdf', 'doc', 'docx', 'txt', 'epub', 'xls', 'xlsx', 'ppt', 'pptx'];
      case 'Images':
        return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
      case 'Videos':
        return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp'];
      case 'Music':
        return ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg', 'wma'];
      case 'APKs':
        return ['apk'];
      case 'Archives':
        return ['zip', 'rar', '7z', 'tar', 'gz', 'bz2'];
      default:
        return [];
    }
  }

  /// Isolate-friendly recursive scan that returns just file paths
  static List<String> _scanDirectorySync(Map<String, dynamic> params) {
    final String rootPath = params['rootPath'];
    final List<String> extensions = List<String>.from(params['extensions']);
    final List<String> results = [];
    
    void scan(Directory dir) {
      try {
        final dirName = p.basename(dir.path);
        // Skip hidden directories and Android system directories
        if (dirName.startsWith('.') || 
            dirName == 'Android' ||
            dirName == 'cache' ||
            dirName == 'thumbnails') {
          return;
        }

        final entities = dir.listSync();
        for (var entity in entities) {
          if (entity is Directory) {
            scan(entity);
          } else if (entity is File) {
            final ext = p.extension(entity.path).replaceAll('.', '').toLowerCase();
            if (extensions.isEmpty || extensions.contains(ext)) {
              results.add(entity.path);
            }
          }
        }
      } catch (e) {
        // Permission denied or other error, skip this directory
      }
    }
    
    scan(Directory(rootPath));
    return results;
  }

  /// Refresh the cached index for a category
  Future<void> refreshCategoryIndex(String category) async {
    // Remove existing cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('file_index_$category');
      _cachedIndexes.remove(category);
    } catch (e) {
      debugPrint('Error removing cached index: $e');
    }
    
    // Rescan
    await scanAllDirectoriesForCategory(category);
  }

  void _applyFilterAndSort() {
    _filteredFiles = _allFiles.where((file) {
      final matchesSearch = file.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_categoryFilter.isEmpty) return matchesSearch;
      
      bool matchesCategory = false;
      final extensions = _getExtensionsForCategory(_categoryFilter);
      if (extensions.isEmpty) {
        matchesCategory = true;
      } else {
        matchesCategory = extensions.contains(file.extension);
      }
      return matchesSearch && matchesCategory;
    }).toList();

    _filteredFiles.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int comparison;
      switch (_currentSort) {
        case SortOption.size:
          comparison = a.size.compareTo(b.size);
          break;
        case SortOption.date:
          comparison = a.modified.compareTo(b.modified);
          break;
        case SortOption.type:
          comparison = a.extension.compareTo(b.extension);
          break;
        case SortOption.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _isAscending ? comparison : -comparison;
    });
    _debouncedNotify();
  }

  /// Debounced notifyListeners to prevent excessive UI updates
  void _debouncedNotify() {
    final now = DateTime.now();
    final diff = now.difference(_lastNotify).inMilliseconds;
    
    // If last notify was less than 100ms ago, schedule it
    if (diff < 100) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(Duration(milliseconds: 100 - diff), () {
        _lastNotify = DateTime.now();
        notifyListeners();
      });
    } else {
      // Otherwise notify immediately
      _lastNotify = now;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilterAndSort();
  }

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    _applyFilterAndSort();
  }

  void clearCategoryFilter() {
    _categoryFilter = '';
    _allFiles = [];
    _filteredFiles = [];
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    if (_currentSort == option) {
      _isAscending = !_isAscending;
    } else {
      _currentSort = option;
      _isAscending = true;
    }
    _applyFilterAndSort();
  }

  void toggleSelection(FileEntity entity) {
    if (_selectedEntities.contains(entity)) {
      _selectedEntities.remove(entity);
    } else {
      _selectedEntities.add(entity);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedEntities.clear();
    notifyListeners();
  }

  Future<void> createFolder(String name) async {
    final path = p.join(_currentPath, name);
    await Directory(path).create();
    await loadFiles(_currentPath);
  }

  Future<void> deleteEntity(FileEntity entity) async {
    await entity.entity.delete(recursive: true);
    await loadFiles(_currentPath);
  }

  Future<void> deleteSelected() async {
    for (var entity in _selectedEntities) {
      await entity.entity.delete(recursive: true);
    }
    _selectedEntities.clear();
    await loadFiles(_currentPath);
  }

  Future<void> renameEntity(FileEntity entity, String newName) async {
    final newPath = p.join(p.dirname(entity.path), newName);
    await entity.entity.rename(newPath);
    await loadFiles(_currentPath);
  }

  void copySelected() {
    _clipboardList = List.from(_selectedEntities);
    _isCut = false;
    _selectedEntities.clear();
    notifyListeners();
  }

  void cutSelected() {
    _clipboardList = List.from(_selectedEntities);
    _isCut = true;
    _selectedEntities.clear();
    notifyListeners();
  }

  Future<void> paste() async {
    if (_clipboardList.isEmpty) return;
    
    for (var entity in _clipboardList) {
      final destPath = p.join(_currentPath, entity.name);
      if (entity.isDirectory) {
        // Recursive copy not implemented here for brevity
      } else {
        final file = File(entity.path);
        if (_isCut) {
          await file.rename(destPath);
        } else {
          await file.copy(destPath);
        }
      }
    }
    
    if (_isCut) _clipboardList.clear();
    await loadFiles(_currentPath);
  }

  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }

  Future<void> moveToSafeFolder(FileEntity entity) async {
    try {
      final safeDir = Directory('/storage/emulated/0/.safe_folder');
      if (!safeDir.existsSync()) {
        await safeDir.create(recursive: true);
      }
      
      final newPath = p.join(safeDir.path, entity.name);
      await entity.entity.rename(newPath);
      await loadFiles(_currentPath);
    } catch (e) {
      debugPrint("Error moving to safe folder: $e");
      rethrow;
    }
  }

  /// Get storage info for a path
  Future<Map<String, int>> getStorageInfo(String path) async {
    try {
      final diskSpace = DiskSpacePlus();
      
      final totalSpace = await diskSpace.getTotalDiskSpace;
      final freeSpace = await diskSpace.getFreeDiskSpace;
      
      final totalBytes = totalSpace != null ? (totalSpace * 1024 * 1024).toInt() : 0;
      final freeBytes = freeSpace != null ? (freeSpace * 1024 * 1024).toInt() : 0;
      final usedBytes = totalBytes - freeBytes;
      
      return {
        'total': totalBytes,
        'used': usedBytes,
        'free': freeBytes,
      };
    } catch (e) {
      debugPrint('Error getting storage info: $e');
      return {
        'total': 0,
        'used': 0,
        'free': 0,
      };
    }
  }
}
