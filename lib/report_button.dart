import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportButton extends StatelessWidget {
  final String reportedUserId;
  final String postId;

  const ReportButton({
    Key? key,
    required this.reportedUserId,
    required this.postId,
  }) : super(key: key);

  Future<void> _submitReport(BuildContext context, String reason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to report.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedBy': currentUser.uid,
        'reportedUserId': reportedUserId,
        'postId': postId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    }
  }

  void _showReasonDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Wrap(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Report Post For:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Inappropriate Content'),
            onTap: () => _submitReport(context, 'Inappropriate Content'),
          ),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Vulgar or Obscene Material'),
            onTap: () => _submitReport(context, 'Vulgar or Obscene Material'),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Spam or Misleading'),
            onTap: () => _submitReport(context, 'Spam or Misleading'),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Harassment or Hate Speech'),
            onTap: () => _submitReport(context, 'Harassment or Hate Speech'),
          ),
          ListTile(
            leading: const Icon(Icons.dangerous),
            title: const Text('Violence or Threatening Behavior'),
            onTap: () => _submitReport(context, 'Violence or Threatening Behavior'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showReasonDialog(context),
      icon: const Icon(Icons.report_outlined, color: Colors.white),
      label: const Text('Report', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
