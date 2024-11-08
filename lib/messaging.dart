import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class AppColors {
  static const primaryGreen = Color(0xFF1E8B55);
  static const darkBackground = Color(0xFF000000);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const cardDark = Color(0xFF252525);
  static const textLight = Color(0xFFE0E0E0);
  static const textDim = Color(0xFFB0B0B0);
}

class Messaging extends StatefulWidget {
  @override
  _MessagingState createState() => _MessagingState();
}

class _MessagingState extends State<Messaging> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  List<Map<String, dynamic>> _connectedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser.uid;
      });
      _fetchConnections();
    }
  }

  Future<void> _fetchConnections() async {
    if (_currentUserId != null) {
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          List<String> connections = List<String>.from(
              (userDoc.data() as Map<String, dynamic>)['connections'] ?? []);

          List<Map<String, dynamic>> users = [];

          for (String userId in connections) {
            DocumentSnapshot connectedUserDoc =
            await _firestore.collection('users').doc(userId).get();

            if (connectedUserDoc.exists && connectedUserDoc.data() != null) {
              Map<String, dynamic> userData =
              connectedUserDoc.data() as Map<String, dynamic>;
              users.add({
                'uid': userId,
                'firstName': userData['firstName'] ?? '',
                'lastName': userData['lastName'] ?? '',
                'email': userData['email'] ?? '',
              });
            }
          }

          setState(() {
            _connectedUsers = users;
          });
        }
      } catch (e) {
        print('Error fetching connections: $e');
      }
    }
  }

  void _openChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          peerUserId: userId,
          peerUserName: userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Messages',
          style: TextStyle(color: AppColors.textLight),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _connectedUsers.isNotEmpty
            ? ListView.builder(
          itemCount: _connectedUsers.length,
          itemBuilder: (context, index) {
            final user = _connectedUsers[index];
            return Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryGreen,
                  child: Text(
                    user['firstName'][0].toUpperCase(),
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
                title: Text(
                  '${user['firstName']} ${user['lastName']}',
                  style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  user['email'],
                  style: const TextStyle(color: AppColors.textDim),
                ),
                onTap: () {
                  _openChat(user['uid'],
                      '${user['firstName']} ${user['lastName']}');
                },
              ),
            );
          },
        )
            : const Center(
          child: Text(
            "No connections found",
            style: TextStyle(color: AppColors.textDim, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class MessageType {
  static const text = 'text';
  static const file = 'file';
}

class ChatScreen extends StatefulWidget {
  final String peerUserId;
  final String peerUserName;

  const ChatScreen({
    Key? key,
    required this.peerUserId,
    required this.peerUserName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;
  late String _chatRoomId;
  bool _isAttaching = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _chatRoomId = _getChatRoomId(_currentUserId, widget.peerUserId);
  }

  String _getChatRoomId(String user1, String user2) {
    return user1.compareTo(user2) > 0 ? '$user1-$user2' : '$user2-$user1';
  }

  Future<void> _sendMessage({String type = MessageType.text, String? fileUrl, String? fileName}) async {
    if (type == MessageType.text && _messageController.text.trim().isEmpty) return;

    String message = type == MessageType.text ? _messageController.text.trim() : fileName ?? 'File';
    _messageController.clear();

    try {
      await _firestore.collection('chatRooms').doc(_chatRoomId).set({
        'lastMessage': type == MessageType.text ? message : 'Sent a file: $fileName',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [_currentUserId, widget.peerUserId],
      }, SetOptions(merge: true));

      await _firestore
          .collection('chatRooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': _currentUserId,
        'message': message,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> _attachFile() async {
    setState(() => _isAttaching = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = path.basename(file.path);

        // Upload file to Firebase Storage
        Reference storageRef = _storage
            .ref()
            .child('chat_files')
            .child(_chatRoomId)
            .child(DateTime.now().millisecondsSinceEpoch.toString() + '_' + fileName);

        UploadTask uploadTask = storageRef.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String fileUrl = await snapshot.ref.getDownloadURL();

        await _sendMessage(
          type: MessageType.file,
          fileUrl: fileUrl,
          fileName: fileName,
        );
      }
    } catch (e) {
      print('Error attaching file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to attach file')),
      );
    } finally {
      setState(() => _isAttaching = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Stream<QuerySnapshot> _getChatStream() {
    return _firestore
        .collection('chatRooms')
        .doc(_chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  Widget _buildMessageBubble(DocumentSnapshot message, bool isMe) {
    final messageData = message.data() as Map<String, dynamic>;
    final timestamp = messageData['timestamp'] as Timestamp?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8.0,
          left: isMe ? 64.0 : 8.0,
          right: isMe ? 8.0 : 64.0,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 16.0,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryGreen : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messageData['type'] == MessageType.file)
              GestureDetector(
                onTap: () {
                  // Handle file opening logic here
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attachment,
                      color: isMe ? AppColors.textLight : AppColors.textDim,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        messageData['fileName'] ?? 'File',
                        style: TextStyle(
                          color: isMe ? AppColors.textLight : AppColors.textDim,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                messageData['message'] ?? '',
                style: TextStyle(
                  color: isMe ? AppColors.textLight : AppColors.textLight,
                  fontSize: 16.0,
                ),
              ),
            const SizedBox(height: 4),
            if (timestamp != null)
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  color: (isMe ? AppColors.textLight : AppColors.textDim)
                      .withOpacity(0.7),
                  fontSize: 12.0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          widget.peerUserName,
          style: const TextStyle(color: AppColors.textLight),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getChatStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.textDim),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                    ),
                  );
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    var messageData = message.data() as Map<String, dynamic>;
                    bool isMe = messageData['senderId'] == _currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            color: AppColors.surfaceDark,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attachment,
                      color: _isAttaching
                          ? AppColors.primaryGreen
                          : AppColors.textDim,
                    ),
                    onPressed: _isAttaching ? null : _attachFile,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: AppColors.textLight),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: AppColors.textDim),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                        onSubmitted: (_) =>
                            _sendMessage(type: MessageType.text),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: AppColors.primaryGreen,
                    onPressed: () => _sendMessage(type: MessageType.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
