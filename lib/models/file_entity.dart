import 'dart:io';
import 'package:path/path.dart' as p;

class FileEntity {
  final FileSystemEntity entity;
  final String name;
  final String path;
  final bool isDirectory;
  final DateTime modified;
  final int size;
  final String extension;

  FileEntity({
    required this.entity,
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.modified,
    required this.size,
    required this.extension,
  });

  factory FileEntity.fromEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    return FileEntity(
      entity: entity,
      name: p.basename(entity.path),
      path: entity.path,
      isDirectory: entity is Directory,
      modified: stat.modified,
      size: stat.size,
      extension: entity is File ? p.extension(entity.path).replaceAll('.', '').toLowerCase() : '',
    );
  }
}
