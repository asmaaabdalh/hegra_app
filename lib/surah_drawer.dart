import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class SurahDrawer extends StatefulWidget {
  final Function(int surahNumber, int firstPage) onSurahSelected;
  const SurahDrawer({super.key, required this.onSurahSelected});

  @override
  State<SurahDrawer> createState() => _SurahDrawerState();
}

class _SurahDrawerState extends State<SurahDrawer> {
  List<dynamic> surahList = [];
  List<dynamic> filteredList = [];

  @override
  void initState() {
    super.initState();
    loadMetadata();
  }

  Future<void> loadMetadata() async {
    String jsonData = await rootBundle.loadString("assets/metadata.json");
    surahList = json.decode(jsonData);
    filteredList = surahList;
    setState(() {});
  }

  void filterSurah(String text) {
    setState(() {
      filteredList = surahList.where((s) =>
          s["name"]["ar"].toString().contains(text) ||
          s["name"]["transliteration"]
              .toString()
              .toLowerCase()
              .contains(text.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            child: Text(
              "فهرس السور",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: filterSurah,
              decoration: const InputDecoration(
                hintText: "ابحث باسم السورة",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                var surah = filteredList[index];
                return ListTile(
                  title: Text(
                    "${surah["number"]}. ${surah["name"]["ar"]}",
                    textDirection: TextDirection.rtl,
                  ),
                  onTap: () {
                    widget.onSurahSelected(surah["number"], 1); // مؤقتًا page 1
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
