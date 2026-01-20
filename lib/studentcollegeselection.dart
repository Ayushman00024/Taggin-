import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentCollegeSelectionScreen extends StatefulWidget {
  const StudentCollegeSelectionScreen({Key? key}) : super(key: key);

  @override
  State<StudentCollegeSelectionScreen> createState() =>
      _StudentCollegeSelectionScreenState();
}

class _StudentCollegeSelectionScreenState
    extends State<StudentCollegeSelectionScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  final TextEditingController _searchCtrl = TextEditingController();

  List<String> _colleges = [];
  String? _selectedCollege;
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGlobalColleges();
  }

  Future<void> _loadGlobalColleges() async {
    try {
      final snapshot = await _fire.collection("colleges").orderBy("name").get();
      setState(() {
        _colleges = snapshot.docs.map((d) => d["name"] as String).toList();
        _loading = false;
      });

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _fire.collection("users").doc(uid).get();
        final data = userDoc.data();
        if (data != null && data["selectedCollege"] != null) {
          setState(() => _selectedCollege = data["selectedCollege"]);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load colleges: $e")),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _addCollege(String college) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || college.trim().isEmpty) return;

    final formatted = college.trim().toUpperCase();

    // If already exists, just select it
    final existing = await _fire.collection("colleges").doc(formatted).get();
    if (existing.exists) {
      setState(() => _selectedCollege = formatted);
      return;
    }

    // Create new global college with deterministic ID
    await _fire.collection("colleges").doc(formatted).set({
      "name": formatted,
      "addedBy": uid,
      "createdAt": FieldValue.serverTimestamp(),
    });

    setState(() {
      _colleges.add(formatted);
      _selectedCollege = formatted;
      _searchCtrl.clear();
    });
  }

  Future<void> _saveSelection() async {
    final uid = _auth.currentUser?.uid;
    final user = _auth.currentUser;
    if (uid == null || _selectedCollege == null) return;

    setState(() => _isSaving = true);

    try {
      final ref = _fire.collection("users").doc(uid);
      final doc = await ref.get();

      // 🧩 Ensure user doc exists
      if (!doc.exists) {
        await ref.set({
          'uid': uid,
          'email': user?.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // ✅ Save selected college
      await ref.set({
        "selectedCollege": _selectedCollege,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context, _selectedCollege);
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: ${e.message ?? e.code}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<String> get _filteredColleges {
    final query = _searchCtrl.text.trim().toUpperCase();
    if (query.isEmpty) return _colleges;
    return _colleges.where((c) => c.contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toUpperCase();
    final exists = _colleges.any((c) => c == query);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Your College"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search or add a college...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (query.isNotEmpty && !exists)
              ElevatedButton.icon(
                onPressed: () => _addCollege(query),
                icon: const Icon(Icons.add),
                label: Text("Add \"$query\""),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _colleges.isEmpty
                  ? const Center(
                child: Text("No colleges yet",
                    style: TextStyle(color: Colors.white70)),
              )
                  : ListView.builder(
                itemCount: _filteredColleges.length,
                itemBuilder: (context, index) {
                  final college = _filteredColleges[index];
                  final isSelected =
                      _selectedCollege == college;
                  return ListTile(
                    leading: const Icon(Icons.school,
                        color: Colors.white70),
                    title: Text(college,
                        style:
                        const TextStyle(color: Colors.white)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                        color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCollege = college;
                      });
                    },
                  );
                },
              ),
            ),
            if (_selectedCollege != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                      : const Text(
                    "Save",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
