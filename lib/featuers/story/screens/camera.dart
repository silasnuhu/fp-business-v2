// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:whoxa/featuers/story/provider/story_provider.dart';

// class CameraScreen extends StatefulWidget {
//   const CameraScreen({super.key});

//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   @override
//   void initState() {
//     Future.microtask(() {
//       Provider.of<StoryProvider>(context, listen: false).initCamera();
//     });

//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Consumer<StoryProvider>(
//         builder: (context, storyProvider, _) {
//           if (!storyProvider.cameraController.value.isInitialized) {
//             return Center(child: CircularProgressIndicator());
//           }
//           return Stack(
//             children: [
//               CameraPreview(storyProvider.cameraController),
//               Positioned(
//                 bottom: 100,
//                 left: 0,
//                 right: 0,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     ElevatedButton(
//                       onPressed: () {
//                         setState(() {
//                           storyProvider.isVideoMode = false;
//                         });
//                       },
//                       child: Text('Photo'),
//                     ),
//                     SizedBox(width: 20),
//                     ElevatedButton(
//                       onPressed: () {
//                         setState(() {
//                           storyProvider.isVideoMode = true;
//                         });
//                       },
//                       child: Text('Video'),
//                     ),
//                   ],
//                 ),
//               ),
//               Positioned(
//                 bottom: 30,
//                 left: 0,
//                 right: 0,
//                 child: Center(
//                   child: FloatingActionButton(
//                     onPressed:
//                         storyProvider.isVideoMode
//                             ? storyProvider.handleVideo
//                             : storyProvider.capturePhoto,
//                     child: Icon(
//                       storyProvider.isVideoMode
//                           ? (storyProvider.isRecording
//                               ? Icons.stop
//                               : Icons.videocam)
//                           : Icons.camera_alt,
//                     ),
//                   ),
//                 ),
//               ),

//               if (storyProvider.isRecording)
//                 Positioned(
//                   top: 50,
//                   left: 20,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withValues(alpha: 0.6),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           Icons.fiber_manual_record,
//                           color: Colors.red,
//                           size: 16,
//                         ),
//                         SizedBox(width: 5),
//                         Text(
//                           storyProvider.formatDuration(
//                             storyProvider.recordDuration,
//                           ),
//                           style: TextStyle(color: Colors.black, fontSize: 16),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
