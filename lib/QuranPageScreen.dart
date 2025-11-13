import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuranPageScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;

  const QuranPageScreen({
    Key? key,
    required this.surahNumber,
    required this.surahName,
  }) : super(key: key);

  @override
  State<QuranPageScreen> createState() => _QuranPageScreenState();
}

class _QuranPageScreenState extends State<QuranPageScreen> {
  List<dynamic> pages = [];
  late PageController _pageController;
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    loadSurahPages();
  }

  Future<void> loadSurahPages() async {
    final String jsonString =
        await rootBundle.loadString("assets/pagesQuran.json");

    final List<dynamic> allPages = json.decode(jsonString);

    pages = allPages.where((p) => p["surah"] == widget.surahNumber).toList();

    if (mounted) {
      setState(() {});
    }
  }

  // ⇦ التالي (سهم للشمال)
  void _goToNextPage() {
    if (currentPageIndex < pages.length - 1) {
      currentPageIndex++;
      _pageController.animateToPage(
        currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ⇨ السابق (سهم لليمين)
  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      currentPageIndex--;
      _pageController.animateToPage(
        currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName, textDirection: TextDirection.rtl),
      ),
      body: pages.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    reverse: true, // مهم جدًا علشان يبقى زي المصحف
                    onPageChanged: (index) {
                      setState(() => currentPageIndex = index);
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Image.asset(
                          pages[index]["image"],
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),

                // ✅ الأسهم للانتقال بين الصفحات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_left, size: 32),
                      onPressed: _goToNextPage,
                    ),
                    Text(
                      "${currentPageIndex + 1} / ${pages.length}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right, size: 32),
                      onPressed: _goToPreviousPage,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
    );
  }
}
