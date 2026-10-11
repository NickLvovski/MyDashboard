import Foundation

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
    var deadline: Date?

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
    var dueDate: Date?
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
        switch self {
        case .open: return true
        case .today: return task.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        case .overdue: return task.dueDate.map { calendar.startOfDay(for: $0) < calendar.startOfDay(for: now) } ?? false
        case .week:
            guard let due = task.dueDate, let end = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) else { return false }
            return due >= calendar.startOfDay(for: now) && due < end
        default: return false
        }
    }
}

struct DashboardDocument: Codable, Equatable {
    var version = 1
    var isDemo = false
    var goals: [LifeGoal] = []
    var tasks: [LifeTask] = []

    func validated() throws -> DashboardDocument {
        guard version == 1 else { throw DataError.invalid("Эта версия резервной копии не поддерживается.") }
        guard goals.count <= 500, tasks.count <= 10000 else { throw DataError.invalid("В файле слишком много записей.") }
        let goalIDs = Set(goals.map(\.id))
        guard goalIDs.count == goals.count, Set(tasks.map(\.id)).count == tasks.count else { throw DataError.invalid("В файле есть повторяющиеся идентификаторы.") }
        for goal in goals {
            guard !goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, goal.title.count <= 140,
                  goal.details.count <= 2000, goal.unit.count <= 30,
                  goal.current.isFinite, goal.current >= 0, goal.target.isFinite, goal.target > 0,
                  goal.deadline?.timeIntervalSince1970.isFinite ?? true else {
                throw DataError.invalid("Некорректные данные цели. Проверьте название и числовой показатель.")
            }
        }
        for task in tasks {
            guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, task.title.count <= 240,
                  task.goalID.map({ goalIDs.contains($0) }) ?? true,
                  task.isDone == (task.completedAt != nil),
                  task.createdAt.timeIntervalSince1970.isFinite,
                  task.dueDate?.timeIntervalSince1970.isFinite ?? true,
                  task.completedAt?.timeIntervalSince1970.isFinite ?? true else {
                throw DataError.invalid("Некорректные данные задачи или связь с отсутствующей целью.")
            }
        }
        return self
    }

    static func decode(_ data: Data) throws -> DashboardDocument {
        guard data.count <= 5_000_000 else { throw DataError.invalid("Файл больше 5 МБ.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data).validated()
    }
    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
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
        let cal = Calendar.current
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))! }
        let run = LifeGoal(title: "Пробежать первые 10 км", area: .health, details: "Бегать регулярно и постепенно увеличивать дистанцию.", current: 6, target: 10, unit: "км", deadline: day(70))
        let work = LifeGoal(title: "Собрать портфолио", area: .career, details: "Три проекта, которые показывают мой опыт.", mode: .tasks, deadline: day(45))
        let books = LifeGoal(title: "Прочитать 12 книг", area: .learning, current: 7, target: 12, unit: "книг", deadline: day(80))
        let money = LifeGoal(title: "Финансовая подушка", area: .finances, current: 350000, target: 1000000, unit: "₸", deadline: day(150))
        return DashboardDocument(isDemo: true, goals: [run, work, books, money], tasks: [
            LifeTask(title: "Пробежка в спокойном темпе", goalID: run.id, dueDate: day(0), priority: .high),
            LifeTask(title: "Описать первый кейс", goalID: work.id, dueDate: day(0), priority: .high),
            LifeTask(title: "Прочитать 20 страниц", goalID: books.id, dueDate: day(0)),
            LifeTask(title: "Перевести часть дохода в резерв", goalID: money.id, dueDate: day(2)),
            LifeTask(title: "Выбрать три проекта", goalID: work.id, dueDate: day(-1), isDone: true, completedAt: day(-1)),
            LifeTask(title: "Собрать материалы для кейсов", goalID: work.id, dueDate: day(-2), isDone: true, completedAt: day(-2)),
            LifeTask(title: "Оформить второй кейс", goalID: work.id, dueDate: day(4)),
            LifeTask(title: "Опубликовать портфолио", goalID: work.id, dueDate: day(7)),
            LifeTask(title: "Разминка и растяжка", goalID: run.id, dueDate: day(-3), isDone: true, completedAt: day(-3)),
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
func russianDate(_ date: Date) -> String {
    let format = DateFormatter(); format.locale = Locale(identifier: "ru_RU"); format.dateFormat = "d MMM yyyy"
    return format.string(from: date)
}
func parseNumber(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00a0}", with: "").replacingOccurrences(of: "\u{202f}", with: "").replacingOccurrences(of: ",", with: "."))
}
func taskOrder(_ lhs: LifeTask, _ rhs: LifeTask) -> Bool {
    if lhs.isDone != rhs.isDone { return !lhs.isDone }
    if lhs.dueDate != rhs.dueDate { return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture) }
    if lhs.priority != rhs.priority { return lhs.priority.order < rhs.priority.order }
    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
    return lhs.id.uuidString < rhs.id.uuidString
}
