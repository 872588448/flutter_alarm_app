
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await AndroidAlarmManager.initialize();
  runApp(MyApp());
  // 启动自动调度服务，每天凌晨 3 点执行一次
  AndroidAlarmManager.periodic(
    const Duration(hours: 24),
    0,
    scheduleAlarm,
    wakeup: true,
    rescheduleOnReboot: true,
    exact: true,
    startAt: DateTime.now().add(Duration(seconds: 10)),
  );
}


Future<void> scheduleAlarm() async {
  if (await shouldSkipToday()) {
    print("今天为节假日或周末，跳过闹钟设置");
    return;
  }

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await 
  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse);


  final now = DateTime.now();
  final start = DateTime(2025, 1, 1);
  final weekDiff = now.difference(start).inDays ~/ 7;
  final isBigWeek = weekDiff % 2 == 0;

  final time = isBigWeek
      ? TimeOfDay(hour: 7, minute: 30)
      : TimeOfDay(hour: 8, minute: 30);

  final scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  final tzScheduled = tz.TZDateTime.from(scheduled.isBefore(now) ? scheduled.add(Duration(days: 1)) : scheduled, tz.local);

  const androidDetails = AndroidNotificationDetails(
    'alarm_channel_id',
    'Alarm Channel',
    importance: Importance.max,
    priority: Priority.high,
  );
  const notificationDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    '自动闹钟提醒',
    isBigWeek ? '今天是大周' : '今天是小周',
    tzScheduled,
    notificationDetails,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}



Future<bool> shouldSkipToday() async {
  final now = DateTime.now();
  final weekday = now.weekday;
  if (weekday >= 6) return true; // 周六周日跳过

  final prefs = await SharedPreferences.getInstance();
  final apiUrl = prefs.getString('holidayApiUrl') ?? 'https://timor.tech/api/holiday/info';

  try {
    final resp = await http.get(Uri.parse('\$apiUrl/${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return data['holiday'] != null;
    }
  } catch (e) {
    print('节假日API请求失败: \$e');
  }
  return false;
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TimeOfDay _bigWeekTime = TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _smallWeekTime = TimeOfDay(hour: 8, minute: 30);
  bool _isBigWeek = true;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _initNotifications();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('isBigWeek');
    if (saved != null) {
      setState(() => _isBigWeek = saved);
    }
  }

  Future<void> _initNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _
  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse);

  }

  Future<void> _scheduleManualAlarm(TimeOfDay time) async {
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    ).add(Duration(days: scheduledTimeIsToday(time, now) ? 0 : 1));

    final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'alarm_channel_id',
      'Alarm Channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      '调试闹钟提醒',
      '这是手动调试设置的闹钟',
      tzScheduled,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  bool scheduledTimeIsToday(TimeOfDay time, DateTime now) {
    final target = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return target.isAfter(now);
  }

  void _toggleWeek(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isBigWeek = value);
    prefs.setBool('isBigWeek', value);
  }

  Future<void> _pickTime(bool isBig) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBig ? _bigWeekTime : _smallWeekTime,
    );
    if (picked != null) {
      setState(() {
        if (isBig) {
          _bigWeekTime = picked;
        } else {
          _smallWeekTime = picked;
        }
      });
    }
  }

  void _startManualAlarm() {
    final time = _isBigWeek ? _bigWeekTime : _smallWeekTime;
    _scheduleManualAlarm(time);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("手动闹钟设置在 ${time.format(context)}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('大小周闹钟（含自动+手动调试）')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GFToggle(
                onChanged: _toggleWeek,
                value: _isBigWeek,
                type: GFToggleType.ios,
              ),
              SizedBox(height: 16),
              GFListTile(
                titleText: '大周时间: ${_bigWeekTime.format(context)}',
                icon: Icon(Icons.access_time),
                onTap: () => _pickTime(true),
              ),
              GFListTile(
                titleText: '小周时间: ${_smallWeekTime.format(context)}',
                icon: Icon(Icons.access_time),
                onTap: () => _pickTime(false),
              ),
              SizedBox(height: 24),
              
              
              
              
              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RepeatSettingsPage()),
                  );
                },
                text: "设置重复闹钟",
                fullWidthButton: true,
                color: Colors.teal,
              ),

              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SnoozeSettingsPage()),
                  );
                },
                text: "设置懒睡时间",
                fullWidthButton: true,
                color: Colors.purple,
              ),

              
              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RepeatSettingsPage()),
                  );
                },
                text: "设置重复闹钟",
                fullWidthButton: true,
                color: Colors.teal,
              ),

              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SoundSettingsPage()),
                  );
                },
                text: "设置铃声",
                fullWidthButton: true,
                color: Colors.blueGrey,
              ),

              
              
              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RepeatSettingsPage()),
                  );
                },
                text: "设置重复闹钟",
                fullWidthButton: true,
                color: Colors.teal,
              ),

              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SnoozeSettingsPage()),
                  );
                },
                text: "设置懒睡时间",
                fullWidthButton: true,
                color: Colors.purple,
              ),

              
              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RepeatSettingsPage()),
                  );
                },
                text: "设置重复闹钟",
                fullWidthButton: true,
                color: Colors.teal,
              ),

              
              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VolumeSettingsPage()),
                  );
                },
                text: "设置铃声音量",
                fullWidthButton: true,
                color: Colors.deepOrange,
              ),

              
              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RingtoneSettingsPage()),
                  );
                },
                text: "自定义铃声",
                fullWidthButton: true,
                color: Colors.indigo,
              ),

              GFButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HolidayApiSettingsPage()),
                  );
                },
                text: "设置节假日 API",
                fullWidthButton: true,
                color: Colors.orange,
              ),

              GFButton(
                onPressed: _startManualAlarm,
                text: "测试设置（调试闹钟）",
                fullWidthButton: true,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(
                  "自动调度已启用：每天定时判断大小周并设置闹钟。",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}



class HolidayApiSettingsPage extends StatefulWidget {
  @override
  _HolidayApiSettingsPageState createState() => _HolidayApiSettingsPageState();
}

class _HolidayApiSettingsPageState extends State<HolidayApiSettingsPage> {
  final _controller = TextEditingController();
  String _savedUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('holidayApiUrl') ?? 'https://timor.tech/api/holiday/info';
    setState(() {
      _controller.text = url;
      _savedUrl = url;
    });
  }

  Future<void> _saveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('holidayApiUrl', _controller.text.trim());
    setState(() => _savedUrl = _controller.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存 API 地址')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("节假日 API 设置")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: '节假日 API 地址'),
            ),
            SizedBox(height: 16),
            GFButton(
              onPressed: _saveUrl,
              text: "保存设置",
              fullWidthButton: true,
            ),
            SizedBox(height: 24),
            Text("当前使用：$_savedUrl", style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}



class SoundSettingsPage extends StatefulWidget {
  @override
  _SoundSettingsPageState createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends State<SoundSettingsPage> {
  String? _selectedSoundPath;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSoundPath();
  }

  Future<void> _loadSoundPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSoundPath = prefs.getString('alarmSoundPath');
    });
  }

  Future<void> _pickSound() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarmSoundPath', path);
      setState(() {
        _selectedSoundPath = path;
      });
    }
  }

  Future<void> _playPreview() async {
    if (_selectedSoundPath != null) {
      await _player.play(DeviceFileSource(_selectedSoundPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("自定义铃声设置")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("当前选择的铃声："),
            SizedBox(height: 8),
            Text(_selectedSoundPath ?? "未选择", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            GFButton(
              onPressed: _pickSound,
              text: "选择本地铃声",
              fullWidthButton: true,
            ),
            SizedBox(height: 16),
            GFButton(
              onPressed: _playPreview,
              text: "预览铃声",
              fullWidthButton: true,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}



class SnoozeSettingsPage extends StatefulWidget {
  @override
  _SnoozeSettingsPageState createState() => _SnoozeSettingsPageState();
}

class _SnoozeSettingsPageState extends State<SnoozeSettingsPage> {
  int _snoozeMinutes = 5;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSnoozeTime();
  }

  Future<void> _loadSnoozeTime() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('snoozeMinutes') ?? 5;
    setState(() {
      _snoozeMinutes = stored;
      _controller.text = stored.toString();
    });
  }

  Future<void> _saveSnoozeTime() async {
    final minutes = int.tryParse(_controller.text.trim());
    if (minutes != null && minutes > 0 && minutes <= 60) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snoozeMinutes', minutes);
      setState(() => _snoozeMinutes = minutes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('懒睡时间已保存')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请输入 1 到 60 之间的数字')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("懒睡时间设置")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("设置再次响铃延迟时间（分钟）"),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "懒睡分钟数"),
            ),
            SizedBox(height: 16),
            GFButton(
              onPressed: _saveSnoozeTime,
              text: "保存设置",
              fullWidthButton: true,
              color: Colors.purple,
            ),
            SizedBox(height: 24),
            Text("当前懒睡时间：$_snoozeMinutes 分钟", style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}




Future<void> showAlarmNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'alarm_channel_id',
    'Alarm Notifications',
    channelDescription: 'Channel for alarm',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    playSound: true,
    $notification_volume_patch
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('snooze', '懒睡一下')
    ],
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  
  final prefs = await SharedPreferences.getInstance();
  final volume = prefs.getDouble('alarmVolume') ?? 1.0;

  await flutterLocalNotificationsPlugin.show(
    0,
    '⏰ 闹钟响了',
    '点击“懒睡一下”再响铃',
    platformChannelSpecifics,
    payload: 'alarm',
  );
}

Future<void> handleNotificationResponse(NotificationResponse response) async {
  if (response.actionId == 'snooze') {
    final prefs = await SharedPreferences.getInstance();
    final snoozeMinutes = prefs.getInt('snoozeMinutes') ?? 5;
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      '⏰ 再次响铃',
      '这是你的懒睡闹钟',
      tz.TZDateTime.from(snoozeTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'snooze_channel_id',
          'Snooze Notifications',
          channelDescription: 'Channel for snooze alarms',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}




Future<bool> isHoliday(DateTime date) async {
  final prefs = await SharedPreferences.getInstance();
  final apiUrl = prefs.getString('holidayApiUrl');
  if (apiUrl == null || apiUrl.isEmpty) return false;

  final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  final uri = Uri.parse("$apiUrl?date=$formattedDate");

  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result is Map && result.containsKey("isHoliday")) {
        return result["isHoliday"] == true;
      }
    }
  } catch (e) {
    print("节假日 API 失败: $e");
  }
  return false;
}



Future<bool> isTodayHoliday() async {
  final prefs = await SharedPreferences.getInstance();
  final apiUrl = prefs.getString('holidayApiUrl') ?? '';
  if (apiUrl.isEmpty) return false;

  try {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 统一结构：要求 API 返回 {"2025-05-01": true, "2025-05-02": false, ...}
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return data[today] == true;
    }
  } catch (e) {
    print("节假日 API 错误: \$e");
  }
  return false;
}



enum RepeatOption {
  none,
  daily,
  weekdays,
  custom,
}

List<String> weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

class RepeatSettingsPage extends StatefulWidget {
  @override
  _RepeatSettingsPageState createState() => _RepeatSettingsPageState();
}

class _RepeatSettingsPageState extends State<RepeatSettingsPage> {
  RepeatOption _repeat = RepeatOption.none;
  List<bool> _selectedDays = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    _loadRepeatSettings();
  }

  Future<void> _loadRepeatSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _repeat = RepeatOption.values[prefs.getInt('repeatOption') ?? 0];
    final days = prefs.getStringList('repeatDays') ?? [];
    _selectedDays = List.generate(7, (i) => days.contains(i.toString()));
    setState(() {});
  }

  Future<void> _saveRepeatSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('repeatOption', _repeat.index);
    final days = _selectedDays.asMap().entries.where((e) => e.value).map((e) => e.key.toString()).toList();
    await prefs.setStringList('repeatDays', days);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重复设置已保存')));
  }

  Widget _buildWeekdaySelector() {
    return Wrap(
      spacing: 10,
      children: List.generate(7, (i) {
        return FilterChip(
          label: Text('周${weekdayNames[i]}'),
          selected: _selectedDays[i],
          onSelected: (selected) {
            setState(() {
              _selectedDays[i] = selected;
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("重复设置")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<RepeatOption>(
              value: _repeat,
              items: [
                DropdownMenuItem(child: Text("不重复"), value: RepeatOption.none),
                DropdownMenuItem(child: Text("每天"), value: RepeatOption.daily),
                DropdownMenuItem(child: Text("工作日"), value: RepeatOption.weekdays),
                DropdownMenuItem(child: Text("自定义"), value: RepeatOption.custom),
              ],
              onChanged: (value) {
                setState(() {
                  _repeat = value!;
                });
              },
            ),
            if (_repeat == RepeatOption.custom) _buildWeekdaySelector(),
            SizedBox(height: 16),
            GFButton(
              onPressed: _saveRepeatSettings,
              text: "保存设置",
              color: Colors.teal,
              fullWidthButton: true,
            )
          ],
        ),
      ),
    );
  }
}



class VolumeSettingsPage extends StatefulWidget {
  @override
  _VolumeSettingsPageState createState() => _VolumeSettingsPageState();
}

class _VolumeSettingsPageState extends State<VolumeSettingsPage> {
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _volume = prefs.getDouble('alarmVolume') ?? 1.0;
    });
  }

  Future<void> _saveVolume() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('alarmVolume', _volume);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("音量设置已保存")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("铃声音量")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("当前音量: ${(_volume * 100).round()}%"),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: "${(_volume * 100).round()}%",
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });
              },
            ),
            GFButton(
              onPressed: _saveVolume,
              text: "保存设置",
              fullWidthButton: true,
              color: Colors.deepOrange,
            )
          ],
        ),
      ),
    );
  }
}



import 'package:file_picker/file_picker.dart';

class RingtoneSettingsPage extends StatefulWidget {
  @override
  _RingtoneSettingsPageState createState() => _RingtoneSettingsPageState();
}

class _RingtoneSettingsPageState extends State<RingtoneSettingsPage> {
  String? _ringtonePath;

  @override
  void initState() {
    super.initState();
    _loadCustomPath();
  }

  Future<void> _loadCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ringtonePath = prefs.getString('customAlarmPath');
    });
  }

  Future<void> _pickRingtone() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customAlarmPath', result.files.single.path!);
      setState(() {
        _ringtonePath = result.files.single.path!;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("铃声已设置")));
    }
  }

  Future<void> _clearRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customAlarmPath');
    setState(() {
      _ringtonePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("自定义铃声")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_ringtonePath == null ? "未设置自定义铃声" : "当前铃声: $_ringtonePath"),
            SizedBox(height: 10),
            GFButton(
              onPressed: _pickRingtone,
              text: "选择本地音频",
              icon: Icon(Icons.music_note),
              color: Colors.indigo,
              fullWidthButton: true,
            ),
            SizedBox(height: 10),
            if (_ringtonePath != null)
              GFButton(
                onPressed: _clearRingtone,
                text: "清除铃声",
                color: Colors.redAccent,
                fullWidthButton: true,
              ),
          ],
        ),
      ),
    );
  }
}
