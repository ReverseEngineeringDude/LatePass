import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityService {
  Stream<InternetStatus> get onStatusChange =>
      InternetConnection().onStatusChange;

  Future<bool> get hasConnection => InternetConnection().hasInternetAccess;
}
