import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friend_service.dart';

class AddFriendButton extends StatefulWidget {
  final String otherUserId;
  final bool mini;

  const AddFriendButton({
    Key? key,
    required this.otherUserId,
    this.mini = false,
  }) : super(key: key);

  @override
  State<AddFriendButton> createState() => _AddFriendButtonState();
}

class _AddFriendButtonState extends State<AddFriendButton> {
  String _status = "loading";
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await FriendService.loadFriendStatus(widget.otherUserId);
    String? requestId;
    if (status == "received_pending") {
      final myId = FirebaseAuth.instance.currentUser!.uid;
      final recvReq = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('from', isEqualTo: widget.otherUserId)
          .where('to', isEqualTo: myId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (recvReq.docs.isNotEmpty) {
        requestId = recvReq.docs.first.id;
      }
    }
    if (mounted) {
      setState(() {
        _status = status;
        _pendingRequestId = requestId;
      });
    }
  }

  Future<void> _sendRequest() async {
    await FriendService.sendFriendRequest(widget.otherUserId);
    _loadStatus();
  }

  Future<void> _cancelRequest() async {
    await FriendService.cancelFriendRequest(widget.otherUserId);
    _loadStatus();
  }

  Future<void> _acceptRequest() async {
    if (_pendingRequestId != null) {
      await FriendService.acceptFriendRequest(_pendingRequestId!, widget.otherUserId);
      _loadStatus();
    }
  }

  Future<void> _declineRequest() async {
    if (_pendingRequestId != null) {
      await FriendService.ignoreFriendRequest(_pendingRequestId!);
      _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.mini ? 32.0 : 40.0;
    final friendsWidth = widget.mini ? 64.0 : 88.0;
    final pendingWidth = widget.mini ? 74.0 : 104.0;

    if (_status == "loading") {
      return SizedBox(
        width: height,
        height: height,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: widget.mini ? 2 : 3,
            color: Colors.white,
          ),
        ),
      );
    }

    // Already friends: Dark Glass Look (Taggin theme)
    if (_status == "friends") {
      return SizedBox(
        width: friendsWidth,
        height: height,
        child: TextButton(
          onPressed: null,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.08), // frosted glass
            fixedSize: Size(friendsWidth, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Colors.white.withOpacity(0.25),
                width: 1.2,
              ),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.mini ? 14 : 16,
              letterSpacing: 0.5,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
          child: Center(
            child: Text('Friends'),
          ),
        ),
      );
    }

    // Pending: you sent the request (Dark Glass Look)
    if (_status == "pending") {
      return SizedBox(
        width: pendingWidth,
        height: height,
        child: TextButton(
          onPressed: _cancelRequest,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.08),
            fixedSize: Size(pendingWidth, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Colors.purpleAccent.withOpacity(0.35),
                width: 1.2,
              ),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.mini ? 14 : 16,
              letterSpacing: 0.5,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
          child: Center(
            child: Text('Pending'),
          ),
        ),
      );
    }

    // Received Pending: Show only Accept
    if (_status == "received_pending") {
      return SizedBox(
        height: height,
        child: ElevatedButton(
          onPressed: _acceptRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            elevation: 2,
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.mini ? 12 : 14,
            ),
            minimumSize: Size(widget.mini ? 38 : 60, height),
            padding: EdgeInsets.symmetric(horizontal: widget.mini ? 4 : 8),
          ),
          child: Text('Accept'),
        ),
      );
    }

    // Default: only icon button (bigger), with glow gradient
    return SizedBox(
      width: height + 16,
      height: height + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow
          Container(
            width: height + 12,
            height: height + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.36),
                  Colors.purpleAccent.withOpacity(0.18),
                  Colors.transparent
                ],
                radius: 0.75,
              ),
            ),
          ),
          Material(
            color: Colors.black,
            elevation: 5,
            shadowColor: Colors.blueAccent.withOpacity(0.23),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: _sendRequest,
              icon: Icon(
                Icons.person_add,
                color: Colors.white,
                size: widget.mini ? 24 : 32,
              ),
              splashRadius: widget.mini ? 18 : 26,
            ),
          ),
        ],
      ),
    );
  }
}
