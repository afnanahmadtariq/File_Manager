import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/file_entity.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

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

  FileEntity? _clipboardEntity;
  List<FileEntity> _clipboardList = [];
  bool _isCut = false;
  bool get hasClipboard => _clipboardList.isNotEmpty || _clipboardEntity != null;

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
      _currentPath = '/storage/emulated/0';
      if (!Directory(_currentPath).existsSync()) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          _currentPath = directory.path;
        }
      }
      await loadFiles(_currentPath);
      await loadRecentFiles();
    }
  }

  Future<void> loadFiles(String path) async {
    _currentPath = path;
    _categoryFilter = '';
    _selectedEntities.clear();
    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      _allFiles = entities.map((e) => FileEntity.fromEntity(e)).toList();
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
        final List<FileSystemEntity> entities = await dir.list().toList();
        _recentFiles = entities
            .whereType<File>()
            .map((e) => FileEntity.fromEntity(e))
            .toList();
        _recentFiles.sort((a, b) => b.modified.compareTo(a.modified));
        _recentFiles = _recentFiles.take(10).toList();
      }
    } catch (e) {
      debugPrint("Error loading recent files: $e");
    }
    notifyListeners();
  }

  void _applyFilterAndSort() {
    _filteredFiles = _allFiles.where((file) {
      final matchesSearch = file.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_categoryFilter.isEmpty) return matchesSearch;
      
      bool matchesCategory = false;
      switch (_categoryFilter) {
        case 'Docs':
          matchesCategory = ['pdf', 'doc', 'docx', 'txt', 'epub'].contains(file.extension);
          break;
        case 'Images':
          matchesCategory = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(file.extension);
          break;
        case 'Videos':
          matchesCategory = ['mp4', 'mkv', 'avi', 'mov'].contains(file.extension);
          break;
        case 'Music':
          matchesCategory = ['mp3', 'wav', 'flac', 'm4a'].contains(file.extension);
          break;
        case 'APKs':
          matchesCategory = file.extension == 'apk';
          break;
        case 'Archives':
          matchesCategory = ['zip', 'rar', '7z', 'tar'].contains(file.extension);
          break;
        case 'More':
          matchesCategory = true;
          break;
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
        default:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _isAscending ? comparison : -comparison;
    });
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilterAndSort();
  }

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    _applyFilterAndSort();
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
        // Recursive copy not implemented here for brevity, usually needs a library or manual crawl
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
}
