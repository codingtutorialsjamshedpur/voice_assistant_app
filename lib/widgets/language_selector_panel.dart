import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/language_model.dart';
import '../../constants/language_constants.dart';

class LanguageSelectorPanel extends StatefulWidget {
  final Function(LanguageModel) onLanguageSelected;
  final LanguageModel? selectedLanguage;

  const LanguageSelectorPanel({
    super.key,
    required this.onLanguageSelected,
    this.selectedLanguage,
  });

  @override
  State<LanguageSelectorPanel> createState() => _LanguageSelectorPanelState();
}

class _LanguageSelectorPanelState extends State<LanguageSelectorPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<LanguageGroup> _tabs = [
    LanguageGroup.main,
    LanguageGroup.nativeIndian,
    LanguageGroup.international,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildTabBar(),
          _buildLanguageList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Language',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Main'),
          Tab(text: 'Indian'),
          Tab(text: 'International'),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    return SizedBox(
      height: 250,
      child: TabBarView(
        controller: _tabController,
        children: _tabs.map((group) => _buildLanguageGrid(group)).toList(),
      ),
    );
  }

  Widget _buildLanguageGrid(LanguageGroup group) {
    final languages = kAllLanguages.where((l) => l.group == group).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final language = languages[index];
        final isSelected = widget.selectedLanguage?.code == language.code;

        return _buildLanguageCard(language, isSelected);
      },
    );
  }

  Widget _buildLanguageCard(LanguageModel language, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onLanguageSelected(language);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4), blurRadius: 10)
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              language.flag,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              language.nativeName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              language.name,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 16),
          ],
        ),
      ),
    );
  }
}

void showLanguageSelectorSheet(
  BuildContext context, {
  LanguageModel? selectedLanguage,
  required Function(LanguageModel) onLanguageSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => LanguageSelectorPanel(
      selectedLanguage: selectedLanguage,
      onLanguageSelected: (language) {
        onLanguageSelected(language);
        Navigator.of(context).pop();
      },
    ),
  );
}
