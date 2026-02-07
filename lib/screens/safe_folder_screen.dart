
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/file_entity.dart';

class SafeFolderScreen extends StatefulWidget {
  const SafeFolderScreen({super.key});

  @override
  State<SafeFolderScreen> createState() => _SafeFolderScreenState();
}

class _SafeFolderScreenState extends State<SafeFolderScreen> {
  bool _isAuthenticated = false;
  bool _isSettingUp = false;
  List<FileEntity> _safeFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString('safe_folder_pin');

      if (mounted) {
        if (storedPin == null) {
          setState(() {
            _isSettingUp = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isSettingUp = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking safe folder setup: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Fallback to setup mode or show error?
          // If prefs fail, we can't really secure it properly.
          // But showing error state is better than crash.
          _isSettingUp = true; 
        });
      }
    }
  }

  Future<void> _setPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('safe_folder_pin', pin);
      if (mounted) {
        setState(() {
          _isSettingUp = false;
          _isAuthenticated = true;
        });
        _loadSafeFiles();
      }
    } catch (e) {
      debugPrint('Error setting PIN: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Failed to set PIN')),
         );
      }
    }
  }

  Future<void> _verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString('safe_folder_pin');
      
      if (!mounted) return;

      if (pin == storedPin) {
        setState(() {
          _isAuthenticated = true;
        });
        _loadSafeFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN')),
        );
      }
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Error verifying PIN')),
         );
      }
    }
  }

  Future<void> _loadSafeFiles() async {
    // We'll use a hidden folder in the app's document directory or external storage
    // For simplicity, let's use a hidden folder in external storage if possible, or app doc dir.
    // Using external path allows partial recovery if app is uninstalled but creates visibility issues.
    // Let's us specific app directory.
    
    final appDir = await Directory('/storage/emulated/0/.safe_folder').create(recursive: true);
    final files = appDir.listSync();
    
    if (mounted) {
      setState(() {
        _safeFiles = files
            .whereType<File>()
            .map((e) => FileEntity.fromEntity(e))
            .toList();
      });
    }
  }
  
  Future<void> _removeFromSafeFolder(FileEntity file) async {
    // Move back to specific restore location, e.g. Downloads
    final restoreDir = Directory('/storage/emulated/0/Download');
    if (!restoreDir.existsSync()) {
      await restoreDir.create();
    }
    
    final newPath = p.join(restoreDir.path, file.name);
    await file.entity.rename(newPath);
     _loadSafeFiles();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isSettingUp) {
      return _buildPinSetup();
    }

    if (!_isAuthenticated) {
      return _buildPinEntry();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Folder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Open file picker to add files
              // For now, simple instruction
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use "Move to Safe Folder" from file options')),
              );
            },
          ),
        ],
      ),
      body: _safeFiles.isEmpty
          ? const Center(child: Text('No files in Safe Folder'))
          : ListView.builder(
              itemCount: _safeFiles.length,
              itemBuilder: (context, index) {
                final file = _safeFiles[index];
                return ListTile(
                  leading: const Icon(Icons.lock),
                  title: Text(file.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    onPressed: () => _removeFromSafeFolder(file),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPinSetup() {
    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Create a 4-digit PIN for your Safe Folder'),
            const SizedBox(height: 24),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (val) {
                 if (val.length == 4) {
                   // Move to confirm step in a real app,
                   // for simplicity here we just set it
                   _setPin(val);
                 }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter PIN',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Enter your PIN to access Safe Folder'),
            const SizedBox(height: 24),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (val) {
                 if (val.length == 4) {
                   _verifyPin(val);
                 }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'PIN',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
