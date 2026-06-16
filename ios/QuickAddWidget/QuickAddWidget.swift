import WidgetKit
import SwiftUI

// MARK: - Timeline

struct QuickAddEntry: TimelineEntry {
    let date: Date
    let balance: String
}

struct Provider: TimelineProvider {
    // App Group shared with the Runner target. Must match WidgetService.appGroupId.
    let appGroupId = "group.com.example.finlytic"

    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date(), balance: "0.00")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [readEntry()], policy: .never))
    }

    private func readEntry() -> QuickAddEntry {
        // home_widget stores values under this UserDefaults suite, prefixed key.
        let defaults = UserDefaults(suiteName: appGroupId)
        let balance = defaults?.string(forKey: "balance") ?? "0.00"
        return QuickAddEntry(date: Date(), balance: balance)
    }
}

// MARK: - View

struct QuickAddWidgetEntryView: View {
    var entry: QuickAddEntry

    private let dark = Color(red: 0.078, green: 0.078, blue: 0.075)
    private let light = Color(red: 0.980, green: 0.976, blue: 0.961)
    private let orange = Color(red: 0.851, green: 0.467, blue: 0.341)
    private let green = Color(red: 0.471, green: 0.549, blue: 0.365)
    private let midGray = Color(red: 0.690, green: 0.682, blue: 0.647)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("finlytic")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(dark)
                Spacer()
                Text("$\(entry.balance)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(midGray)
            }
            Text("Quick add")
                .font(.system(size: 11))
                .foregroundColor(midGray)

            HStack(spacing: 6) {
                button(title: "+ Income", color: green, type: "income")
                button(title: "− Expense", color: orange, type: "expense")
                button(title: "⇄ Transfer", color: dark, type: "transfer")
            }
        }
        .padding(14)
    }

    private func button(title: String, color: Color, type: String) -> some View {
        Link(destination: URL(string: "finlytic://add?type=\(type)")!) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(light)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color)
                .cornerRadius(12)
        }
    }
}

// MARK: - Widget

@main
struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                QuickAddWidgetEntryView(entry: entry)
                    .containerBackground(.white, for: .widget)
            } else {
                QuickAddWidgetEntryView(entry: entry)
                    .background(Color.white)
            }
        }
        .configurationDisplayName("finlytic quick add")
        .description("Quickly add an income, expense, or transfer.")
        .supportedFamilies([.systemMedium])
    }
}
