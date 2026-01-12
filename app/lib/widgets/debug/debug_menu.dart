import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'components/debug_copy_button.dart';
import 'tabs/overview_tab.dart';
import 'tabs/quests_tab.dart';
import 'tabs/sessions_tab.dart';
import 'tabs/lp_sync_tab.dart';
import 'tabs/actions_tab.dart';
import 'tabs/polling_tab.dart';
import 'tabs/steps_debug_tab.dart';

/// Enhanced debug menu with tab-based interface
class DebugMenu extends StatefulWidget {
  const DebugMenu({Key? key}) : super(key: key);

  @override
  State<DebugMenu> createState() => _DebugMenuState();
}

class _DebugMenuState extends State<DebugMenu> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getAllData() {
    // TODO: Implement comprehensive data collection
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'tab': _tabController.index,
      'note': 'Copy All functionality - to be implemented per tab',
    };
    return JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🐛 Debug Menu',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      DebugCopyButton(
                        data: _getAllData(),
                        message: 'All debug data copied',
                        isLarge: true,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Actions'),
                  Tab(text: 'Steps'),
                  Tab(text: 'Polling'),
                  Tab(text: 'Overview'),
                  Tab(text: 'Quests'),
                  Tab(text: 'Sessions'),
                  Tab(text: 'LP & Sync'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: Container(
                color: const Color(0xFFFFFEFD),
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    ActionsTab(),
                    StepsDebugTab(),
                    PollingTab(),
                    OverviewTab(),
                    QuestsTab(),
                    SessionsTab(),
                    LpSyncTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
