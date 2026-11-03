// CREATE TABLE translations [
//     id SERIAL PRIMARY KEY,
//     key VARCHAR[255] UNIQUE NOT NULL,
//     english TEXT NOT NULL
// ];

// INSERT INTO translations  VALUES

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyWidgetLang extends StatefulWidget {
  const MyWidgetLang({super.key});

  @override
  State<MyWidgetLang> createState() => _MyWidgetLangState();
}

class _MyWidgetLangState extends State<MyWidgetLang> {
  List<List<String>> ll = [
    ["Search contacts", "Search contacts"],
    ["No contacts available for chat", "No contacts available for chat"],
    ["No contacts to invite", "No contacts to invite"],
    ["Loading chats", "Loading chats"],
    ["Search name or number", "Search name or number"],
    ["Add", "Add"],
    [
      "What's this group about? (Optional)",
      "What's this group about? (Optional)",
    ],
    ["Members", "Members"],
    ["out of", "out of"],
    ["Please enter a group name", "Please enter a group name"],
    ["Creating Group", "Creating Group"],
    ["Message pinned for", "Message pinned for"],
    ["Unpinning", "Unpinning"],
    ["Pinning", "Pinning"],
    ["Invite friends to", "Invite friends to"],
    [
      "Join me on Flickpitch! Download the app and start chatting",
      "Join me on Flickpitch! Download the app and start chatting",
    ],
    ["Share Link", "Share Link"],
    ["Copy Link", "Copy Link"],
    ["Pin Message", "Pin Message"],
    ["You can unpin at any time", "You can unpin at any time"],
    ["Hours", "Hours"],
    ["Days", "Days"],
    [
      "This will delete all messages from this chat. This action cannot be undone.",
      "This will delete all messages from this chat. This action cannot be undone.",
    ],
    ["Blocked", "Blocked"],
    ["Unblocked", "Unblocked"],
    ["Docs", "Docs"],
    ["Chat color", "Chat color"],
    ["Are you sure you want to Delete?", "Are you sure you want to Delete?"],
    ["Deleting", "Deleting"],
  ];
  bool isLoading = false;
  Future<void> sendKeysToApi(
    List<List<String>> extractedKeywords,
    String token,
  ) async {
    var url = Uri.parse("https://YOUR_ADMIN_URL/api/admin/add-keyword");

    for (var item in extractedKeywords) {
      for (var word in item) {
        try {
          var request = http.MultipartRequest("POST", url);

          // form-data field
          request.fields["key"] = word;

          // ✅ Add Authorization token (Bearer or your API’s format)
          request.headers["Authorization"] = "Bearer $token";

          var response = await request.send();

          if (response.statusCode == 200) {
            var body = await response.stream.bytesToString();
            debugPrint("✅ Success for '$word': $body");
          } else {
            var body = await response.stream.bytesToString();
            debugPrint(
              "❌ Failed for '$word' | Status: ${response.statusCode}, Body: $body",
            );
          }
        } catch (e) {
          debugPrint("⚠️ Error for '$word': $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Keys")),
      body: Center(
        child:
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: () async {
                    await sendKeysToApi(
                      ll,
                      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG1pbl9pZCI6MSwidXNlcl90eXBlIjoiYWRtaW4iLCJpYXQiOjE3NjIzMjI2NjF9.myOBgYlOzXgxD05KxPBmOG6ZDtI_bCsX114v6tzmfQI",
                    );
                  },
                  child: Text("Send Keys to API"),
                ),
      ),
    );
  }
}
