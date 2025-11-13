import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SurahIndexPage extends StatefulWidget {
  final Function(int pageNumber) onSurahSelected;

  const SurahIndexPage({super.key, required this.onSurahSelected});

  @override
  _SurahIndexPageState createState() => _SurahIndexPageState();
}

class _SurahIndexPageState extends State<SurahIndexPage> {
  List<dynamic> surahList = [];
  List<dynamic> filteredList = [];

  @override
  void initState() {
    super.initState();
    loadSurahMeta();
  }

  Future<void> loadSurahMeta() async {
    String data = await rootBundle.loadString("assets/quran_meta.json"); // اسم ملف الميتا
    surahList = json.decode(data);
    setState(() {
      filteredList = surahList;
    });
  }

  void filterSearch(String query) {
    setState(() {
      filteredList = surahList.where((surah) {
        String nameAr = surah["name"]["ar"];
        String nameEn = surah["name"]["en"];
        String transliteration = surah["name"]["transliteration"];

        return nameAr.contains(query) ||
            nameEn.toLowerCase().contains(query.toLowerCase()) ||
            transliteration.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("فهرس السور")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "ابحث باسم السورة...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: filterSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                var surah = filteredList[index];
                return ListTile(
                  title: Text(
                    surah["name"]["ar"],
                    textDirection: TextDirection.rtl,
                  ),
                  subtitle: Text(
                    "${surah["name"]["en"]} • ${surah["verses_count"]} آية",
                  ),
                  onTap: () {
                    widget.onSurahSelected(surah["number"]);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
