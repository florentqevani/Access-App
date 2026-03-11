import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/presentation/pages/users_dashboard.dart';
import 'package:flutter/material.dart';

// Backward-compatible alias for the misspelled page name.
class UsersDahboardPage extends UsersDashboardPage {
  const UsersDahboardPage({super.key, required super.session});

  static MaterialPageRoute<dynamic> route({required AuthSession session}) {
    return UsersDashboardPage.route(session: session);
  }
}
