package com.example.finlytic

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget with Income / Expense / Transfer quick-add buttons.
/// Each button deep-links into the app's add screen on the matching tab.
class QuickAddWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)

            // Show the latest balance pushed from Flutter (defaults to $0.00).
            val balance = widgetData.getString("balance", "0.00") ?: "0.00"
            views.setTextViewText(R.id.widget_balance, "$$balance")

            views.setOnClickPendingIntent(
                R.id.widget_income,
                launchIntent(context, "income"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_expense,
                launchIntent(context, "expense"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_transfer,
                launchIntent(context, "transfer"),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launchIntent(context: Context, type: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            QuickAddActivity::class.java,
            Uri.parse("finlytic://add?type=$type"),
        )
}
