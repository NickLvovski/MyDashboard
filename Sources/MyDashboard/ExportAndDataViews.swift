import SwiftUI
import AppKit

struct NotesExportView: View {
    @EnvironmentObject var store: DashboardStore
    @ViewState private var filter: TaskFilter = .open
    @ViewState private var goalID: UUID?
    @ViewState private var copied = false
    private var exported: (text: String, count: Int) { store.document.taskExport(filter: filter, goalID: goalID) }

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Panel {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Что перенести").font(.system(size: 17, weight: .semibold))
                    Picker("Список задач", selection: $filter) { ForEach(TaskFilter.allCases) { Text($0.title).tag($0) } }
                    Picker("Цель", selection: $goalID) { Text("Все цели").tag(Optional<UUID>.none); ForEach(store.goals) { Text($0.title).tag(Optional($0.id)) } }
                    HStack { Text("Предпросмотр"); Spacer(); Text("\(exported.count) задач") }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                    ScrollView {
                        Text(exported.text).textSelection(.enabled).font(.system(size: 12)).lineSpacing(6).frame(maxWidth: .infinity, alignment: .leading).padding(17)
                    }.frame(height: 310).background(Palette.background, in: RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 12) {
                        ShareLink(item: exported.text, preview: SharePreview("Мой курс — задачи")) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }.buttonStyle(GreenButton()).disabled(exported.count == 0).help("Выберите Заметки в системном меню")
                        Button(copied ? "Скопировано" : "Копировать", systemImage: copied ? "checkmark" : "doc.on.doc") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(exported.text, forType: .string); copied = true
                        }.buttonStyle(GreenButton(prominent: false)).disabled(exported.count == 0)
                    }
                    Button("Сохранить TXT…", systemImage: "arrow.down.document") { store.exportText(exported.text) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.green).disabled(exported.count == 0)
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Из Mac — на iPhone", systemImage: "iphone").font(.system(size: 16, weight: .semibold))
                    noteStep(1, title: "Нажмите «Поделиться»", text: "Выберите «Заметки» и сохраните список в заметку. Если Заметок нет в меню, используйте TXT или скопируйте текст.")
                    noteStep(2, title: "Выберите папку iCloud", text: "Заметка в папке «На моём Mac» останется только на компьютере.")
                    noteStep(3, title: "Откройте Заметки на iPhone", text: "Войдите в тот же Apple Account и включите Заметки в настройках iCloud.")
                    Divider()
                    Text("Через файл").font(.system(size: 12, weight: .semibold))
                    Text("Сохраните TXT. В Заметках на Mac выберите «Файл → Импортировать в Заметки» и папку iCloud. На iPhone файл можно открыть в «Файлах» и отправить в Заметки через «Поделиться».").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(5)
                    Text("Это копия списка. Отметки в Заметках не обновляют дашборд. Символы ☐ — текстовые пункты; при необходимости оформите список как чеклист в Заметках.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(4).padding(13).background(Palette.soft, in: RoundedRectangle(cornerRadius: 8))
                    Link("Инструкция Apple", destination: URL(string: "https://support.apple.com/en-gb/102223")!).font(.system(size: 11))
                }
            }.frame(width: 330)
        }.onChange(of: filter) { _, _ in copied = false }.onChange(of: goalID) { _, _ in copied = false }
            .onChange(of: store.document) { _, _ in copied = false }
    }
    private func noteStep(_ number: Int, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.system(size: 11, weight: .medium)).frame(width: 25, height: 25).background(Palette.soft, in: Circle()).foregroundStyle(Palette.green)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(text).font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
            }
        }
    }
}

struct DataSettingsView: View {
    @EnvironmentObject var store: DashboardStore
    @ViewState private var incoming: DashboardDocument?
    @ViewState private var reset = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 22) {
                Panel {
                    VStack(alignment: .leading, spacing: 17) {
                        Label("Резервная копия", systemImage: "externaldrive.badge.checkmark").font(.system(size: 16, weight: .semibold))
                        Text("Сохраните цели, показатели и задачи в JSON-файл. Его можно восстановить в приложении на другом Mac.").font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(5)
                        Button("Сохранить копию…", systemImage: "arrow.down.document") { store.exportBackup() }.buttonStyle(GreenButton()).disabled(store.recoveryRequired)
                        Button("Восстановить из файла…", systemImage: "arrow.up.document") { incoming = store.readBackup() }.buttonStyle(GreenButton(prominent: false))
                        Text("При изменениях предыдущая версия данных также сохраняется в dashboard.previous.json рядом с основным файлом.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(4)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 17) {
                        Label("Только на вашем Mac", systemImage: "lock.shield").font(.system(size: 16, weight: .semibold))
                        Text("Цели и задачи сохраняются автоматически после каждого изменения. Интернет и аккаунт для работы приложения не нужны.").font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(5)
                        Text(store.fileURL.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled).lineLimit(5)
                        Button("Показать файл в Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }.buttonStyle(GreenButton(prominent: false)).disabled(!FileManager.default.fileExists(atPath: store.fileURL.path))
                        Text("Перенос списка в Apple Заметки выполняется отдельно. Автоматической синхронизации задач между устройствами нет.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(4)
                    }
                }
            }
            if store.recoveryRequired {
                Panel {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Восстановление данных", systemImage: "exclamationmark.triangle").font(.system(size: 15, weight: .semibold)).foregroundStyle(.orange)
                        Text("Исходный файл не изменён. Сохраните его отдельно, затем восстановите исправную копию или начните заново. При восстановлении исходный файл также будет сохранён рядом с данными.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        Button("Сохранить исходный файл…") { store.preserveUnreadableFile() }.buttonStyle(GreenButton(prominent: false))
                        Button("Начать заново…", role: .destructive) { reset = true }
                    }
                }
            } else if store.goals.isEmpty && store.tasks.isEmpty {
                Panel {
                    HStack {
                        VStack(alignment: .leading, spacing: 7) { Text("Посмотрите, как это работает").font(.system(size: 14, weight: .medium)); Text("Загрузите пример с четырьмя целями и несколькими задачами.").font(.system(size: 11)).foregroundStyle(Palette.muted) }
                        Spacer()
                        Button("Открыть пример") { _ = store.save(.sample()) }.buttonStyle(GreenButton(prominent: false))
                    }
                }
            }
        }
        .confirmationDialog("Восстановить резервную копию?", isPresented: Binding(get: { incoming != nil }, set: { if !$0 { incoming = nil } }), titleVisibility: .visible) {
            if let replacement = incoming {
                Button("Восстановить", role: .destructive) { _ = store.save(replacement, allowRecovery: true); incoming = nil }
            }
        } message: { Text("В файле: \(incoming?.goals.count ?? 0) целей и \(incoming?.tasks.count ?? 0) задач. Они заменят текущие данные. Предыдущая версия будет сохранена рядом с основным файлом.") }
        .confirmationDialog("Начать заново?", isPresented: $reset, titleVisibility: .visible) {
            Button("Создать пустой дашборд", role: .destructive) { _ = store.save(DashboardDocument(), allowRecovery: true) }
        } message: { Text("Исходный файл будет сохранён рядом с данными для восстановления.") }
    }
}
