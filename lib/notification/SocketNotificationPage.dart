import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketNotificationPage extends StatefulWidget {
  const SocketNotificationPage({Key? key}) : super(key: key);

  @override
  _SocketNotificationPageState createState() => _SocketNotificationPageState();
}

class _SocketNotificationPageState extends State<SocketNotificationPage> {
  IO.Socket? socket;
  List<String> notifications = [];

  @override
  void initState() {
    super.initState();
    connectToSocket();
  }

  void connectToSocket() {
    // Replace with your backend socket URL
    socket = IO.io('http://YOUR_BACKEND_URL', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) {
      print('Connected to socket server');
    });

    // Listen for 'notification' event
    socket!.on('notification', (data) {
      print('Notification received: $data');
      setState(() {
        notifications.insert(0, data.toString());
      });
      showSnackBar(data.toString());
    });

    socket!.onDisconnect((_) {
      print('Disconnected from socket server');
    });
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Socket Notifications')),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(notifications[index]),
          );
        },
      ),
    );
  }
}
