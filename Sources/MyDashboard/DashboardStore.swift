import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class DashboardStore: ObservableObject {
    @Published private(set) var document = DashboardDocument()
    @Published var notice: AppNotice?
    @Published private(set) var recoveryRequired = false
    @Published private(set) var savedAt: Date?
    let fileURL: URL

    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MyDashboard", isDirectory: true)
        fileURL = directory.appendingPathComponent("dashboard.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                document = try Self.readDocument(at: fileURL)
                savedAt = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            } catch {
                recoveryRequired = true
                notice = AppNotice(title: "Не удалось прочитать данные", message: "Исходный файл сохранён. Откройте раздел «Данные», сохраните повреждённый файл и восстановите резервную копию. \(error.localizedDescription)")
            }
        }
    }
    var goals: [LifeGoal] { document.goals }
    var tasks: [LifeTask] { document.tasks }
    var averageProgress: Double { goals.isEmpty ? 0 : goals.reduce(0) { $0 + $1.progress(in: tasks) } / Double(goals.count) }
    func goal(for task: LifeTask) -> LifeGoal? { goals.first { $0.id == task.goalID } }

    @discardableResult
    func save(_ updated: DashboardDocument, allowRecovery: Bool = false) -> Bool {
        if recoveryRequired && !allowRecovery {
            notice = AppNotice(title: "Сначала восстановите данные", message: "Исходный файл не будет перезаписан. Используйте раздел «Данные».")
            return false
        }
        do {
            let data = try updated.encoded()
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Preserve the previous readable document before replacing it atomically.
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let previous = try Data(contentsOf: fileURL)
                let previousName = recoveryRequired ? "dashboard.recovery-\(UUID().uuidString).json" : "dashboard.previous.json"
                try previous.write(to: fileURL.deletingLastPathComponent().appendingPathComponent(previousName), options: .atomic)
            }
            try data.write(to: fileURL, options: .atomic)
            document = updated
            recoveryRequired = false
            savedAt = Date()
            return true
        } catch {
            notice = AppNotice(title: "Изменения не сохранены", message: error.localizedDescription)
            return false
        }
    }
    @discardableResult
    func upsert(_ goal: LifeGoal) -> Bool {
        var updated = document
        if let index = updated.goals.firstIndex(where: { $0.id == goal.id }) { updated.goals[index] = goal }
        else { updated.goals.append(goal) }
        return save(updated)
    }
    @discardableResult
    func upsert(_ task: LifeTask) -> Bool {
        var updated = document
        if let index = updated.tasks.firstIndex(where: { $0.id == task.id }) { updated.tasks[index] = task }
        else { updated.tasks.append(task) }
        return save(updated)
    }
    func toggle(_ task: LifeTask) {
        var updated = task; updated.isDone.toggle(); updated.completedAt = updated.isDone ? Date() : nil
        _ = upsert(updated)
    }
    func removeGoal(_ id: UUID) {
        var updated = document
        updated.goals.removeAll { $0.id == id }
        for index in updated.tasks.indices where updated.tasks[index].goalID == id { updated.tasks[index].goalID = nil }
        _ = save(updated)
    }
    func removeTask(_ id: UUID) {
        var updated = document; updated.tasks.removeAll { $0.id == id }; _ = save(updated)
    }
    func exportBackup() {
        do { try saveFile(try document.encoded(), name: "Мой курс — резервная копия.json", type: .json) }
        catch { notice = AppNotice(title: "Не удалось создать копию", message: error.localizedDescription) }
    }
    func readBackup() -> DashboardDocument? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.message = "Выберите резервную копию. Данные будут проверены перед восстановлением."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do { return try Self.readDocument(at: url) }
        catch { notice = AppNotice(title: "Не удалось открыть копию", message: error.localizedDescription); return nil }
    }
    func exportText(_ text: String) {
        do { try saveFile(Data(text.utf8), name: "Мой курс — задачи.txt", type: .plainText) }
        catch { notice = AppNotice(title: "Не удалось экспортировать задачи", message: error.localizedDescription) }
    }
    func preserveUnreadableFile() {
        do { try saveFile(Data(contentsOf: fileURL), name: "dashboard-original.json", type: .json) }
        catch { notice = AppNotice(title: "Не удалось сохранить исходный файл", message: error.localizedDescription) }
    }
    private func saveFile(_ data: Data, name: String, type: UTType) throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [type]; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { try data.write(to: url, options: .atomic) }
    }
    private static func readDocument(at url: URL) throws -> DashboardDocument {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 5_000_000 else { throw DataError.invalid("Файл больше 5 МБ.") }
        return try DashboardDocument.decode(Data(contentsOf: url))
    }
}
