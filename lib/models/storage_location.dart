
class StorageLocation {
  final String name;
  final String path;
  final IconType iconType;
  final bool isRemovable;

  StorageLocation({
    required this.name,
    required this.path,
    required this.iconType,
    this.isRemovable = false,
  });
}

enum IconType {
  internalStorage,
  sdCard,
  download,
  dcim,
  documents,
  music,
  movies,
  pictures,
  bluetooth,
  custom,
}
