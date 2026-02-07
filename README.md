# 📂 File Manager

A fast, modern, and powerful file manager built with Flutter. Browse, organize, and manage your files with a clean, intuitive interface designed for performance.

[![Download APK](https://img.shields.io/badge/Download-Latest%20APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/afnanahmadtariq/File_Manager/releases/latest/download/app-release.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.10.3+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

## ✨ key Features

- **🚀 High Performance**: Utilizes Dart Isolates for background file scanning, ensuring a smooth, jank-free user experience even with large directories.
- **📂 Smart Categorization**: Automatically organizes your files into intuitive categories:
  - 🖼️ Images
  - 🎬 Videos
  - 🎵 Music
  - 📄 Documents
  - 📦 Archives
  - 📱 APKs
- **📊 Storage Analysis**: Visual breakdown of your storage usage in the sidebar, helping you manage space effectively.
- **🔒 Safe Folder**: Securely store sensitive files in a protected folder.
- **🧹 Cleaner Tool**: Built-in utility to help identify and clean up unnecessary files (Coming Soon/In Development).
- **🔍 Power Search**: Quickly find any file with real-time search filtering.
- **🛠 Full File Operations**:
  - Copy / Cut / Paste
  - Rename
  - Delete
  - Share files directly
  - Open files with default apps
- **📱 Responsive Design**: Adaptive layout that works beautifully on both phones (Drawer navigation) and tablets/desktops (Persistent Sidebar).
- **🎨 Modern UI**: Features a sleek design with smooth transitions and animations.

## 🛠 Tech Stack

Built with the following robust technologies:

- **[Flutter](https://flutter.dev/)**: For a beautiful, natively compiled application.
- **[Provider](https://pub.dev/packages/provider)**: For efficient state management.
- **[path_provider](https://pub.dev/packages/path_provider)** & **[open_filex](https://pub.dev/packages/open_filex)**: For core file system interactions.
- **[permission_handler](https://pub.dev/packages/permission_handler)**: For handling Android runtime permissions.
- **[disk_space_plus](https://pub.dev/packages/disk_space_plus)**: For accurate storage statistics.

## 📸 Screenshots

|    Home Screen     |  Storage Browser   |      Sidebar       |
| :----------------: | :----------------: | :----------------: |
| _(Add Screenshot)_ | _(Add Screenshot)_ | _(Add Screenshot)_ |

## 🚀 Getting Started

To build and run this project locally, follow these steps:

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- An Android device or emulator (iOS support is planned).

### Installation

1.  **Clone the repository**:

    ```bash
    git clone https://github.com/afnanahmadtariq/File_Manager.git
    cd File_Manager
    ```

2.  **Install dependencies**:

    ```bash
    flutter pub get
    ```

3.  **Run the app**:

    ```bash
    flutter run
    ```

4.  **Build Release APK**:
    ```bash
    flutter build apk --release
    ```

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improvements or bug fixes, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/YourFeature`).
3.  Commit your changes (`git commit -m 'Add some feature'`).
4.  Push to the branch (`git push origin feature/YourFeature`).
5.  Open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ by <a href="https://github.com/afnanahmadtariq">Afnan Ahmad Tariq</a>
</p>
