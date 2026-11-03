// import 'dart:convert';
// import 'dart:typed_data';

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'package:whoxa/core/utils/logger.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/utils/constants/app_colors.dart';
// import 'package:whoxa/utils/constants/message_type.dart';
// import 'package:whoxa/utils/logger.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

// class GifScreen extends StatefulWidget {
//   final String userId;

//   const GifScreen({
//     Key? key,
//     required this.userId,
//   }) : super(key: key);

//   @override
//   State<GifScreen> createState() => _GifScreenState();
// }

// class _GifScreenState extends State<GifScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final ConsoleAppLogger _logger = ConsoleAppLogger();
//   final String _apiKey = "YOUR_GIPHY_API_KEY"; // Replace with your actual GIPHY API key

//   List<GifItem> _gifs = [];
//   bool _isLoading = false;
//   String _error = '';

//   @override
//   void initState() {
//     super.initState();
//     _fetchTrendingGifs();
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   Future<void> _fetchTrendingGifs() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       final response = await http.get(
//         Uri.parse('https://api.giphy.com/v1/gifs/trending?api_key=$_apiKey&limit=25&rating=g'),
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
        
//         List<GifItem> gifs = [];
//         for (var gifData in data['data']) {
//           gifs.add(
//             GifItem(
//               id: gifData['id'],
//               url: gifData['images']['fixed_height']['url'],
//               previewUrl: gifData['images']['fixed_height_small']['url'],
//             ),
//           );
//         }

//         setState(() {
//           _gifs = gifs;
//           _isLoading = false;
//         });
//       } else {
//         setState(() {
//           _isLoading = false;
//           _error = 'Failed to load GIFs: ${response.statusCode}';
//         });
//       }
//     } catch (e) {
//       _logger.e('Error fetching trending GIFs: $e');
//       setState(() {
//         _isLoading = false;
//         _error = 'Network error. Please try again.';
//       });
//     }
//   }

//   Future<void> _searchGifs(String query) async {
//     if (query.isEmpty) {
//       _fetchTrendingGifs();
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       final response = await http.get(
//         Uri.parse('https://api.giphy.com/v1/gifs/search?api_key=$_apiKey&q=$query&limit=25&rating=g'),
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
        
//         List<GifItem> gifs = [];
//         for (var gifData in data['data']) {
//           gifs.add(
//             GifItem(
//               id: gifData['id'],
//               url: gifData['images']['fixed_height']['url'],
//               previewUrl: gifData['images']['fixed_height_small']['url'],
//             ),
//           );
//         }

//         setState(() {
//           _gifs = gifs;
//           _isLoading = false;
//         });
//       } else {
//         setState(() {
//           _isLoading = false;
//           _error = 'Failed to search GIFs: ${response.statusCode}';
//         });
//       }
//     } catch (e) {
//       _logger.e('Error searching GIFs: $e');
//       setState(() {
//         _isLoading = false;
//         _error = 'Network error. Please try again.';
//       });
//     }
//   }

//   Future<void> _selectGif(GifItem gif) async {
//     try {
//       // Show loading indicator
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => Center(
//           child: CircularProgressIndicator(),
//         ),
//       );

//       // Download the GIF
//       final response = await http.get(Uri.parse(gif.url));
      
//       if (response.statusCode == 200) {
//         // Convert response bytes to Uint8List
//         final Uint8List bytes = response.bodyBytes;
        
//         // Get the chat provider
//         final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        
//         // Get chat ID
//         final chatId = chatProvider.currentChatData.chatId ?? 0;
        
//         if (chatId > 0) {
//           // Send the GIF
//           await chatProvider.sendMessage(
//             chatId,
//             gif.url,
//             messageType: MessageType.gif.name,
//             bytes: bytes,
//           );
          
//           // Close loading dialog and this screen
//           Navigator.of(context).pop(); // Close loading dialog
//           Navigator.of(context).pop(); // Close GIF screen
//         } else {
//           // Get chat ID first, then send message
//           final success = await chatProvider.getChatId(widget.userId);
          
//           if (success) {
//             final newChatId = chatProvider.currentChatData.chatId ?? 0;
            
//             if (newChatId > 0) {
//               // Send the GIF
//               await chatProvider.sendMessage(
//                 newChatId,
//                 gif.url,
//                 messageType: MessageType.gif.name,
//                 bytes: bytes,
//               );
              
//               // Close loading dialog and this screen
//               Navigator.of(context).pop(); // Close loading dialog
//               Navigator.of(context).pop(); // Close GIF screen
//             } else {
//               // Show error
//               Navigator.of(context).pop(); // Close loading dialog
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Failed to get chat ID')),
//               );
//             }
//           } else {
//             // Show error
//             Navigator.of(context).pop(); // Close loading dialog
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Failed to get chat ID')),
//             );
//           }
//         }
//       } else {
//         // Show error
//         Navigator.of(context).pop(); // Close loading dialog
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to download GIF')),
//         );
//       }
//     } catch (e) {
//       _logger.e('Error selecting GIF: $e');
      
//       // Close loading dialog if open
//       Navigator.of(context).pop(); 
      
//       // Show error
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to send GIF: ${e.toString()}')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Select a GIF'),
//         backgroundColor: AppColors.appPriSecColor.primaryColor,
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           // Search bar
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: 'Search GIFs',
//                 prefixIcon: Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide(color: Colors.grey[300]!),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide(color: Colors.grey[300]!),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide(color: AppColors.appPriSecColor.primaryColor),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey[100],
//                 contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//               ),
//               onSubmitted: _searchGifs,
//               textInputAction: TextInputAction.search,
//             ),
//           ),
          
//           // Error message
//           if (_error.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Text(
//                 _error,
//                 style: TextStyle(color: Colors.red),
//                 textAlign: TextAlign.center,
//               ),
//             ),
          
//           // GIFs grid or loading indicator
//           Expanded(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : _gifs.isEmpty
//                     ? Center(child: Text('No GIFs found'))
//                     : GridView.builder(
//                         padding: EdgeInsets.all(8.0),
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 2,
//                           childAspectRatio: 1.0,
//                           crossAxisSpacing: 8.0,
//                           mainAxisSpacing: 8.0,
//                         ),
//                         itemCount: _gifs.length,
//                         itemBuilder: (context, index) {
//                           final gif = _gifs[index];
//                           return GestureDetector(
//                             onTap: () => _selectGif(gif),
//                             child: Card(
//                               elevation: 2.0,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(10.0),
//                               ),
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(10.0),
//                                 child: Image.network(
//                                   gif.previewUrl,
//                                   fit: BoxFit.cover,
//                                   loadingBuilder: (context, child, loadingProgress) {
//                                     if (loadingProgress == null) return child;
//                                     return Center(
//                                       child: CircularProgressIndicator(
//                                         value: loadingProgress.expectedTotalBytes != null
//                                             ? loadingProgress.cumulativeBytesLoaded /
//                                                 loadingProgress.expectedTotalBytes!
//                                             : null,
//                                       ),
//                                     );
//                                   },
//                                   errorBuilder: (context, error, stackTrace) => Center(
//                                     child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class GifItem {
//   final String id;
//   final String url;
//   final String previewUrl;

//   GifItem({
//     required this.id,
//     required this.url,
//     required this.previewUrl,
//   });
// }