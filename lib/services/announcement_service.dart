import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/announcement.dart';

class AnnouncementService extends ChangeNotifier {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'announcements';

  List<Announcement> _announcements = [];
  bool _isLoading = false;

  List<Announcement> get announcements => List.unmodifiable(_announcements);
  bool get isLoading => _isLoading;

  Future<void> loadAnnouncements() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();

      _announcements = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Announcement.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createAnnouncement(Announcement announcement) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final newAnnouncement = announcement.copyWith(id: docRef.id);
      await docRef.set(newAnnouncement.toMap());
      _announcements.insert(0, newAnnouncement);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      rethrow;
    }
  }

  Future<void> updateAnnouncement(Announcement announcement) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(announcement.id)
          .update(announcement.toMap());
      
      final index = _announcements.indexWhere((a) => a.id == announcement.id);
      if (index != -1) {
        _announcements[index] = announcement;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating announcement: $e');
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      _announcements.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
      rethrow;
    }
  }

  Stream<List<Announcement>> getActiveAnnouncementsStream() {
    return _firestore
        .collection(_collection)
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Announcement.fromMap(data);
      }).where((a) {
        // Double check expiration locally
        if (a.expiresAt == null) return true;
        // Treat expiration date as inclusive (valid until end of that day)
        final expirationEndContext = DateTime(
          a.expiresAt!.year, 
          a.expiresAt!.month, 
          a.expiresAt!.day, 
          23, 59, 59
        );
        return expirationEndContext.isAfter(DateTime.now());
      }).toList();
    });
  }
}
