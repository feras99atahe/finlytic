package com.example.finlytic

import io.flutter.embedding.android.FlutterActivity

/// Dialog-style activity that runs the `quickAddMain` Flutter entrypoint and
/// shows only the quick-add card (over a dim scrim) instead of the full app.
/// Launched by the home-screen widget buttons via `finlytic://add?type=…`.
///
/// Rendered opaque (default surface mode) for reliable compositing; the dim
/// "floating over the screen" look is painted by the Flutter scrim itself.
class QuickAddActivity : FlutterActivity() {

    /// `income | expense | transfer`, taken from the launch URI.
    private val type: String
        get() = intent?.data?.getQueryParameter("type") ?: "expense"

    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun getDartEntrypointArgs(): List<String> = listOf(type)
}
