package com.example.productivity

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity statt FlutterActivity: local_auth zeigt seinen
// Dialog als Fragment an und wirft sonst zur Laufzeit.
class MainActivity : FlutterFragmentActivity()
