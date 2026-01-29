import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'openting_list_view.dart';
import 'openting_chat_view.dart';

class OpentingView extends StatelessWidget {
  const OpentingView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    if (currentUserId == null) {
      // User not logged in, show list view (it will handle the error)
      return const OpenChatroomListView();
    }

    // Check if user is currently in a chatroom
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('openChatrooms')
          .where('participants', arrayContains: currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading while checking chatroom status
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          // User is in a chatroom, show chat view
          final chatroomId = snapshot.data!.docs.first.id;
          return OpenChatroomChatView(chatroomId: chatroomId);
        } else {
          // User not in chatroom, show list view
          return const OpenChatroomListView();
        }
      },
    );
  }
}
