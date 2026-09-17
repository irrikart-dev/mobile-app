package com.irrikart.app

import io.flutter.embedding.android.FlutterFragmentActivity

// razorpay_flutter's checkout UI needs a FragmentActivity host — plain
// FlutterActivity crashes it at runtime with a ClassCastException.
class MainActivity: FlutterFragmentActivity()
