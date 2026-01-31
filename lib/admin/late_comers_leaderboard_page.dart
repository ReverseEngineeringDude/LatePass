import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_detail_history_page.dart';
import 'package:latepass/shared/skeleton_loader.dart';

class LateComersLeaderboardPage extends StatefulWidget {
  const LateComersLeaderboardPage({super.key});

  @override
  State<LateComersLeaderboardPage> createState() =>
      _LateComersLeaderboardPageState();
}

class _LateComersLeaderboardPageState extends State<LateComersLeaderboardPage> {
  // Toggle State: 0 = Monthly, 1 = Yearly
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  void _onToggleChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _isLoading = true;
      _leaderboardData = [];
    });
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final now = DateTime.now();
      DateTime startDate;

      if (_selectedIndex == 0) {
        // Monthly: Start of current month
        startDate = DateTime(now.year, now.month, 1);
      } else {
        // Yearly: Start of current year
        startDate = DateTime(now.year, 1, 1);
      }

      // 1. Fetch all attendance logs for the period
      final query = await FirebaseFirestore.instance
          .collection('attendance')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Aggregate counts by studentId locally
      final Map<String, int> counts = {};
      
      for (var doc in query.docs) {
        final data = doc.data();
        final sid = data['studentId'] as String;
        counts[sid] = (counts[sid] ?? 0) + 1;
      }

      // 3. Convert to List and Sort
      List<Map<String, dynamic>> tempLeaderboard = [];
      final studentIds = counts.keys.toList();

      // Chunk reads if needed, but for now we do 1-by-1 or Future.wait
      // Given FlutterFire limits, let's just do sequential or parallel in small batches
      // For simplicity and speed in this demo, we'll fetch details for the top ranked ones
      
      // Sort IDs by count desc first to prioritize fetches? 
      // Actually we need details for all to show name. 
      // Let's assume < 100 students for now.
      
      for (String sid in studentIds) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(sid)
            .get();
        
        if (!studentDoc.exists) continue;

        tempLeaderboard.add({
          'student': studentDoc.data(),
          'studentId': sid,
          'count': counts[sid],
        });
      }

      tempLeaderboard.sort((a, b) => 
        (b['count'] as int).compareTo(a['count'] as int)
      );

      if (mounted) {
        setState(() {
          _leaderboardData = tempLeaderboard;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching leaderboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Late Comers Leaderboard"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _leaderboardData = [];
              });
              _fetchLeaderboard();
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildToggle(theme, isDark),
          Expanded(
            child: _isLoading
                ? _buildSkeletonList()
                : _leaderboardData.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _leaderboardData.length,
                        itemBuilder: (context, index) {
                          final item = _leaderboardData[index];
                          return _buildRankCard(item, index + 1, theme, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }



  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: 8, // Show 8 skeleton items
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.03)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank Circle Skeleton
                const SkeletonContainer.square(size: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
                const SizedBox(width: 16),
                // Name & Dept Skeleton
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       SkeletonContainer.rectangular(height: 16, width: 120),
                       SizedBox(height: 8),
                       SkeletonContainer.rectangular(height: 12, width: 80),
                    ],
                  ),
                ),
                // Score Badge Skeleton
                const SkeletonContainer.rectangular(height: 30, width: 40, borderRadius: BorderRadius.all(Radius.circular(12))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggle(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildToggleButton("This Month", 0, theme, isDark),
          _buildToggleButton("This Year", 1, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, int index, ThemeData theme, bool isDark) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onToggleChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected 
              ? theme.colorScheme.primary 
              : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankCard(
    Map<String, dynamic> item,
    int rank,
    ThemeData theme,
    bool isDark,
  ) {
    final student = item['student'] as Map<String, dynamic>;
    final studentName = student['name'] ?? 'Unknown';
    final dept = student['department'] ?? 'N/A';
    final count = item['count'] as int;

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = theme.disabledColor.withOpacity(0.3);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailHistoryPage(
                studentData: student,
                studentId: item['studentId'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: rank <= 3 ? rankColor : theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dept,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "$count",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.error,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "LATES",
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: theme.disabledColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No Records Found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No late comers for this period.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
