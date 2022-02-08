import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:orientation/orientation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(MyApp());
  if (Platform.isAndroid) {
    // 以下两行 设置android状态栏为透明的沉浸。写在组件渲染之后，是为了在渲染后进行set赋值，覆盖状态栏，写在渲染之前MaterialApp组件会覆盖掉这个值。
    SystemUiOverlayStyle systemUiOverlayStyle =
        SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    OrientationPlugin.forceOrientation(DeviceOrientation.portraitUp);
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  static var currentThemeMode = ThemeMode.system;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '背否',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blueGrey,
        backgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Color.fromARGB(255, 38, 40, 40),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Color.fromARGB(255, 38, 50, 50)),
      ),
      themeMode: currentThemeMode,
      home: HomePage(),
      supportedLocales: [
        const Locale('zh'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _openDatabase();
    _loadAll();
  }

  @override
  void dispose() {
    dataProvider.close();
    nameFocusNode.dispose();
    super.dispose();
  }

  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  final FocusNode nameFocusNode = new FocusNode();

  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: _appbar,
      drawer: _drawer,
      body: _body,
      floatingActionButton: _floatingButtons,
    );
  }

  /*void changeTheme() {
    setState(() {
      MyApp.currentThemeMode = MyApp.currentThemeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }*/

  var reversedRoasted = "";

  final puncs = Set.from([
    ',',
    '.',
    '?',
    ':',
    ';',
    '!',
    '-',
    '"',
    "'",
    '，',
    '。',
    '？',
    '、',
    '！',
    '：',
    '；',
    '“',
    '”',
    '‘',
    '’',
    '(',
    ')',
    '—',
    '《',
    '》',
    '*',
    '\n'
  ]);

  final spaces = Set.from(['　', ' ']);

  static final nameText = TextEditingController(text: "未命名");
  static final crawText = TextEditingController(text: "");
  static final csMin = TextEditingController(text: "1");
  static final csMax = TextEditingController(text: "2");
  static final ccMin = TextEditingController(text: "1");
  static final ccMax = TextEditingController(text: "2");
  static final cr = TextEditingController(text: "＿");
  static final crMin = TextEditingController(text: "1");
  static final crMax = TextEditingController(text: "1");
  static final croastedText = TextEditingController();
  static final dataProvider = DataProvider();
  static var currentData = Data();
  static var currentEntryIndex = 0;
  static var entries = List<Entry>();

  static SharedPreferences prefs;

  var autoSave = true;
  var plusButtonText = "生成 / 保存";

  static final originalRoastedText = TextField(
    decoration: InputDecoration(
      hintText: "生成结果",
    ),
    controller: croastedText,
    readOnly: true,
    minLines: 1,
    maxLines: 1024,
    style: TextStyle(
      fontSize: 18,
      letterSpacing: 2,
      fontFamily: "SourceHanSerifSC",
    ),
  );

  var roastedText = originalRoastedText;

  static final hiddenText = TextField(
    decoration: InputDecoration(
      hintText: "生成结果",
    ),
    controller: croastedText,
    readOnly: true,
    minLines: 1,
    maxLines: 1024,
    style: TextStyle(
      fontSize: 18,
      letterSpacing: 2,
      fontFamily: "SourceHanSerifSC",
    ),
    textDirection: TextDirection.rtl,
  );

  var aha = false;

  String _getErrorInformation(String action, Exception e) {
    return "无法" + action + "，具体错误信息：\n" + e.toString();
  }

  Future<void> _saveAutoSaveSetting(bool newValue) async {
    _updateAutoSave(newValue);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("autoSave", newValue);
  }

  _updateAutoSave(value) {
    setState(() {
      autoSave = value == null ? true : value;
      plusButtonText = autoSave ? "生成 / 保存" : "生成";
    });
  }

  Future<void> _saveUserData([bool fromOld = false]) async {
    /*await prefs.setString("crawText", crawText.text);
    await prefs.setString("csMin", csMin.text);
    await prefs.setString("csMax", csMax.text);
    await prefs.setString("ccMin", ccMin.text);
    await prefs.setString("ccMax", ccMax.text);
    await prefs.setString("cr", cr.text);
    await prefs.setString("crMin", crMin.text);
    await prefs.setString("crMax", crMax.text);*/

    if (currentData.name != nameText.text) {
      setState(() {
        entries[currentEntryIndex].name = nameText.text;
      });
    }

    currentData.name = nameText.text;
    currentData.crawText = crawText.text;
    currentData.csMin = csMin.text;
    currentData.csMax = csMax.text;
    currentData.ccMin = ccMin.text;
    currentData.ccMax = ccMax.text;
    currentData.cr = cr.text;
    currentData.crMin = crMin.text;
    currentData.crMax = crMax.text;

    if (currentData != null) {
      try {
        await dataProvider.update(currentData);
      } catch (e) {
        croastedText.text = _getErrorInformation("保存", e);
        return;
      }
    }

    if (fromOld) {
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('已从旧版本升级数据'),
        duration: Duration(seconds: 2),
      ));
    } else {
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('已保存篇目'),
        duration: Duration(seconds: 1),
      ));
    }
  }

  Future<void> _openDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'data.db');
    await dataProvider.open(path).then((_) {
      dataProvider.readyCompleter.complete();
    });
  }

  Future<void> _loadData() async {
    /*currentData = await dataProvider.getData(currentId);

    if (currentData != null) {
      crawText.text = currentData.crawText;
      csMin.text = currentData.csMin;
      csMax.text = currentData.csMax;
      ccMin.text = currentData.ccMin;
      ccMax.text = currentData.ccMax;
      cr.text = currentData.cr;
      crMin.text = currentData.crMin;
      crMax.text = currentData.crMax;
    } else {
      currentData = await dataProvider.insert(Data());
      currentId = currentData.id;
    }*/

    if (entries.isEmpty) {
      await _addPage('草稿');
      return;
    }

    try {
      currentData = await dataProvider.getData(entries[currentEntryIndex].id);
    } catch (e) {
      croastedText.text = _getErrorInformation("加载", e);
      return;
    }

    if (currentData != null) {
      nameText.text = currentData.name;
      crawText.text = currentData.crawText;
      csMin.text = currentData.csMin;
      csMax.text = currentData.csMax;
      ccMin.text = currentData.ccMin;
      ccMax.text = currentData.ccMax;
      cr.text = currentData.cr;
      crMin.text = currentData.crMin;
      crMax.text = currentData.crMax;
    }
  }

  Future<void> _loadAll() async {
    prefs = await SharedPreferences.getInstance();

    if (prefs != null) {
      /*crawText.text = prefs.getString("crawText");
      csMin.text = prefs.getString("csMin");
      csMax.text = prefs.getString("csMax");
      ccMin.text = prefs.getString("ccMin");
      ccMax.text = prefs.getString("ccMax");
      cr.text = prefs.getString("cr");
      crMin.text = prefs.getString("crMin");
      crMax.text = prefs.getString("crMax");*/

      var entryIndex = prefs.getInt("entryIndex");
      setState(() {
        currentEntryIndex = entryIndex == null ? 0 : entryIndex;
      });
      _updateAutoSave(prefs.getBool("autoSave"));

      //debug
      /*prefs.setString("crawText", "1212");
      prefs.setString("csMin", "1212");
      prefs.setString("csMax", "1212");
      prefs.setString("ccMin", "1212");
      prefs.setString("ccMax", "1212");
      prefs.setString("cr", "1212");
      //prefs.setString("crMin", "1212");
      //prefs.setString("crMax", "1212");*/

      if (prefs.containsKey("crawText")) {
        await _addPage("草稿");

        crawText.text = prefs.getString("crawText");
        csMin.text = prefs.getString("csMin");
        csMax.text = prefs.getString("csMax");
        ccMin.text = prefs.getString("ccMin");
        ccMax.text = prefs.getString("ccMax");
        cr.text = prefs.getString("cr");
        crMin.text = prefs.getString("crMin");
        crMax.text = prefs.getString("crMax");

        await _saveUserData(true);

        await prefs.remove("crawText");
        await prefs.remove("csMin");
        await prefs.remove("csMax");
        await prefs.remove("ccMin");
        await prefs.remove("ccMax");
        await prefs.remove("cr");
        await prefs.remove("crMin");
        await prefs.remove("crMax");
      }
    }

    Future<void> _getEntries() async {
      entries = await dataProvider.getAllEntries();
      setState(() {});
    }

    _getEntries().whenComplete(_loadData);
  }

  /*Future<void> _clearData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    crawText.text = csMin.text = csMax.text =
        ccMin.text = ccMax.text = cr.text = crMin.text = crMax.text = "";
    autoSave = true;
  }*/

  Future<void> _loadPage() async {
    await _loadData();
    croastedText.text = "";
    await prefs.setInt("entryIndex", currentEntryIndex);
  }

  Future<void> _addPage([String name]) async {
    Data data;

    try {
      data = await dataProvider.insert(Data(name));
    } catch (e) {
      croastedText.text = _getErrorInformation("创建篇目", e);
      return;
    }

    setState(() {
      entries.add(Entry(data.id, data.name));
    });

    setState(() {
      currentEntryIndex = entries.length - 1;
    });

    await _loadPage();

    FocusScope.of(scaffoldKey.currentContext).requestFocus(nameFocusNode);
  }

  Future<void> _deletePage() async {
    HapticFeedback.lightImpact();

    try {
      await dataProvider.delete(entries[currentEntryIndex].id);
    } catch (e) {
      croastedText.text = _getErrorInformation("删除", e);
      return;
    }

    setState(() {
      entries.removeAt(currentEntryIndex);
    });
    currentEntryIndex--;

    scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text('已删除篇目'),
      duration: Duration(seconds: 1),
    ));

    await _loadPage();
  }

  Future<void> _generate() async {
    HapticFeedback.lightImpact();
    if (aha) {
      setState(() {
        roastedText = originalRoastedText;
      });
      aha = false;
    }
    if (autoSave) {
      await _saveUserData();
    }
    final roasted = StringBuffer();
    final rroasted = StringBuffer();
    try {
      final raw = crawText.text;
      final smin = int.parse(csMin.text);
      final smax = int.parse(csMax.text) - smin + 1;
      final cmin = int.parse(ccMin.text);
      final cmax = int.parse(ccMax.text) - cmin + 1;
      final r = cr.text;
      final rmin = int.parse(crMin.text);
      final rmax = int.parse(crMax.text) - rmin + 1;
      if (smin < 0 ||
          cmin < 0 ||
          rmin < 0 ||
          (smin == 0 && smax != 1) ||
          (cmin == 0 && cmax != 1)) throw (Exception("Invalid Range"));

      final ran = Random();
      var skp = 0;
      var kp = cmin + ran.nextInt(cmax);
      for (int i = 0; i < raw.length; i++) {
        final c = raw[i];
        if (spaces.contains(c)) {
          continue;
        }
        if (puncs.contains(c)) {
          roasted.write(c);
          rroasted.write(c);
        } else if (skp == 0) {
          kp--;
          roasted.write(c);
          final rr = rmin + ran.nextInt(rmax);
          rroasted.write(r * rr);
          if (kp == 0) skp = smin + ran.nextInt(smax);
        } else if (kp == 0) {
          skp--;
          rroasted.write(c);
          final rr = rmin + ran.nextInt(rmax);
          roasted.write(r * rr);
          if (skp == 0) kp = cmin + ran.nextInt(cmax);
        }
      }
    } catch (e) {
      croastedText.text = _getErrorInformation("生成", e);
      reversedRoasted = "💩";
      return;
    }
    croastedText.text = roasted.toString();
    reversedRoasted = rroasted.toString();
  }

  void _reverse() {
    HapticFeedback.lightImpact();
    if (reversedRoasted == "💩") {
      setState(() {
        aha ? roastedText = originalRoastedText : roastedText = hiddenText;
      });
      aha = !aha;
      return;
    }
    final str = croastedText.text;
    croastedText.text = reversedRoasted;
    reversedRoasted = str;
  }

  get _floatingButtons => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Visibility(
            visible: !autoSave,
            child: FloatingActionButton(
              onPressed: _saveUserData,
              mini: true,
              child: Icon(Icons.save),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(5),
          ),
          FloatingActionButton.extended(
            onPressed: _generate,
            icon: Icon(Icons.add),
            label: Text(plusButtonText),
          ),
          Padding(
            padding: EdgeInsets.all(5),
          ),
          FloatingActionButton.extended(
            onPressed: _reverse,
            icon: Icon(Icons.loop),
            label: Text("翻转"),
          ),
        ],
      );

  get _body => ListView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
        shrinkWrap: false,
        children: [
          TextField(
            decoration: InputDecoration(labelText: "篇目名称"),
            maxLines: 1,
            controller: nameText,
            focusNode: nameFocusNode,
          ),
          TextField(
            decoration: InputDecoration(
              labelText: "原文",
            ),
            minLines: 1,
            maxLines: 1024,
            controller: crawText,
          ),
          Container(
            height: 60,
            width: 60,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 60,
                        width: 75,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "最小跳过",
                          ),
                          controller: csMin,
                        ),
                      ),
                      Container(
                        height: 60,
                        width: 75,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "最大跳过",
                          ),
                          controller: csMax,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        height: 60,
                        width: 75,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "最小连续",
                          ),
                          controller: ccMin,
                        ),
                      ),
                      Container(
                        height: 60,
                        width: 75,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "最大连续",
                          ),
                          controller: ccMax,
                        ),
                      ),
                    ],
                  ),
                ]),
          ),
          Container(
            height: 60,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 60,
                    width: 150,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: "替换符",
                      ),
                      controller: cr,
                    ),
                  ),
                  Row(children: [
                    Container(
                      height: 60,
                      width: 75,
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: "最小替换",
                        ),
                        controller: crMin,
                      ),
                    ),
                    Container(
                      height: 60,
                      width: 75,
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: "最大替换",
                        ),
                        controller: crMax,
                      ),
                    ),
                  ])
                ]),
          ),
          Padding(padding: EdgeInsets.fromLTRB(0, 10, 0, 10)),
          Card(
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: roastedText,
            ),
          ),
          Container(
            height: 80,
          )
        ],
      );

  get _appbar => AppBar(
        title: Text('背否 (Early Access)'),
        actions: [
          IconButton(
            padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
            icon: Icon(Icons.delete),
            onPressed: currentEntryIndex == 0 ? null : () => _deletePage(),
          )
        ],
      );

  get _drawer => Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                separatorBuilder: (context, index) => Divider(
                  color: Color.fromARGB(125, 150, 150, 150),
                  indent: 50,
                  endIndent: 50,
                  height: 1,
                  thickness: 0.5,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: index == 0
                        ? Icon(Icons.mode_edit)
                        : Icon(Icons.bookmark),
                    title: Text(entries[index].name),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        currentEntryIndex = index;
                      });
                      _loadPage();
                    },
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
            ),
            ListTile(
              leading: Icon(Icons.add_circle),
              title: Text("添加篇目"),
              onTap: () async {
                await _addPage();
                Navigator.of(scaffoldKey.currentContext).pop();
              },
            ),
            SwitchListTile(
              value: autoSave,
              title: Text("生成后自动保存"),
              onChanged: _saveAutoSaveSetting,
            ),
            Container(
              height: 10,
            ),
          ],
        ),
      );
}

final String tableData = 'data';
final String columnId = '_id';
final String columnName = 'name';
final String columnCrawText = 'crawText';
final String columnCsMin = 'csMin';
final String columnCsMax = 'csMax';
final String columnCcMin = 'ccMin';
final String columnCcMax = 'ccMax';
final String columnCr = 'cr';
final String columnCrMin = 'crMin';
final String columnCrMax = 'crMax';

class Data {
  int id;
  String name = "未命名";
  String crawText = "";
  String csMin = "1";
  String csMax = "2";
  String ccMin = "1";
  String ccMax = "2";
  String cr = "＿";
  String crMin = "1";
  String crMax = "1";

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      columnName: name,
      columnCrawText: crawText,
      columnCsMin: csMin,
      columnCsMax: csMax,
      columnCcMin: ccMin,
      columnCcMax: ccMax,
      columnCr: cr,
      columnCrMin: crMin,
      columnCrMax: crMax,
    };

    if (id != null) {
      map[columnId] = id;
    }

    return map;
  }

  Data([String _name]) {
    if (_name != null) {
      name = _name;
    }
  }

  Data.fromMap(Map<String, dynamic> map) {
    id = map[columnId];
    name = map[columnName];
    crawText = map[columnCrawText];
    csMin = map[columnCsMin];
    csMax = map[columnCsMax];
    ccMin = map[columnCcMin];
    ccMax = map[columnCcMax];
    cr = map[columnCr];
    crMin = map[columnCrMin];
    crMax = map[columnCrMax];
  }
}

class Entry {
  int id;
  String name;

  Entry(int _id, String _name) {
    id = _id;
    name = _name;
  }
}

class DataProvider {
  Database db;
  var readyCompleter = Completer();
  Future get ready => readyCompleter.future;

  Future open(String path) async {
    db = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
create table $tableData (
  $columnId integer primary key autoincrement,
  $columnName text not null,
  $columnCrawText text,
  $columnCsMin text,
  $columnCsMax text,
  $columnCcMin text,
  $columnCcMax text,
  $columnCr text,
  $columnCrMin text,
  $columnCrMax text)
''');
    });
  }

  Future<Data> insert(Data data) async {
    await ready;

    data.id = await db.insert(tableData, data.toMap()); //todo debug
    return data;
  }

  Future<List<Entry>> getAllEntries() async {
    await ready;

    List<Map> maps = await db.query(tableData, columns: [columnId, columnName]);

    var list = List<Entry>();
    maps.forEach((e) {
      list.add(Entry(e[columnId], e[columnName]));
    });

    return list;
  }

  Future<Data> getData(int id) async {
    await ready;

    List<Map> maps = await db.query(tableData,
        columns: [
          columnId,
          columnName,
          columnCrawText,
          columnCsMin,
          columnCsMax,
          columnCcMin,
          columnCcMax,
          columnCr,
          columnCrMin,
          columnCrMax
        ],
        where: '$columnId = ?',
        whereArgs: [id]);
    if (maps.length > 0) {
      return Data.fromMap(maps.first);
    }
    return null;
  }

  Future<int> delete(int id) async {
    await ready;

    return await db.delete(tableData, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> update(Data data) async {
    await ready;

    var map = data.toMap();
    if (map[columnName] == "") map[columnName] = "未命名";
    return await db
        .update(tableData, map, where: '$columnId = ?', whereArgs: [data.id]);
  }

  Future close() async => db.close();
}
