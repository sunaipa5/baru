import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'scraper.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:baru/window_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowStorage.initialize(title: 'Baru');

  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(theme: ThemeData.dark(), home: HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Source> sources = [
    Source(
      name: 'MAIN',
      url: 'https://www.bartin.edu.tr/arsiv/duyuru-arsiv.html',
    ),
    Source(name: 'OIDB', url: 'https://oidb.bartin.edu.tr/duyuru-arsiv.html'),
    Source(name: 'IIBF', url: 'https://iibf.bartin.edu.tr/duyuru-arsiv.html'),
    Source(name: 'YBS', url: 'https://ybs.bartin.edu.tr/duyuru-arsiv.html'),
  ];
  Map<String, List<Announcement>> announcements = {};
  Map<String, bool> expanded = {};

  @override
  void initState() {
    super.initState();
    _loadMeals();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('saved_sources_v1');
    if (jsonList != null) {
      setState(() {
        sources = jsonList.map((e) => Source.fromJson(json.decode(e))).toList();
      });
    }
  }

  Future<void> _saveSources() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sources.map((s) => json.encode(s.toJson())).toList();
    await prefs.setStringList('saved_sources_v1', jsonList);
  }

  Future<void> _addSource() async {
    showDialog(
      context: context,
      builder: (_) {
        String name = '', url = '';
        return AlertDialog(
          titlePadding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Add Source',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(labelText: 'Name'),
                onChanged: (v) => name = v,
              ),
              TextField(
                decoration: InputDecoration(labelText: 'URL'),
                onChanged: (v) => url = v,
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (name.isEmpty || url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Name and URL cannot be empty')),
                      );
                      return;
                    }

                    if (sources.any((s) => s.name == name || s.url == url)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'A source with the same name or URL already exists',
                          ),
                        ),
                      );
                      return;
                    }

                    if (Uri.tryParse(url) == null ||
                        !(Uri.tryParse(url)!.isAbsolute)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid URL')),
                      );
                      return;
                    }

                    setState(() {
                      sources.add(Source(name: name, url: url));
                      expanded[url] = false;
                    });
                    _saveSources();
                    Navigator.pop(context);
                  },
                  child: Text('Add'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> showHtmlAlert(String url) async {
    try {
      final htmlContent = await fetchNoticePage(url);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          titlePadding: const EdgeInsets.only(top: 7, right: 7),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          content: SingleChildScrollView(
            child: Html(
              data: htmlContent,
              extensions: const [TableHtmlExtension()],
              onLinkTap:
                  (
                    String? url,
                    Map<String, String> attributes,
                    dom.Element? element,
                  ) {
                    if (url != null) {
                      final uri = Uri.parse(url);
                      canLaunchUrl(uri).then((canLaunch) {
                        if (canLaunch) launchUrl(uri);
                      });
                    }
                  },
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: "Open with browser",
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: Text('Failed to get page: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> removeSourceConfirm(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this source?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        sources.removeAt(index);
      });
      _saveSources();
      return true;
    }
    return false;
  }

  Future<void> _fetchAnnouncements(String url) async {
    final list = await fetchAnnouncements(url);
    setState(() {
      announcements[url] = list;
    });
  }

  final todayInt = DateTime.now().day;
  List<MealDay> days = [];
  MealFetchResult mealResult = MealFetchResult(
    meals: [],
    error: MealFetchError.none,
  );

  Future<void> _loadMeals() async {
    final res = await fetchWeeklyMeals();
    setState(() {
      mealResult = res;
      days = res.meals;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('BARU'),
      actions: [IconButton(onPressed: _addSource, icon: Icon(Icons.add))],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        setState(() {
          announcements = <String, List<Announcement>>{};
        });
        if (mealResult.error == MealFetchError.emptyData) return;

        setState(() {
          _loadMeals();
        });
      },
      child: Padding(
        padding: EdgeInsets.all(5),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: days.isEmpty
                  ? Builder(
                      builder: (context) {
                        switch (mealResult.error) {
                          case MealFetchError.none:
                            return Center(child: Text("No meals this week"));
                          case MealFetchError.emptyData:
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Next month’s meal list isn't published yet",
                                  ),
                                ],
                              ),
                            );
                          case MealFetchError.httpError:
                          case MealFetchError.parseError:
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Failed to get meal list"),
                                  SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _loadMeals,
                                    child: Text("Reload"),
                                  ),
                                ],
                              ),
                            );
                        }
                      },
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      children: days.map((d) {
                        final isToday = d.dayInt == todayInt;
                        return Card(
                          margin: EdgeInsets.only(
                            left: 5,
                            right: 10,
                            bottom: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isToday
                                ? BorderSide(
                                    color: Colors.green.shade900,
                                    width: 2,
                                  )
                                : BorderSide(
                                    color: Colors.transparent,
                                    width: 0,
                                  ),
                          ),
                          child: Container(
                            width: 180,
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${d.dayInt} ${d.dateString}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...d.meals.map((m) => Text("• $m")),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final isExpanded = expanded[source.url] ?? false;
                  return Dismissible(
                    key: Key(source.url),
                    direction: DismissDirection.endToStart,
                    background: Container(color: Colors.red),
                    confirmDismiss: (_) => removeSourceConfirm(index),
                    child: Card(
                      margin: EdgeInsets.all(4),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(source.name),
                          initiallyExpanded: isExpanded,
                          onExpansionChanged: (val) {
                            setState(() {
                              expanded[source.url] = val;
                            });
                            if (val && (announcements[source.url] == null)) {
                              _fetchAnnouncements(source.url);
                            }
                          },
                          children: [
                            if (announcements[source.url] == null)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              ...announcements[source.url]!.map(
                                (a) => ListTile(
                                  title: Text(a.text),
                                  trailing: Text(a.date),
                                  onTap: () => showHtmlAlert(a.link),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
