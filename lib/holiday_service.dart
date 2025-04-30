
import 'dart:convert';
import 'package:http/http.dart' as http;

class HolidayInfo {
  final bool isHoliday;
  final String source;
  final String? description;

  HolidayInfo({required this.isHoliday, required this.source, this.description});
}

class HolidayService {
  static Future<HolidayInfo> checkHoliday(DateTime date, String apiUrl) async {
    try {
      final url = Uri.parse("\$apiUrl?date=\${date.toIso8601String().split('T')[0]}");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        bool isHoliday = false;

        // 通用解析逻辑（支持布尔、int、字符串等）
        if (json is Map<String, dynamic>) {
          if (json.containsKey('isHoliday')) {
            final value = json['isHoliday'];
            if (value is bool) {
              isHoliday = value;
            } else if (value is int) {
              isHoliday = value != 0;
            } else if (value is String) {
              isHoliday = (value.toLowerCase() == 'true' || value == '1');
            }
          }
        }

        return HolidayInfo(
          isHoliday: isHoliday,
          source: apiUrl,
          description: json['description']?.toString(),
        );
      } else {
        return HolidayInfo(isHoliday: false, source: apiUrl);
      }
    } catch (e) {
      return HolidayInfo(isHoliday: false, source: apiUrl);
    }
  }
}
