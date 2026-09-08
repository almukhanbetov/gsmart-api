import '../../../core/utils/json.dart';

/// Соответствует Go `type Device` (backend/models.go) и `Device` в
/// mobile/src/lib/types.ts. `account` — строка (в БД varchar), по нему же
/// делаются запросы GET /api/money|coin|payments/:account.
class Device {
  const Device({
    required this.id,
    required this.account,
    required this.userCode,
    required this.deviceName,
    required this.type,
    required this.bin,
    required this.gruppa,
    required this.deviceStatus,
    required this.serverStatus,
    required this.abonTime,
    required this.summa,
    required this.signalWifi,
    required this.status,
    required this.dataStatus,
    required this.dataInkas,
  });

  final int id;
  final String account;
  final int userCode; // user_code
  final String deviceName; // device_name
  final int type;
  final String bin;
  final String gruppa;
  final bool deviceStatus; // device_status
  final bool serverStatus; // server_status
  final String? abonTime; // abon_time (nullable)
  final double summa;
  final String signalWifi; // signal_wifi
  final bool status;
  final String? dataStatus; // data_status (nullable)
  final String? dataInkas; // data_inkas (nullable)

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: asInt(json['id']),
      account: asString(json['account']),
      userCode: asInt(json['user_code']),
      deviceName: asString(json['device_name']),
      type: asInt(json['type']),
      bin: asString(json['bin']),
      gruppa: asString(json['gruppa']),
      deviceStatus: asBool(json['device_status']),
      serverStatus: asBool(json['server_status']),
      abonTime: asStringOrNull(json['abon_time']),
      summa: asDouble(json['summa']),
      signalWifi: asString(json['signal_wifi']),
      status: asBool(json['status']),
      dataStatus: asStringOrNull(json['data_status']),
      dataInkas: asStringOrNull(json['data_inkas']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account': account,
        'user_code': userCode,
        'device_name': deviceName,
        'type': type,
        'bin': bin,
        'gruppa': gruppa,
        'device_status': deviceStatus,
        'server_status': serverStatus,
        'abon_time': abonTime,
        'summa': summa,
        'signal_wifi': signalWifi,
        'status': status,
        'data_status': dataStatus,
        'data_inkas': dataInkas,
      };
}
