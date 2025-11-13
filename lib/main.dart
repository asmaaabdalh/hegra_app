import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:firebase_core/firebase_core.dart';
//import 'firebase_options.dart';

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: "Roboto",
        primaryColor: Colors.brown,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const QuranHomePage(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Animation
            ScaleTransition(
              scale: _scaleAnimation,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  "assets/images/logo.jpeg", // Updated image path
                  width: 160,
                  height: 160,
                  errorBuilder: (context, error, stackTrace) {
                    // Show error widget if image fails to load
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.brown[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.brown[800],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Text Animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "القرآن الكريم",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.brown[600],
                      letterSpacing: 1.5,
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
}

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage>
    with SingleTickerProviderStateMixin {
  List<dynamic> surahList = [];
  List<dynamic> fullSurahList = [];
  List<dynamic> pagesList = [];

  int currentPage = 1;
  int? bookmarkedPage;

  bool _uiVisible = true;

  /// ✅ جديد (اسم السورة والجزء)
  String currentSurahName = "";
  int currentJuz = 1;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  // NEW: search debounce + ayah matches
  Timer? _searchDebounce;
  List<Map<String, dynamic>> ayahMatches = [];

  Map<int, List<Map<String, dynamic>>> surahIndex = {}; // cached normalized verses
  bool isIndexing = false;

  @override
  void initState() {
    super.initState();

    // initialize controller and a safe default slide animation to avoid null in build
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_controller);

    // load metadata and pages sequentially, then update surah/juz
    loadMetadata()
        .then((_) => loadPages())
        .then((_) => updateSurahAndJuz())
        .then((_) => _preloadSurahIndex()) // start background indexing
        .catchError((e) => debugPrint('load error: $e'));
  }

  Future<void> loadMetadata() async {
    String jsonString = await rootBundle.loadString("assets/metadata.json");
    setState(() {
      surahList = jsonDecode(jsonString);
      fullSurahList = List.from(surahList);
    });
  }

  Future<void> loadPages() async {
    String jsonString = await rootBundle.loadString("assets/pagesQuran.json");
    setState(() {
      pagesList = jsonDecode(jsonString);
    });
  }

  /// ✅ تحميل اسم السورة والجزء من ملفات surah_xx.json
  Future<void> updateSurahAndJuz() async {
    try {
      if (pagesList.isEmpty) return;

      // find page object safely
      Map<String, dynamic> pageObj = pagesList
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p.containsKey('page') && p['page'] == currentPage,
              orElse: () => <String, dynamic>{});

      if (pageObj.isEmpty) return;

      // safe access to nested fields
      final start = pageObj['start'];
      if (start == null || start is! Map || !start.containsKey('surah_number')) {
        return;
      }

      final surahNumber = start['surah_number'];
      if (surahNumber == null) return;

      // load surah file safely
      final raw =
          await rootBundle.loadString("assets/surah/surah_$surahNumber.json");
      final surah = jsonDecode(raw) as Map<String, dynamic>;

      final nameAr = (surah['name'] is Map) ? (surah['name']['ar'] ?? '') : '';
      int juzFromVerses = currentJuz;
      if (surah['verses'] is List && (surah['verses'] as List).isNotEmpty) {
        final firstVerse = (surah['verses'] as List).first;
        if (firstVerse is Map && firstVerse.containsKey('juz')) {
          final j = firstVerse['juz'];
          if (j is int) juzFromVerses = j;
        }
      }

      setState(() {
        currentSurahName = nameAr.toString();
        currentJuz = juzFromVerses;
      });
    } catch (e, st) {
      debugPrint("❌ updateSurahAndJuz error: $e\n$st");
    }
  }

  void goToSurah(int surahNumber) {
    final matchedPage = pagesList.firstWhere(
      (page) =>
          page["start"]["surah_number"] == surahNumber ||
          page["end"]["surah_number"] == surahNumber,
      orElse: () => null,
    );

    if (matchedPage != null) {
      setState(() => currentPage = matchedPage["page"]);
      updateSurahAndJuz();
    }
  }

  void saveBookmark() {
    setState(() => bookmarkedPage = currentPage);
  }

  void animatePageChange(bool forward) async {
    // prepare a slide animation for this transition
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(forward ? -0.3 : 0.3, 0),
    ).animate(_controller);

    try {
      await _controller.forward();
    } catch (e) {
      debugPrint('animation error: $e');
    } finally {
      _controller.reset();
      // update surah/juz after animation completes
      updateSurahAndJuz();
    }
  }

  // Replace the Drawer TextField onChanged handler with this helper:
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      performSearch(q.trim());
    });
  }

  // normalize Arabic text: remove tashkeel, tatweel and unify common letters
  String normalizeArabic(String input) {
    if (input.isEmpty) return input;
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final n = _normalizeChar(input[i]);
      if (n.isNotEmpty) buf.write(n);
    }
    return buf.toString();
  }

  // normalize a single char: return '' for removed diacritics/tatweel
  String _normalizeChar(String ch) {
    const diacritics = [
      '\u0610','\u0611','\u0612','\u0613','\u0614','\u0615','\u0616','\u0617','\u0618','\u0619','\u061A',
      '\u064B','\u064C','\u064D','\u064E','\u064F','\u0650','\u0651','\u0652','\u0653','\u0654','\u0655','\u0656','\u0657','\u0658','\u0659','\u065A','\u065B','\u065C','\u065D','\u065E','\u065F',
      '\u06D6','\u06D7','\u06D8','\u06D9','\u06DA','\u06DB','\u06DC','\u06DF','\u06E0','\u06E1','\u06E2','\u06E3','\u06E4','\u06E5','\u06E6','\u06E7','\u06E8','\u06EA','\u06EB','\u06EC','\u06ED',
      '\u0670','\u06D4','\u0640'
    ];
    if (diacritics.contains(ch)) return '';

    // unify alef variants to bare alef
    if (ch == '\u0622' || ch == '\u0623' || ch == '\u0625' || ch == '\u0671') return '\u0627';
    // convert alef maqsura (ى) to ya (ي)
    if (ch == '\u0649') return '\u064A';
    // convert taa marbuta to heh-like (keep 'ة' as is or map to 'ه' if desired)
    if (ch == '\u0629') return '\u0629';
    // remove tatweel already handled above
    // normalize waw/ya hamza variants to base letters (common normalization)
    if (ch == '\u0624') return '\u0648';
    if (ch == '\u0626') return '\u064A';
    // default: return lower-case of char (no case in Arabic but keep as-is)
    return ch;
  }

  // find index in original string corresponding to match in normalized text
  // returns tuple (startIndex, endIndex) or (-1, -1) if not found
  List<int> _findOriginalRangeForNormalizedMatch(String original, String normQuery) {
    final List<int> map = [];
    final StringBuffer normBuf = StringBuffer();
    for (int i = 0; i < original.length; i++) {
      final n = _normalizeChar(original[i]);
      if (n.isEmpty) continue;
      normBuf.write(n);
      // for characters that normalized to multiple chars (not here) you'd handle differently
      map.add(i);
    }
    final normStr = normBuf.toString().toLowerCase();
    final q = normQuery.toLowerCase();
    final idx = normStr.indexOf(q);
    if (idx == -1) return [-1, -1];
    final startOrig = map[idx];
    final endOrig = map[idx + q.length - 1] + 1;
    return [startOrig, endOrig];
  }

  // updated snippet maker that respects tashkeel-insensitive matches
  String _makeSnippet(String full, String q, {int radius = 30}) {
    if (full.isEmpty) return '';
    final normQ = normalizeArabic(q);
    if (normQ.isEmpty) {
      // fallback to plain truncation
      return full.length > 80 ? '${full.substring(0, 80)}…' : full;
    }
    final range = _findOriginalRangeForNormalizedMatch(full, normQ);
    if (range[0] == -1) {
      return full.length > 80 ? '${full.substring(0, 80)}…' : full;
    }
    final start = (range[0] - radius).clamp(0, full.length);
    final end = (range[1] + radius).clamp(0, full.length);
    final pre = start > 0 ? '…' : '';
    final post = end < full.length ? '…' : '';
    return '$pre${full.substring(start, end)}$post';
  }

  // use index when performing search (fast)
  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        surahList = List.from(fullSurahList);
        ayahMatches.clear();
      });
      return;
    }

    final normQuery = normalizeArabic(query).toLowerCase();

    // filter surah list (light)
    final filtered = fullSurahList.where((s) {
      final nameRaw = (s['name'] is String)
          ? s['name']
          : (s['name'] is Map ? (s['name']['ar'] ?? s['name']['en'] ?? '') : '');
      final name = normalizeArabic(nameRaw.toString()).toLowerCase();
      final eng = (s['englishName'] ?? '').toString().toLowerCase();
      return name.contains(normQuery) || eng.contains(query.toLowerCase());
    }).toList();

    final List<Map<String, dynamic>> found = [];

    // fast search using prebuilt index if available; otherwise fallback to previous slow method
    if (surahIndex.isNotEmpty) {
      for (final entry in surahIndex.entries) {
        final surahNum = entry.key;
        for (final v in entry.value) {
          final norm = (v['norm'] ?? '').toString();
          if (norm.contains(normQuery)) {
            found.add({
              'surah': surahNum,
              'surahName': v['surahName'] ?? '',
              'ayah': v['ayah'],
              'text': _makeSnippet(v['text'] ?? '', query),
              'page': v['page'],
            });
            if (found.length >= 200) break;
          }
        }
        if (found.length >= 200) break;
      }
    } else {
      // fallback to existing slower per-file search (keeps behavior)
      if (normQuery.length >= 1 && pagesList.isNotEmpty) {
        for (final s in fullSurahList) {
          int surahNumber;
          try {
            surahNumber = (s['number'] is int) ? s['number'] : int.parse((s['number'] ?? s['id'] ?? 0).toString());
          } catch (_) {
            continue;
          }
          try {
            final raw = await rootBundle.loadString('assets/surah/surah_$surahNumber.json');
            final surah = jsonDecode(raw);
            final verses = (surah is Map && surah['verses'] is List) ? surah['verses'] as List : <dynamic>[];
            final surahNameRaw = (surah['name'] is String)
                ? surah['name']
                : (surah['name'] is Map ? (surah['name']['ar'] ?? '') : '');

            for (int i = 0; i < verses.length; i++) {
              final v = verses[i];
              String verseText = '';
              if (v is Map) {
                verseText = (v['text'] ?? v['text_uthmani'] ?? v['verse'] ?? v['content'] ?? '').toString();
              } else {
                verseText = v.toString();
              }
              if (verseText.isEmpty) continue;

              final normVerse = normalizeArabic(verseText).toLowerCase();
              if (normVerse.contains(normQuery)) {
                final ayahNumber = (v is Map)
                    ? (v['numberInSurah'] ?? v['verse_number'] ?? v['aya'] ?? v['number'] ?? (i + 1))
                    : (i + 1);
                final snippet = _makeSnippet(verseText, query);
                final page = _findPageForVerse(surahNumber, ayahNumber);
                found.add({
                  'surah': surahNumber,
                  'surahName': surahNameRaw ?? '',
                  'ayah': ayahNumber,
                  'text': snippet,
                  'page': page,
                });
                if (found.length >= 200) break;
              }
            }
          } catch (e) {
            continue;
          }
          if (found.length >= 200) break;
        }
      }
    }

    setState(() {
      surahList = filtered;
      ayahMatches = found;
    });
  }

  // Duplicate non-normalized _makeSnippet removed to avoid name collision;
  // the normalized, tashkeel-insensitive _makeSnippet defined earlier is used.

  int? _findPageForVerse(int surahNumber, dynamic ayahNumber) {
    try {
      final p = pagesList.cast<Map<String, dynamic>>().firstWhere((page) {
        final start = page['start'];
        final end = page['end'];
        // safe extraction
        final startSurah = (start is Map) ? (start['surah_number'] ?? start['surah']) : null;
        final endSurah = (end is Map) ? (end['surah_number'] ?? end['surah']) : null;
        if (startSurah == null || endSurah == null) return false;
        if (surahNumber < startSurah || surahNumber > endSurah) return false;
        // if same surah, optionally check ayah ranges if available
        if (startSurah == surahNumber) {
          final startAyah = (start is Map) ? (start['ayah'] ?? start['verse'] ?? null) : null;
          if (startAyah is int && ayahNumber is int && ayahNumber < startAyah) return false;
        }
        if (endSurah == surahNumber) {
          final endAyah = (end is Map) ? (end['ayah'] ?? end['verse'] ?? null) : null;
          if (endAyah is int && ayahNumber is int && ayahNumber > endAyah) return false;
        }
        return true;
      }, orElse: () => <String, dynamic>{});
      if (p.isNotEmpty && p.containsKey('page')) return p['page'] as int;
    } catch (_) {}
    return null;
  }

  Future<void> _preloadSurahIndex() async {
    if (fullSurahList.isEmpty || pagesList.isEmpty) return;
    setState(() => isIndexing = true);

    // load raw surah files into a map of strings (so we can pass to compute)
    final Map<String, String> rawMap = {};
    for (final s in fullSurahList) {
      int surahNumber;
      try {
        surahNumber = (s['number'] is int) ? s['number'] : int.parse((s['number'] ?? s['id'] ?? 0).toString());
      } catch (_) {
        continue;
      }
      try {
        final raw = await rootBundle.loadString('assets/surah/surah_$surahNumber.json');
        rawMap[surahNumber.toString()] = raw;
      } catch (_) {
        // missing file: skip
      }
    }

    try {
      final dynamic result = await compute(_buildSurahIndex, {
        'rawMap': rawMap,
        'pagesList': pagesList,
      });
      // result is Map<String, List<Map<String, dynamic>>>
      final Map<String, dynamic> resMap = Map<String, dynamic>.from(result as Map);
      final Map<int, List<Map<String, dynamic>>> idx = {};
      resMap.forEach((k, v) {
        idx[int.parse(k)] = List<Map<String, dynamic>>.from(v as List);
      });
      setState(() {
        surahIndex = idx;
        isIndexing = false;
      });
      debugPrint('Indexing complete: ${surahIndex.length} surahs indexed.');
    } catch (e, st) {
      debugPrint('Indexing failed: $e\n$st');
      setState(() => isIndexing = false);
    }
  }

  // top-level helper for compute (must be a top-level or static function)
  static Map<String, dynamic> _buildSurahIndex(Map<String, dynamic> args) {
    final Map<String, String> rawMap = Map<String, String>.from(args['rawMap'] ?? {});
    final List<dynamic> pagesList = List<dynamic>.from(args['pagesList'] ?? []);
    final Map<String, List<Map<String, dynamic>>> out = {};

    String normalizeLocal(String input) {
      if (input.isEmpty) return input;
      final StringBuffer buf = StringBuffer();
      for (int i = 0; i < input.length; i++) {
        final ch = input[i];
        // reuse a small normalization similar to _normalizeChar
        const diacritics = [
          '\u0610','\u0611','\u0612','\u0613','\u0614','\u0615','\u0616','\u0617','\u0618','\u0619','\u061A',
          '\u064B','\u064C','\u064D','\u064E','\u064F','\u0650','\u0651','\u0652','\u0653','\u0654','\u0655','\u0656','\u0657','\u0658','\u0659','\u065A','\u065B','\u065C','\u065D','\u065E','\u065F',
          '\u06D6','\u06D7','\u06D8','\u06D9','\u06DA','\u06DB','\u06DC','\u06DF','\u06E0','\u06E1','\u06E2','\u06E3','\u06E4','\u06E5','\u06E6','\u06E7','\u06E8','\u06EA','\u06EB','\u06EC','\u06ED',
          '\u0670','\u06D4','\u0640'
        ];
        if (diacritics.contains(ch)) continue;
        if (ch == '\u0622' || ch == '\u0623' || ch == '\u0625' || ch == '\u0671') { buf.write('\u0627'); continue;}
        if (ch == '\u0649') { buf.write('\u064A'); continue;}
        if (ch == '\u0624') { buf.write('\u0648'); continue;}
        if (ch == '\u0626') { buf.write('\u064A'); continue;}
        buf.write(ch);
      }
      return buf.toString();
    }

    int? _findPageForVerseLocal(int surahNumber, dynamic ayahNumber) {
      try {
        final p = pagesList.cast<Map<String, dynamic>>().firstWhere((page) {
          final start = page['start'];
          final end = page['end'];
          final startSurah = (start is Map) ? (start['surah_number'] ?? start['surah']) : null;
          final endSurah = (end is Map) ? (end['surah_number'] ?? end['surah']) : null;
          if (startSurah == null || endSurah == null) return false;
          if (surahNumber < startSurah || surahNumber > endSurah) return false;
          if (startSurah == surahNumber) {
            final startAyah = (start is Map) ? (start['ayah'] ?? start['verse'] ?? null) : null;
            if (startAyah is int && ayahNumber is int && ayahNumber < startAyah) return false;
          }
          if (endSurah == surahNumber) {
            final endAyah = (end is Map) ? (end['ayah'] ?? end['verse'] ?? null) : null;
            if (endAyah is int && ayahNumber is int && ayahNumber > endAyah) return false;
          }
          return true;
        }, orElse: () => <String, dynamic>{});
        if (p.isNotEmpty && p.containsKey('page')) return p['page'] as int;
      } catch (_) {}
      return null;
    }

    rawMap.forEach((k, raw) {
      try {
        final surah = jsonDecode(raw) as Map<String, dynamic>;
        final verses = (surah['verses'] is List) ? surah['verses'] as List : <dynamic>[];
        final List<Map<String, dynamic>> list = [];
        for (int i = 0; i < verses.length; i++) {
          final v = verses[i];
          String verseText = '';
          if (v is Map) {
            verseText = (v['text'] ?? v['text_uthmani'] ?? v['verse'] ?? v['content'] ?? '').toString();
          } else {
            verseText = v.toString();
          }
          if (verseText.isEmpty) continue;
          final norm = normalizeLocal(verseText).toLowerCase();
          final ayahNumber = (v is Map)
              ? (v['numberInSurah'] ?? v['verse_number'] ?? v['aya'] ?? v['number'] ?? (i + 1))
              : (i + 1);
          final surahNum = int.parse(k);
          final page = _findPageForVerseLocal(surahNum, ayahNumber);
          list.add({
            'ayah': ayahNumber,
            'text': verseText,
            'norm': norm,
            'page': page,
            'surah': surahNum,
            'surahName': (surah['name'] is Map ? (surah['name']['ar'] ?? '') : surah['name'] ?? '')
          });
        }
        out[k] = list;
      } catch (_) {
        // ignore parse errors for single surah
      }
    });

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final slideAnim = _slideAnimation;

    return Scaffold(
      // show surah name + menu on right
      appBar: _uiVisible
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const SizedBox.shrink(),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSurahName.isNotEmpty ? currentSurahName : '...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.brown,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.brown),
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null,

      // end drawer with surah list (fixed menu)
      endDrawer: _uiVisible
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.brown,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      child: const Text(
                        "فهرس السور",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: "ابحث باسم السورة...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        // combined ayahMatches first, then surahList
                        itemCount: ayahMatches.length + surahList.length,
                        itemBuilder: (context, idx) {
                          if (idx < ayahMatches.length) {
                            final m = ayahMatches[idx];
                            final surahNum = m['surah'];
                            final surahName = m['surahName'] ?? 'سورة $surahNum';
                            final ayah = m['ayah'];
                            final snippet = m['text'] ?? '';
                            final page = m['page'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.brown[50],
                                child: Text('${surahNum}', style: const TextStyle(color: Colors.brown)),
                              ),
                              title: Text('$surahName : آية $ayah'),
                              subtitle: Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                Navigator.of(context).pop(); // close drawer
                                if (page is int) {
                                  setState(() => currentPage = page);
                                    setState(() {
                          ayahMatches.clear();
                          surahList = List.from(fullSurahList);
                        });
                                } else {
                                  goToSurah(surahNum);
                                }
                                updateSurahAndJuz();
                              },
                            );
                          } else {
                            final i = idx - ayahMatches.length;
                            final s = surahList[i] as Map<String, dynamic>;
                            final number = s['number'] ?? s['id'] ?? (i + 1);
                            final name = s['name'] is String
                                ? s['name']
                                : (s['name'] is Map
                                    ? (s['name']['ar'] ?? s['name']['en'] ?? '')
                                    : 'سورة $number');
                            return ListTile(
                              title: Text(name.toString()),
                              subtitle: Text("سورة $number"),
                              onTap: () {
                                Navigator.of(context).pop(); // close drawer
                                goToSurah(number is int ? number : int.parse(number.toString()));
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,

      // simplified body: no decorative frame, full-bleed centered page
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFFBF8), const Color(0xFFF5F2EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => setState(() => _uiVisible = !_uiVisible),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // image without frame / border
                Center(
                  child: SlideTransition(
                    position: slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                      child: pagesList.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : Image.asset(
                              "assets/quran_image/$currentPage.png",
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (ctx, err, stack) => Container(
                                color: Colors.brown[50],
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.broken_image, size: 48, color: Colors.brown),
                                    SizedBox(height: 8),
                                    Text('صورة الصفحة غير متوفرة',
                                        style: TextStyle(color: Colors.brown)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                if (_uiVisible && pagesList.isNotEmpty)
                  Positioned(
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.brown.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        "الجزء $currentJuz • صفحة $currentPage",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: _uiVisible
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.brown.shade100, width: 1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 28, color: Colors.brown),
                      onPressed: () {
                        if (currentPage < pagesList.length) {
                          animatePageChange(true);
                          setState(() => currentPage++);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(bookmarkedPage == currentPage ? Icons.bookmark : Icons.bookmark_border,
                          size: 30, color: Colors.brown),
                      onPressed: saveBookmark,
                    ),
                    if (bookmarkedPage != null)
                      IconButton(
                        icon: const Icon(Icons.bookmark_added, size: 30, color: Colors.green),
                        onPressed: () {
                          setState(() => currentPage = bookmarkedPage!);
                          updateSurahAndJuz();
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 28, color: Colors.brown),
                      onPressed: () {
                        if (currentPage > 1) {
                          animatePageChange(false);
                          setState(() => currentPage--);
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}