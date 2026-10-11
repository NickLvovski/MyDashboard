import Foundation

/// A Gregorian calendar day, independent of the user's time zone.
struct CivilDate: Codable, Equatable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }
    init(_ date: Date, calendar: Calendar = .current) {
        let components = Self.gregorian(in: calendar.timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }
    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
    func date(in calendar: Calendar = .current) -> Date? {
        // Noon avoids midnight transitions when bridging to a native DatePicker.
        Self.gregorian(in: calendar.timeZone).date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }
    var isValid: Bool {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let utc = TimeZone(secondsFromGMT: 0), let date = date(in: Self.gregorian(in: utc)) else { return false }
        return CivilDate(date, calendar: Self.gregorian(in: utc)) == self
    }
    var isoDate: String { String(format: "%04d-%02d-%02d", year, month, day) }
    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if let calendar = decoder.userInfo[.legacyDateCalendar] as? Calendar,
           let instant = ISO8601DateFormatter().date(from: value) {
            self.init(instant, calendar: calendar)
        } else {
            let parts = value.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
                  let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
                throw DataError.invalid("Некорректный срок: ожидается дата ГГГГ-ММ-ДД.")
            }
            self.init(year: year, month: month, day: day)
            guard isoDate == value else { throw DataError.invalid("Некорректный формат срока.") }
        }
        guard isValid else { throw DataError.invalid("В сроке указана несуществующая дата.") }
    }
    func encode(to encoder: Encoder) throws {
        guard isValid else { throw DataError.invalid("В сроке указана несуществующая дата.") }
        var container = encoder.singleValueContainer()
        try container.encode(isoDate)
    }
}

private extension CodingUserInfoKey {
    static let legacyDateCalendar = CodingUserInfoKey(rawValue: "MyDashboard.legacyDateCalendar")!
}

enum LifeArea: String, Codable, CaseIterable, Identifiable {
    case health, career, learning, finances, personal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .health: return "Здоровье"
        case .career: return "Карьера"
        case .learning: return "Развитие"
        case .finances: return "Финансы"
        case .personal: return "Личное"
        }
    }
    var symbol: String {
        switch self {
        case .health: return "heart"
        case .career: return "briefcase"
        case .learning: return "book"
        case .finances: return "banknote"
        case .personal: return "sun.max"
        }
    }
}

enum ProgressMode: String, Codable, CaseIterable, Identifiable {
    case metric, tasks
    var id: String { rawValue }
    var title: String { self == .metric ? "По показателю" : "По задачам" }
}

struct LifeGoal: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var area: LifeArea = .personal
    var details = ""
    var mode: ProgressMode = .metric
    var current: Double = 0
    var target: Double = 100
    var unit = "%"
    var deadline: CivilDate?

    func progress(in tasks: [LifeTask]) -> Double {
        if mode == .tasks {
            let linked = tasks.filter { $0.goalID == id }
            return linked.isEmpty ? 0 : Double(linked.filter(\.isDone).count) / Double(linked.count)
        }
        guard target > 0, target.isFinite, current.isFinite else { return 0 }
        return min(1, max(0, current / target))
    }
    func progressDescription(in tasks: [LifeTask]) -> String {
        if mode == .tasks {
            let linked = tasks.filter { $0.goalID == id }
            return "\(linked.filter(\.isDone).count) из \(linked.count) задач"
        }
        return "\(numberText(current)) из \(numberText(target))\(unit.isEmpty ? "" : " " + unit)"
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case high, normal, low
    var id: String { rawValue }
    var title: String {
        switch self { case .high: return "Высокий"; case .normal: return "Обычный"; case .low: return "Низкий" }
    }
    var order: Int {
        switch self { case .high: return 0; case .normal: return 1; case .low: return 2 }
    }
}

struct LifeTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var goalID: UUID?
    var dueDate: CivilDate?
    var priority: TaskPriority = .normal
    var isDone = false
    var completedAt: Date?
    var createdAt = Date()
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case open, today, week, overdue, done, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .open: return "Активные"
        case .today: return "Сегодня"
        case .week: return "7 дней"
        case .overdue: return "Просроченные"
        case .done: return "Готово"
        case .all: return "Все"
        }
    }
    func includes(_ task: LifeTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if self == .all { return true }
        if self == .done { return task.isDone }
        if task.isDone { return false }
        let today = CivilDate(now, calendar: calendar)
        switch self {
        case .open: return true
        case .today: return task.dueDate == today
        case .overdue: return task.dueDate.map { $0 < today } ?? false
        case .week:
            let gregorian = CivilDate.gregorian(in: calendar.timeZone)
            guard let due = task.dueDate, let end = gregorian.date(byAdding: .day, value: 7, to: now) else { return false }
            return due >= today && due < CivilDate(end, calendar: gregorian)
        default: return false
        }
    }
}

struct DashboardDocument: Codable, Equatable {
    static let maximumFileBytes = 20_000_000
    var version = 2
    var isDemo = false
    var goals: [LifeGoal] = []
    var tasks: [LifeTask] = []

    func validated() throws -> DashboardDocument {
        guard version == 2 else { throw DataError.invalid("Эта версия резервной копии не поддерживается.") }
        guard goals.count <= 500, tasks.count <= 10000 else { throw DataError.invalid("В файле слишком много записей.") }
        let goalIDs = Set(goals.map(\.id))
        guard goalIDs.count == goals.count, Set(tasks.map(\.id)).count == tasks.count else { throw DataError.invalid("В файле есть повторяющиеся идентификаторы.") }
        for goal in goals {
            guard !goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, goal.title.count <= 140,
                  goal.details.count <= 2000, goal.unit.count <= 30,
                  goal.current.isFinite, goal.current >= 0, goal.target.isFinite, goal.target > 0,
                  goal.deadline?.isValid ?? true else {
                throw DataError.invalid("Некорректные данные цели. Проверьте название и числовой показатель.")
            }
        }
        for task in tasks {
            guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, task.title.count <= 240,
                  task.goalID.map({ goalIDs.contains($0) }) ?? true,
                  task.isDone == (task.completedAt != nil),
                  task.createdAt.timeIntervalSince1970.isFinite,
                  task.dueDate?.isValid ?? true,
                  task.completedAt?.timeIntervalSince1970.isFinite ?? true else {
                throw DataError.invalid("Некорректные данные задачи или связь с отсутствующей целью.")
            }
        }
        return self
    }

    static func checkFileSize(_ size: Int) throws {
        guard size <= maximumFileBytes else { throw DataError.invalid("Файл больше 20 МБ. Сократите объём данных перед сохранением или импортом.") }
    }
    static func fileVersion(in data: Data) throws -> Int {
        struct Header: Decodable { let version: Int }
        return try JSONDecoder().decode(Header.self, from: data).version
    }
    static func decode(_ data: Data, legacyCalendar: Calendar = .current) throws -> DashboardDocument {
        try checkFileSize(data.count)
        let version = try fileVersion(in: data)
        guard version == 1 || version == 2 else { throw DataError.invalid("Эта версия резервной копии не поддерживается.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Version 1 stored midnight instants without the original time zone.
        // Preserve the calendar day shown in the migration time zone, then freeze it.
        if version == 1 { decoder.userInfo[.legacyDateCalendar] = legacyCalendar }
        var document = try decoder.decode(Self.self, from: data)
        document.version = 2
        return try document.validated()
    }
    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        try Self.checkFileSize(data.count)
        return data
    }

    func taskExport(filter: TaskFilter = .open, goalID: UUID? = nil, now: Date = Date()) -> (text: String, count: Int) {
        let selected = tasks.filter { filter.includes($0, now: now) && (goalID == nil || $0.goalID == goalID) }.sorted(by: taskOrder)
        var lines = ["Мой курс — задачи", russianDate(now), ""]
        if isDemo { lines += ["Демонстрационный список", ""] }
        let groups = goals.map { Optional($0.id) } + [nil]
        for group in groups {
            let items = selected.filter { $0.goalID == group }
            if items.isEmpty { continue }
            lines.append(goals.first { $0.id == group }?.title ?? "Без цели")
            for item in items {
                let due = item.dueDate.map { " · " + russianDate($0) } ?? ""
                let priority = item.priority == .high ? " · Важно" : ""
                lines.append("\(item.isDone ? "☑" : "☐") \(item.title)\(due)\(priority)")
            }
            lines.append("")
        }
        if selected.isEmpty { lines.append("Нет задач для выбранного списка.") }
        return (lines.joined(separator: "\n"), selected.count)
    }

    static func sample(now: Date = Date()) -> DashboardDocument {
        let cal = CivilDate.gregorian(in: Calendar.current.timeZone)
        func instant(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now) ?? now }
        func day(_ offset: Int) -> CivilDate { CivilDate(instant(offset), calendar: cal) }
        let run = LifeGoal(title: "Пробежать первые 10 км", area: .health, details: "Бегать регулярно и постепенно увеличивать дистанцию.", current: 6, target: 10, unit: "км", deadline: day(70))
        let work = LifeGoal(title: "Собрать портфолио", area: .career, details: "Три проекта, которые показывают мой опыт.", mode: .tasks, deadline: day(45))
        let books = LifeGoal(title: "Прочитать 12 книг", area: .learning, current: 7, target: 12, unit: "книг", deadline: day(80))
        let money = LifeGoal(title: "Финансовая подушка", area: .finances, current: 350000, target: 1000000, unit: "₸", deadline: day(150))
        return DashboardDocument(isDemo: true, goals: [run, work, books, money], tasks: [
            LifeTask(title: "Пробежка в спокойном темпе", goalID: run.id, dueDate: day(0), priority: .high),
            LifeTask(title: "Описать первый кейс", goalID: work.id, dueDate: day(0), priority: .high),
            LifeTask(title: "Прочитать 20 страниц", goalID: books.id, dueDate: day(0)),
            LifeTask(title: "Перевести часть дохода в резерв", goalID: money.id, dueDate: day(2)),
            LifeTask(title: "Выбрать три проекта", goalID: work.id, dueDate: day(-1), isDone: true, completedAt: instant(-1)),
            LifeTask(title: "Собрать материалы для кейсов", goalID: work.id, dueDate: day(-2), isDone: true, completedAt: instant(-2)),
            LifeTask(title: "Оформить второй кейс", goalID: work.id, dueDate: day(4)),
            LifeTask(title: "Опубликовать портфолио", goalID: work.id, dueDate: day(7)),
            LifeTask(title: "Разминка и растяжка", goalID: run.id, dueDate: day(-3), isDone: true, completedAt: instant(-3)),
            LifeTask(title: "Записать идеи из книги", goalID: books.id, dueDate: day(3))
        ])
    }
}

enum DataError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}

func numberText(_ value: Double) -> String {
    let format = NumberFormatter()
    format.locale = Locale(identifier: "ru_RU")
    format.numberStyle = .decimal
    format.maximumFractionDigits = 2
    return format.string(from: NSNumber(value: value)) ?? String(value)
}
/// Swift's shortest round-trip representation retains every bit of the stored Double.
func editableNumberText(_ value: Double) -> String {
    String(value).replacingOccurrences(of: ".", with: ",")
}
func russianDate(_ date: Date) -> String {
    let format = DateFormatter(); format.locale = Locale(identifier: "ru_RU"); format.dateFormat = "d MMM yyyy"
    return format.string(from: date)
}
func russianDate(_ day: CivilDate) -> String {
    guard let utc = TimeZone(secondsFromGMT: 0), let date = day.date(in: CivilDate.gregorian(in: utc)) else { return day.isoDate }
    let format = DateFormatter()
    format.calendar = CivilDate.gregorian(in: utc)
    format.timeZone = utc
    format.locale = Locale(identifier: "ru_RU")
    format.dateFormat = "d MMM yyyy"
    return format.string(from: date)
}
func parseNumber(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00a0}", with: "").replacingOccurrences(of: "\u{202f}", with: "").replacingOccurrences(of: ",", with: "."))
}
func taskOrder(_ lhs: LifeTask, _ rhs: LifeTask) -> Bool {
    if lhs.isDone != rhs.isDone { return !lhs.isDone }
    if lhs.dueDate != rhs.dueDate {
        if let left = lhs.dueDate { return rhs.dueDate.map { left < $0 } ?? true }
        return false
    }
    if lhs.priority != rhs.priority { return lhs.priority.order < rhs.priority.order }
    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
    return lhs.id.uuidString < rhs.id.uuidString
}
