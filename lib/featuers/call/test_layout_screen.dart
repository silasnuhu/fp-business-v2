// ignore_for_file: sized_box_for_whitespace

import 'package:flutter/material.dart';

class TestLayoutScreen extends StatefulWidget {
  const TestLayoutScreen({super.key});

  @override
  State<TestLayoutScreen> createState() => _TestLayoutScreenState();
}

class _TestLayoutScreenState extends State<TestLayoutScreen> {
  List<MockParticipant> mockParticipants = [];
  int participantCounter = 1;

  @override
  Widget build(BuildContext context) {
    final totalCount = mockParticipants.length + 1; // +1 for local user

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Test Layout ($totalCount participants)',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.green),
            onPressed: _addParticipant,
            tooltip: 'Add Participant',
          ),
          IconButton(
            icon: Icon(Icons.person_remove, color: Colors.red),
            onPressed: _removeParticipant,
            tooltip: 'Remove Participant',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Video grid using same layout logic as call_ui.dart
          _buildTestVideoGrid(totalCount),

          // Controls overlay with participant count info
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Participants: $totalCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _addParticipant,
                  icon: Icon(Icons.person_add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _removeParticipant,
                  icon: Icon(Icons.person_remove),
                  label: Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _resetParticipants,
                  icon: Icon(Icons.refresh),
                  label: Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Scroll indicator for groups with 5+ participants
          if (totalCount > 4)
            Positioned(
              bottom: 100,
              right: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_vertical,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Scroll',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addParticipant() {
    setState(() {
      mockParticipants.add(
        MockParticipant(
          name: 'User $participantCounter',
          userId: participantCounter.toString(),
          peerId: 'peer_$participantCounter',
        ),
      );
      participantCounter++;
    });
  }

  void _removeParticipant() {
    if (mockParticipants.isNotEmpty) {
      setState(() {
        mockParticipants.removeLast();
      });
    }
  }

  void _resetParticipants() {
    setState(() {
      mockParticipants.clear();
      participantCounter = 1;
    });
  }

  Widget _buildTestVideoGrid(int totalCount) {
    // Use same layout logic as call_ui.dart
    if (totalCount == 2) {
      return _build2ParticipantLayout();
    }

    if (totalCount == 3) {
      return _build3ParticipantLayout();
    }

    // Special handling for 4 participants - custom 50%+50% layout
    if (totalCount == 4) {
      return _build4ParticipantLayout();
    }

    // For 5+ participants, use 2x2 GridView layout with scrolling
    final gridLayout = _calculateOptimalGridLayout(totalCount, context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          padding: EdgeInsets.all(gridLayout.padding),
          child: GridView.builder(
            // Enable scrolling for 5+ participants, otherwise clamp to prevent bounce
            physics:
                totalCount > 4
                    ? BouncingScrollPhysics()
                    : ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridLayout.crossAxisCount,
              crossAxisSpacing: gridLayout.spacing,
              mainAxisSpacing: gridLayout.spacing,
              childAspectRatio: gridLayout.aspectRatio,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildTestVideoTile(name: 'You (Local)', isLocal: true);
              } else {
                final participantIndex = index - 1;
                if (participantIndex < mockParticipants.length) {
                  final participant = mockParticipants[participantIndex];
                  return _buildTestVideoTile(
                    name: participant.name,
                    userId: participant.userId,
                  );
                } else {
                  return _buildTestVideoTile(name: 'Loading...');
                }
              }
            },
          ),
        );
      },
    );
  }

  // Same layout calculation as call_ui.dart
  GridLayoutConfig _calculateOptimalGridLayout(
    int participantCount,
    BuildContext context,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    // 1 user → Fullscreen
    if (participantCount == 1) {
      return GridLayoutConfig(
        crossAxisCount: 1,
        aspectRatio: isLandscape ? 16 / 9 : 9 / 16,
        spacing: 0,
        padding: 0,
      );
    }

    // 2 users → 1 row, 2 columns
    if (participantCount == 2) {
      return GridLayoutConfig(
        crossAxisCount: 2,
        aspectRatio: isLandscape ? 4 / 3 : 3 / 4,
        spacing: 6.0,
        padding: 8.0,
      );
    }

    // 3 users → 2 rows: 2 on top, 1 centered on bottom
    if (participantCount == 3) {
      return GridLayoutConfig(
        crossAxisCount: 2,
        aspectRatio: 4 / 3,
        spacing: 6.0,
        padding: 8.0,
      );
    }

    // 4+ users → Use same 2x2 grid size for consistent large tiles with scrolling
    return GridLayoutConfig(
      crossAxisCount: 2, // Always 2 columns for large, consistent tiles
      aspectRatio:
          isLandscape ? 1.4 : 0.9, // Same large size as 4-participant layout
      spacing: 6.0, // Consistent spacing for clean look
      padding: 8.0, // Balanced padding for optimal use of screen space
    );
  }

  Widget _build2ParticipantLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = 8.0;
        final spacing = 12.0;

        return Container(
          padding: EdgeInsets.only(
            top: 80,
            bottom: 120,
            left: padding,
            right: padding,
          ),
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.only(bottom: spacing / 2),
                  child: _buildTestVideoTile(
                    name: 'You (Local)',
                    isLocal: true,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.only(top: spacing / 2),
                  child:
                      mockParticipants.isNotEmpty
                          ? _buildTestVideoTile(name: mockParticipants[0].name)
                          : _buildTestVideoTile(name: 'Connecting...'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build3ParticipantLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final padding = 8.0;
        final spacing = 8.0;

        if (isLandscape) {
          return Container(
            padding: EdgeInsets.only(
              top: 80,
              bottom: 120,
              left: padding,
              right: padding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTestVideoTile(
                    name: 'You (Local)',
                    isLocal: true,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child:
                      mockParticipants.isNotEmpty
                          ? _buildTestVideoTile(name: mockParticipants[0].name)
                          : _buildTestVideoTile(name: 'User 1'),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child:
                      mockParticipants.length > 1
                          ? _buildTestVideoTile(name: mockParticipants[1].name)
                          : _buildTestVideoTile(name: 'User 2'),
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: EdgeInsets.only(
              top: 80,
              bottom: 120,
              left: padding,
              right: padding,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTestVideoTile(
                          name: 'You (Local)',
                          isLocal: true,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child:
                            mockParticipants.isNotEmpty
                                ? _buildTestVideoTile(
                                  name: mockParticipants[0].name,
                                )
                                : _buildTestVideoTile(name: 'User 1'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      width: constraints.maxWidth * 0.70,
                      child:
                          mockParticipants.length > 1
                              ? _buildTestVideoTile(
                                name: mockParticipants[1].name,
                              )
                              : _buildTestVideoTile(name: 'User 2'),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildTestVideoTile({
    required String name,
    String? userId,
    bool isLocal = false,
  }) {
    final colors = [
      Colors.blue.shade800,
      Colors.green.shade800,
      Colors.purple.shade800,
      Colors.orange.shade800,
      Colors.red.shade800,
      Colors.teal.shade800,
      Colors.indigo.shade800,
      Colors.pink.shade800,
    ];

    final colorIndex = (userId?.hashCode ?? name.hashCode) % colors.length;
    final tileColor = colors[colorIndex];

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocal ? Colors.green : Colors.grey.shade700,
            width: isLocal ? 2 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            // Simulated video content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Video Active',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Name label
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Status indicators
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Special layout for 4 participants: 2 participants top (50%), 2 participants bottom (50%)
  Widget _build4ParticipantLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = 8.0;
        final spacing = 8.0;

        return Container(
          padding: EdgeInsets.only(
            top: 80,
            bottom: 120,
            left: padding,
            right: padding,
          ),
          child: Column(
            children: [
              // Top half - First 2 participants (50% of screen)
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    // Local video (always first)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: spacing / 2,
                          bottom: spacing / 2,
                        ),
                        child: _buildTestVideoTile(
                          name: 'You (Local)',
                          isLocal: true,
                        ),
                      ),
                    ),
                    // Second participant
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          left: spacing / 2,
                          bottom: spacing / 2,
                        ),
                        child:
                            mockParticipants.isNotEmpty
                                ? _buildTestVideoTile(
                                  name: mockParticipants[0].name,
                                )
                                : _buildTestVideoTile(name: 'User 1'),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom half - Last 2 participants (50% of screen)
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    // Third participant
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: spacing / 2,
                          top: spacing / 2,
                        ),
                        child:
                            mockParticipants.length >= 2
                                ? _buildTestVideoTile(
                                  name: mockParticipants[1].name,
                                )
                                : _buildTestVideoTile(name: 'User 2'),
                      ),
                    ),
                    // Fourth participant
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          left: spacing / 2,
                          top: spacing / 2,
                        ),
                        child:
                            mockParticipants.length >= 3
                                ? _buildTestVideoTile(
                                  name: mockParticipants[2].name,
                                )
                                : _buildTestVideoTile(name: 'User 3'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MockParticipant {
  final String name;
  final String userId;
  final String peerId;

  MockParticipant({
    required this.name,
    required this.userId,
    required this.peerId,
  });
}

// Copy the GridLayoutConfig from call_ui.dart
class GridLayoutConfig {
  final int crossAxisCount;
  final double aspectRatio;
  final double spacing;
  final double padding;

  GridLayoutConfig({
    required this.crossAxisCount,
    required this.aspectRatio,
    required this.spacing,
    required this.padding,
  });
}
