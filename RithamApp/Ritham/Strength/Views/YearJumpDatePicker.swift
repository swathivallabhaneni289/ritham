import SwiftUI

// STRENGTH-05's year-jump navigation: a compact year list, and within a selected year, a month
// list -- never an infinite-scroll list of every week, per .planning/REQUIREMENTS.md's explicit
// wording. Offered years and months are derived from `availableDates` (the caller's already-loaded
// session dates, see `StrengthHistoryView.StrengthHistoryModel.allSessionStartDates`), never from
// a load this picker performs itself, so a user is never offered a period with nothing in it.
//
// Selecting a month hands the caller a `ClosedRange<Date>` spanning that month, which
// `StrengthHistoryModel.loadDateRange(_:)` loads through `HealthDataStore`'s date-range accessor
// -- this file has no persistence code of its own and computes only the range boundaries.

struct YearJumpDatePicker: View {
    let availableDates: [Date]
    let calendar: Calendar
    let onSelectRange: (ClosedRange<Date>?) -> Void

    @State private var selectedYear: Int?
    @State private var selectedMonth: Int?

    init(
        availableDates: [Date],
        calendar: Calendar = .current,
        onSelectRange: @escaping (ClosedRange<Date>?) -> Void
    ) {
        self.availableDates = availableDates
        self.calendar = calendar
        self.onSelectRange = onSelectRange
    }

    // MARK: - Pure date arithmetic (tested directly, no rendering required)

    /// Years containing at least one date in `dates`, most recent first.
    static func availableYears(in dates: [Date], calendar: Calendar = .current) -> [Int] {
        Set(dates.map { calendar.component(.year, from: $0) }).sorted(by: >)
    }

    /// Months (1-12) within `year` containing at least one date in `dates`, ascending.
    static func availableMonths(in dates: [Date], year: Int, calendar: Calendar = .current) -> [Int] {
        let months = dates
            .filter { calendar.component(.year, from: $0) == year }
            .map { calendar.component(.month, from: $0) }
        return Set(months).sorted()
    }

    /// The closed date range spanning every instant of `month`/`year`, or `nil` if the components
    /// don't resolve against `calendar` (never expected for a valid 1-12 month).
    static func range(forYear year: Int, month: Int, calendar: Calendar = .current) -> ClosedRange<Date>? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard
            let start = calendar.date(from: components),
            let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: start)
        else {
            return nil
        }
        let end = startOfNextMonth.addingTimeInterval(-1)
        return start...end
    }

    // MARK: - View

    var body: some View {
        let years = Self.availableYears(in: availableDates, calendar: calendar)

        if !years.isEmpty {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Jump to a date")
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)

                HStack(spacing: RithamSpacing.sm) {
                    ForEach(years, id: \.self) { year in
                        ChoiceChip(title: String(year), isSelected: selectedYear == year) {
                            selectYear(year)
                        }
                    }
                }

                if let selectedYear {
                    let months = Self.availableMonths(in: availableDates, year: selectedYear, calendar: calendar)
                    HStack(spacing: RithamSpacing.sm) {
                        ForEach(months, id: \.self) { month in
                            ChoiceChip(title: monthName(month), isSelected: selectedMonth == month) {
                                selectMonth(month, inYear: selectedYear)
                            }
                        }
                    }

                    SecondaryCTAButton(title: "Clear date selection") {
                        clearSelection()
                    }
                }
            }
        }
    }

    private func selectYear(_ year: Int) {
        if selectedYear == year {
            clearSelection()
        } else {
            selectedYear = year
            selectedMonth = nil
            onSelectRange(nil)
        }
    }

    private func selectMonth(_ month: Int, inYear year: Int) {
        if selectedMonth == month {
            selectedMonth = nil
            onSelectRange(nil)
        } else {
            selectedMonth = month
            onSelectRange(Self.range(forYear: year, month: month, calendar: calendar))
        }
    }

    private func clearSelection() {
        selectedYear = nil
        selectedMonth = nil
        onSelectRange(nil)
    }

    private func monthName(_ month: Int) -> String {
        var localizedCalendar = calendar
        localizedCalendar.locale = Locale(identifier: "en_US")
        let symbols = localizedCalendar.monthSymbols
        guard symbols.indices.contains(month - 1) else { return String(month) }
        return symbols[month - 1]
    }
}
