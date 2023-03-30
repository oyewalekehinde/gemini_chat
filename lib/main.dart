import 'dart:io';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:gemini_chat/constants.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  Gemini.init(apiKey: geminiKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Gemini Chat'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ChatUser currentUser = ChatUser(id: "0", firstName: "John", lastName: "Doe");
  ChatUser gemiUser = ChatUser(
    id: "1",
    firstName: "Gemini",
    profileImage:
        "https://firebasestorage.googleapis.com/v0/b/capevi-680e0.appspot.com/o/google-gemini-logo-png_seeklogo-515013.png?alt=media&token=497c54d0-dbd3-4db9-b790-65948d1a52d7",
  );

  List<ChatMessage> messages = [];
  final Gemini gemini = Gemini.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hello Gemini!")),
      body: DashChat(
        inputOptions: InputOptions(
          trailing: [
            IconButton(onPressed: sendMediaMessage, icon: Icon(Icons.image)),
          ],
        ),
        currentUser: currentUser,
        onSend: onSend,
        messages: messages,
      ),
    );
  }

  void sendMediaMessage() async {
    ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ChatMessage message = ChatMessage(
        text: "Describe this image",
        user: currentUser,
        medias: [
          ChatMedia(url: image.path, fileName: "", type: MediaType.image),
        ],
        createdAt: DateTime.now(),
      );
      onSend(message);
    }
  }

  void onSend(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });
    try {
      String question = chatMessage.text;
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [File(chatMessage.medias!.first.url).readAsBytesSync()];
        question = "Describe this image";
      }
      gemini
          .promptStream(
            parts: [
              Part.text(question),
              if (images != null) ...images.map((e) => Part.bytes(e)),
            ],
          )
          .listen((event) {
            ChatMessage? lastMessage = messages.firstOrNull;
            if (lastMessage != null && lastMessage.user == gemiUser) {
              lastMessage = messages.removeAt(0);
              String response =
                  event?.content?.parts?.fold(
                    "",
                    (previous, Part current) =>
                        "$previous ${current.runtimeType == TextPart ? (current as TextPart).text : ""}",
                  ) ??
                  "";
              lastMessage.text += response;
              setState(() {
                messages = [lastMessage!, ...messages];
              });
            } else {
              String response =
                  event?.content?.parts?.fold(
                    "",
                    (previous, current) =>
                        "$previous ${current.runtimeType == TextPart ? (current as TextPart).text : ""}",
                  ) ??
                  "";
              ChatMessage message = ChatMessage(
                text: response,
                user: gemiUser,
                createdAt: DateTime.now(),
              );
              setState(() {
                messages = [message, ...messages];
              });
            }
          });
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
