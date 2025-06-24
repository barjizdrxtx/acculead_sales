import 'package:acculead_sales/utls/url.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  AuthenticationProvider() {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    _accessToken = _prefs.getString(AccessToken.accessToken) ?? '';

    notifyListeners();
  }

  dynamic _accessToken = '';

  String get accessToken => _accessToken;

  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    // Save access token to SharedPreferences
    await _prefs.setString(AccessToken.accessToken, token);
    notifyListeners();
  }

  String getAccessToken() {
    return _accessToken;
  }

  Future<void> logout() async {
    // Clear both access token and rest token
    _accessToken = '';

    // Remove tokens from SharedPreferences
    await _prefs.remove(AccessToken.accessToken);

    notifyListeners();
  }
}
