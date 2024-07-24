import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:speech_to_text/speech_to_text.dart';
// import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini gemini = Gemini.instance;
  final SpeechToText speechToText = SpeechToText();
  bool speechEnabled = false;
  String wordsSpoken = "";
  List<ChatUser> typing = [];
  List<ChatMessage> messages = [];
  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
      id: "1",
      firstName: "Gemini",
      profileImage: "assets/google-gemini-icon.png");

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  void initSpeech() async {
    speechEnabled = await speechToText.initialize();
    setState(() {});
  }

  void startListening() async {
    await speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void stopListening() async {
    await speechToText.stop();
    setState(() {
      wordsSpoken = "";
    });
  }

  void _onSpeechResult(result) async {
    setState(() {
      wordsSpoken = "${result.recognizedWords}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Gemini Chat"),
      ),
      body: _buildUi(),
    );
  }

  Widget _buildUi() {
    return DashChat(
        inputOptions: InputOptions(alwaysShowSend: true, trailing: [
          speechEnabled
              ? IconButton(
                  onPressed: () {
                    startListening();
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            icon: const Icon(Icons.hearing),
                            backgroundColor:
                                const Color.fromARGB(255, 21, 21, 21),
                            title: const Text(
                              "...Listening",
                              style: TextStyle(color: Colors.white),
                            ),
                            content: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                                stopListening();
                                ChatMessage message = ChatMessage(
                                  user: currentUser,
                                  createdAt: DateTime.now(),
                                  text: wordsSpoken,
                                );
                                onSend(message);
                              },
                              child: const Icon(Icons.mic),
                            ),
                          );
                        });
                  },
                  icon: const Icon(Icons.mic_none))
              : const Icon(Icons.mic_off),
        ]),
        currentUser: currentUser,
        onSend: onSend,
        messageListOptions: const MessageListOptions(
          scrollPhysics: BouncingScrollPhysics(),
        ),
        typingUsers: typing,
        messages: messages);
  }

  void onSend(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
      typing.add(geminiUser);
    });
    try {
      List<Uint8List>? images = [];
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }
      String question = chatMessage.text;
      gemini.streamGenerateContent(question, images: images).listen((event) {
        ChatMessage? lastMessage = messages.firstOrNull;
        if (lastMessage != null && lastMessage.user == geminiUser) {
          lastMessage = messages.removeAt(0);
          String? response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          lastMessage.text += response;
          setState(() {
            messages = [lastMessage!, ...messages];
          });
        } else {
          String? response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          ChatMessage message = ChatMessage(
              user: geminiUser, createdAt: DateTime.now(), text: response);
          setState(() {
            messages = [message, ...messages];
          });
        }
      });
    } catch (e) {
      print(e);
    }
    setState(() {
      typing.remove(geminiUser);
    });
  }

  // for Image;

  // Future<void> sendMediaMessage() async {
  //   ImagePicker picker = ImagePicker();
  //   XFile? file = await picker.pickImage(source: ImageSource.gallery);
  //   if (file != null) {
  //     ChatMessage message = ChatMessage(
  //         user: currentUser,
  //         createdAt: DateTime.now(),
  //         text: "Describe this Picture?",
  //         medias: [
  //           ChatMedia(url: file.path, fileName: "", type: MediaType.image),
  //         ]);
  //     onSend(message);
  //   }
  // }
}
