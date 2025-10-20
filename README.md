# BAUST Project Showcase

A Flutter application for showcasing academic projects and research work at Bangladesh Army University of Science and Technology (BAUST).

## 🏗️ Architecture

This project follows the **Model-View-Controller (MVC)** architectural pattern for better code organization and maintainability.

### 📁 Project Structure

```
lib/
├── mvc/
│   ├── models/          # Data models and business entities
│   │   ├── user.dart
│   │   └── project.dart
│   ├── views/           # UI components and screens
│   │   ├── auth.dart
│   │   ├── student_dashboard.dart
│   │   ├── teacher_dashboard.dart
│   │   ├── admin_dashboard.dart
│   │   ├── project_detail.dart
│   │   ├── search_filter.dart
│   │   └── dashboards.dart
│   ├── controllers/     # Business logic and data management
│   │   ├── auth_service.dart
│   │   ├── project_service.dart
│   │   ├── firestore_service.dart
│   │   └── offline_storage.dart
│   └── README.md        # MVC documentation
├── main.dart            # Application entry point
├── firebase_options.dart
└── theme.dart           # App theming
```

## ✨ Features

### 🔐 Authentication System
- **Multi-role support**: Student, Teacher, and Admin roles
- **Secure login/signup** with Firebase Authentication
- **Role-based access control** for different features
- **Offline storage** fallback for authentication

### 📚 Project Management
- **Project upload** with file attachments (PDFs, images)
- **Project categorization** and metadata
- **Search and filtering** capabilities
- **Rating and review** system

### 👥 User Roles
- **Students**: Can upload and showcase their projects
- **Teachers**: Can review, rate, and provide feedback
- **Admins**: Can manage users and moderate content

### 🎨 Modern UI/UX
- **Material Design 3** theming
- **Responsive design** for multiple screen sizes
- **Dark/Light mode** support
- **Intuitive navigation** and user experience

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Firebase project setup
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/mashkurulalamohi37/-baust-project-showcase.git
   cd -baust-project-showcase
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Set up Firebase project
   - Add configuration files for your platform
   - Enable Authentication and Firestore

4. **Run the application**
   ```bash
   flutter run
   ```

### Platform Support
- ✅ **Web** (Chrome, Firefox, Safari)
- ✅ **Android** (API 21+)
- ✅ **iOS** (iOS 11.0+)
- ✅ **Windows** (Windows 10+)
- ✅ **macOS** (macOS 10.14+)
- ✅ **Linux** (Ubuntu 18.04+)

## 🛠️ Technology Stack

- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **Backend**: Firebase (Authentication, Firestore, Storage)
- **State Management**: ChangeNotifier
- **Architecture**: Model-View-Controller (MVC)
- **File Handling**: File Picker
- **Local Storage**: Shared Preferences

## 📱 Screenshots

*Coming soon...*

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Mashkurul Alam Mohi**
- GitHub: [@mashkurulalamohi37](https://github.com/mashkurulalamohi37)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- BAUST for the project inspiration
- Open source community for various packages

---

*Built with ❤️ for the BAUST community*
