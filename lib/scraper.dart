import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Announcement {
  final String date;
  final String text;
  final String link;
  Announcement({required this.date, required this.text, required this.link});
}

class MealDay {
  final String dateString;
  final int dayInt;
  final List<String> meals;
  MealDay({
    required this.dateString,
    required this.dayInt,
    required this.meals,
  });
}

class Source {
  final String name;
  final String url;
  Source({required this.name, required this.url});

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
  factory Source.fromJson(Map<String, dynamic> json) =>
      Source(name: json['name'], url: json['url']);
}

Future<List<Announcement>> fetchAnnouncements(String url) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) return [];
  final doc = parser.parse(res.body);
  List<Announcement> announcements = [];
  final items = doc.querySelectorAll('section .list-group .list-group-item');
  for (var item in items) {
    final dateElem = item.querySelector('.col-2');
    final aTag = item.querySelector('.col-10 a');

    if (aTag == null || dateElem == null) continue;
    final date = dateElem.text.trim();
    final text = aTag.text.trim();

    final href = aTag.attributes['href'] ?? '';

    final uri = Uri.parse(url);
    final link = href.startsWith('http')
        ? href
        : '${uri.scheme}://${uri.host}$href';

    if (link.isEmpty) continue;
    announcements.add(Announcement(date: date, text: text, link: link));
  }
  return announcements;
}

Future<List<Source>> loadSources() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('saved_sources_v1') ?? [];
  return jsonList
      .map((e) => Source.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

Future<void> saveSources(List<Source> sources) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = sources.map((s) => s.toJson().toString()).toList();
  await prefs.setStringList('saved_sources_v1', jsonList);
}

enum MealFetchError { none, httpError, parseError, emptyData }

class MealFetchResult {
  final List<MealDay> meals;
  final MealFetchError error;

  MealFetchResult({required this.meals, required this.error});
}

Future<MealFetchResult> fetchWeeklyMeals() async {
  try {
    final r = await http.get(
      Uri.parse("https://form.bartin.edu.tr/rapor/form/yemek-menu.html"),
    );
    if (r.statusCode != 200) {
      return MealFetchResult(meals: [], error: MealFetchError.httpError);
    }

    final code = r.body;
    final dayBlocks = RegExp(
      r"td='<p></p><p>';.*?td\+='</p>';",
      dotAll: true,
    ).allMatches(code);

    List<MealDay> result = [];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: 1));
    final friday = monday.add(Duration(days: 5));

    for (var b in dayBlocks) {
      final block = b.group(0)!;
      final dateMatch = RegExp(r"t='(\d{2}/\d{2}/\d{4})';").firstMatch(block);
      if (dateMatch == null) continue;

      final dt = DateFormat('dd/MM/yyyy').parse(dateMatch.group(1)!);
      if (dt.isBefore(monday) || dt.isAfter(friday)) continue;

      final meals = RegExp(
        r"yemek\d+='([^']+)'",
      ).allMatches(block).map((m) => m.group(1)!).take(6).toList();

      result.add(
        MealDay(
          dateString: DateFormat('EEEE').format(dt),
          dayInt: dt.day,
          meals: meals,
        ),
      );
    }

    if (result.isEmpty) {
      return MealFetchResult(meals: [], error: MealFetchError.emptyData);
    }

    return MealFetchResult(meals: result, error: MealFetchError.none);
  } catch (e) {
    return MealFetchResult(meals: [], error: MealFetchError.parseError);
  }
}

Future<String> fetchNoticePage(String url) async {
  final uri = Uri.parse(url);

  final response = await http.get(uri);
  if (response.statusCode == 200) {
    final bannedTags = ['script', 'style', 'iframe', 'svg', 'video', 'hr'];
    final document = parser.parse(response.body);
    if (uri.host == 'www.bartin.edu.tr') {
      final firstSection = document.querySelector('section');
      final contentSection = document.querySelectorAll('.section-icerik');

      if (firstSection != null) {
        for (final tag in bannedTags) {
          firstSection.querySelectorAll(tag).forEach((n) => n.remove());
        }
      }

      for (final e in contentSection) {
        for (final tag in bannedTags) {
          e.querySelectorAll(tag).forEach((n) => n.remove());
        }
      }

      final htmlContent = [
        if (firstSection != null) firstSection.outerHtml,
        ...contentSection.map((e) => e.outerHtml),
      ].join('<br><br><br><br>');

      return htmlContent;
    } else {
      final mainElements = document.querySelectorAll(".content-area");

      for (var element in mainElements) {
        for (final tag in bannedTags) {
          element.querySelectorAll(tag).forEach((node) => node.remove());
        }
      }

      final htmlContent = mainElements.map((e) => e.outerHtml).join("\n");
      return htmlContent;
    }

    // selector örneği
  } else {
    throw Exception('Failed to load page: ${response.statusCode}');
  }
}
