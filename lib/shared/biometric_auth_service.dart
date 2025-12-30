import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (canAuthenticate) {
        return await _auth.authenticate(
          localizedReason: 'Please authenticate to access the app',
          biometricOnly: true,
        );
      }
      return false;
    } on PlatformException {
      return false;
    }
  }
}
