import Foundation

@main
struct ModelChecks {
    @MainActor
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
            guard try condition() else { throw DataError.invalid("FAILED: \(message)") }
            checks += 1
        }
        func reject(_ document: DashboardDocument, _ message: String) throws {
            do { _ = try document.validated() }
            catch { checks += 1; return }
            throw DataError.invalid("FAILED: \(message)")
        }
        let now = ISO8601DateFormatter().date(from: "2026-10-11T10:00:00Z")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Almaty")!
        let metric = LifeGoal(title: "12 книг", current: 6, target: 12, unit: "книг")
        try expect(metric.progress(in: []) == 0.5, "Metric progress")
        var overTarget = metric; overTarget.current = 20
        try expect(overTarget.progress(in: []) == 1, "Progress capped at 100%")
        var byTasks = metric; byTasks.mode = .tasks
        let done = LifeTask(title: "Готово", goalID: byTasks.id, isDone: true, completedAt: now)
        let open = LifeTask(title: "Открыто", goalID: byTasks.id, dueDate: cal.startOfDay(for: now))
        try expect(byTasks.progress(in: []) == 0, "Empty task progress")
        try expect(byTasks.progress(in: [done, open]) == 0.5, "Task progress")
        try expect(TaskFilter.today.includes(open, now: now, calendar: cal), "Today's task")
        try expect(!TaskFilter.overdue.includes(open, now: now, calendar: cal), "Today is not overdue")
        var overdue = open; overdue.dueDate = cal.date(byAdding: .day, value: -1, to: now)
        try expect(TaskFilter.overdue.includes(overdue, now: now, calendar: cal), "Overdue task")
        var edge = open; edge.dueDate = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: now))
        try expect(!TaskFilter.week.includes(edge, now: now, calendar: cal), "7-day boundary excluded")
        edge.dueDate = cal.date(byAdding: .day, value: 6, to: cal.startOfDay(for: now))
        try expect(TaskFilter.week.includes(edge, now: now, calendar: cal), "Day six included")
        try expect(!TaskFilter.open.includes(done), "Completed task excluded from active")
        let sample = DashboardDocument.sample(now: now)
        let encoded = try sample.encoded()
        let restored = try DashboardDocument.decode(encoded)
        try expect(try restored.encoded() == encoded, "JSON round trip preserves data")
        let exported = restored.taskExport(filter: .all, now: now)
        try expect(exported.count == restored.tasks.count, "Export count")
        try expect(exported.text.contains("☐") && exported.text.contains("☑") && exported.text.contains("Финансовая подушка"), "Unicode export")
        try expect(restored.taskExport(filter: .done).count == 3, "Export completed tasks")
        try expect(restored.taskExport(goalID: restored.goals[1].id).count == 3, "Export goal subset")
        try expect(parseNumber("350 000,5") == 350000.5, "Russian numeric input")
        var invalid = sample; invalid.goals[0].target = 0
        try reject(invalid, "Reject zero target")
        invalid = sample; invalid.goals.append(invalid.goals[0])
        try reject(invalid, "Reject duplicate goals")
        invalid = sample; invalid.tasks[0].goalID = UUID()
        try reject(invalid, "Reject orphan task")
        invalid = sample; invalid.tasks[0].isDone = true
        try reject(invalid, "Reject missing completion date")
        invalid = sample; invalid.version = 99
        try reject(invalid, "Reject unknown format version")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mydashboard-checks-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DashboardStore(directory: directory)
        try expect(store.goals.isEmpty && store.tasks.isEmpty, "Starts without fabricated data")
        try expect(store.save(sample), "Save initial document")
        let reloaded = DashboardStore(directory: directory)
        try expect(reloaded.goals.count == 4 && reloaded.tasks.count == 10, "Persistence after restart")
        let task = reloaded.tasks[0]
        reloaded.toggle(task)
        try expect(reloaded.tasks[0].isDone && reloaded.tasks[0].completedAt != nil, "Completion stored")
        reloaded.toggle(reloaded.tasks[0])
        try expect(!reloaded.tasks[0].isDone && reloaded.tasks[0].completedAt == nil, "Uncompletion stored")
        let goalID = reloaded.goals[1].id
        reloaded.removeGoal(goalID)
        try expect(reloaded.goals.count == 3 && reloaded.tasks.count == 10, "Deleting goal keeps tasks")
        try expect(reloaded.tasks.allSatisfy { $0.goalID != goalID }, "Deleted goal links cleared")
        let previousURL = directory.appendingPathComponent("dashboard.previous.json")
        try expect(FileManager.default.fileExists(atPath: previousURL.path), "Previous file exists")
        _ = try DashboardDocument.decode(Data(contentsOf: previousURL))
        let broken = Data("broken document".utf8)
        try broken.write(to: store.fileURL)
        let recovery = DashboardStore(directory: directory)
        try expect(recovery.recoveryRequired, "Corrupt data detected")
        try expect(!recovery.save(DashboardDocument()), "Normal writes blocked during recovery")
        try expect(try Data(contentsOf: store.fileURL) == broken, "Corrupt original not overwritten")
        try expect(recovery.save(sample, allowRecovery: true), "Explicit recovery succeeds")
        let recoveryFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("dashboard.recovery-") }
        try expect(recoveryFiles.count == 1, "Corrupt original preserved during recovery")
        try expect(try Data(contentsOf: recoveryFiles[0]) == broken, "Recovery file exact contents")
        let impossible = DashboardStore(directory: URL(fileURLWithPath: "/dev/null/no-directory"))
        try expect(!impossible.save(sample) && impossible.goals.isEmpty, "Failed save does not change visible data")
        print("Passed \(checks) model and persistence checks")
    }
}
