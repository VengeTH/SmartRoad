package com.example.smartroad;

import android.content.Intent;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // * Ensures plugins can read the latest deep link intent.
        setIntent(intent);
    }
}
