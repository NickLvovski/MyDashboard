import SwiftUI
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case overview, goals, tasks, notes, data
    var id: String { rawValue }
    var title: String {
        switch self { case .overview: return "Обзор"; case .goals: return "Мои цели"; case .tasks: return "Задачи"; case .notes: return "Apple Заметки"; case .data: return "Данные" }
    }
    var symbol: String {
        switch self { case .overview: return "square.grid.2x2"; case .goals: return "scope"; case .tasks: return "checklist"; case .notes: return "square.and.arrow.up"; case .data: return "externaldrive" }
    }
}
enum EditorRoute: Identifiable {
    case goal(LifeGoal), task(LifeTask), detail(UUID)
    var id: String {
        switch self { case .goal(let g): return "goal-\(g.id)"; case .task(let t): return "task-\(t.id)"; case .detail(let id): return "detail-\(id)" }
    }
}
enum DeleteTarget {
    case goal(LifeGoal), task(LifeTask)
    var title: String { switch self { case .goal(let goal): return "Удалить «\(goal.title)»?"; case .task(let task): return "Удалить «\(task.title)»?" } }
    var message: String { switch self { case .goal: return "Связанные задачи сохранятся без цели."; case .task: return "Задача будет удалена. Это может изменить прогресс связанной цели." } }
}

struct ContentView: View {
    @EnvironmentObject var store: DashboardStore
    @ViewState private var section: AppSection = .overview
    @ViewState private var editor: EditorRoute?
    @ViewState private var deletion: DeleteTarget?
    @ViewState private var query = ""
    @ViewState private var area = "all"
    @ViewState private var filter: TaskFilter = .open
    @ViewState private var goalFilter: UUID?
    @ViewState private var now = Date()
    @ViewState private var resetDemo = false
    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 400), spacing: 16)]

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    topbar
                    pageHeader
                    if store.document.isDemo { demoBanner }
                    if store.recoveryRequired {
                        Label("Данные не прочитаны. Восстановите их в разделе «Данные».", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(.orange)
                    }
                    switch section {
                    case .overview: overview
                    case .goals: goalsPage
                    case .tasks: tasksPage
                    case .notes: NotesExportView()
                    case .data: DataSettingsView()
                    }
                    HStack {
                        Text("Каждый небольшой шаг имеет значение.")
                        Spacer()
                        Label("Хранится на этом Mac", systemImage: "lock")
                    }.font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.8)).padding(.top, 5)
                }.padding(30).frame(maxWidth: 1350, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Palette.background).id(section)
        }
        .tint(Palette.green).foregroundStyle(Palette.ink)
        .frame(minWidth: 920, minHeight: 620)
        .sheet(item: $editor) { route in
            switch route {
            case .goal(let goal): GoalEditor(goal: goal)
            case .task(let task): TaskEditor(task: task)
            case .detail(let id): GoalDetailView(goalID: id, onEdit: { editor = .goal($0) }, onNewTask: { editor = .task(LifeTask(title: "", goalID: id)) }, onEditTask: { editor = .task($0) })
            }
        }
        .alert(item: $store.notice) { notice in Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("Понятно"))) }
        .confirmationDialog(deletion?.title ?? "Удалить?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
            if let target = deletion {
                Button("Удалить", role: .destructive) {
                    switch target { case .goal(let g): store.removeGoal(g.id); case .task(let t): store.removeTask(t.id) }
                    deletion = nil
                }
            }
        } message: { Text(deletion?.message ?? "") }
        .confirmationDialog("Начать с чистого листа?", isPresented: $resetDemo, titleVisibility: .visible) {
            Button("Удалить демонстрационные данные", role: .destructive) { _ = store.save(DashboardDocument()) }
        } message: { Text("Все цели и задачи из примера, включая ваши изменения в нём, будут удалены. Можно сначала сделать резервную копию в разделе «Данные».") }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in editor = .task(LifeTask(title: "")) }
        .onReceive(NotificationCenter.default.publisher(for: .newGoal)) { _ in editor = .goal(LifeGoal(title: "")) }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        .onChange(of: section) { _, _ in query = ""; area = "all"; goalFilter = nil }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "location.north.circle").font(.system(size: 26, weight: .light)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(Palette.green, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Мой курс").font(.system(size: 20, weight: .semibold))
                    Text("Цели. Шаги. Прогресс.").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
            }.padding(.horizontal, 18).padding(.top, 26).padding(.bottom, 35)
            Text("МОЁ ПРОСТРАНСТВО").font(.system(size: 9, weight: .medium)).tracking(1.4).foregroundStyle(Palette.muted).padding(.horizontal, 20).padding(.bottom, 12)
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol).font(.system(size: 12)).padding(.vertical, 7).tag(item)
                }
            }.listStyle(.sidebar).scrollContentBackground(.hidden)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "leaf").font(.system(size: 19)).foregroundStyle(Palette.green)
                Text("Не нужно успеть всё.\nВыберите то, что важно вам.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(5)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line)).padding(16)
            Label("Личный дашборд", systemImage: "person.crop.circle").font(.system(size: 11)).foregroundStyle(Palette.muted).padding(20)
        }
    }
    private var topbar: some View {
        HStack {
            Label(longDate, systemImage: "calendar").font(.system(size: 11))
            Spacer()
            Circle().fill(store.recoveryRequired ? Color.orange : Palette.green.opacity(0.65)).frame(width: 5, height: 5)
            Text(store.savedAt == nil ? "Локальные данные" : "Изменения сохранены").font(.system(size: 10))
        }.foregroundStyle(Palette.muted)
    }
    private var longDate: String {
        let format = DateFormatter(); format.locale = Locale(identifier: "ru_RU"); format.dateFormat = "EEEE, d MMMM yyyy"
        let text = format.string(from: now)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    private var pageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 9) {
                Text("ЖИЗНЬ В ВАШЕМ ТЕМПЕ").font(.system(size: 9, weight: .medium)).tracking(1.7).foregroundStyle(Palette.muted)
                Text(pageTitle).font(.system(size: 30, weight: .medium)).tracking(-0.8)
                Text(pageSubtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            if section == .overview || section == .goals || section == .tasks {
                if section != .tasks {
                    Button { editor = .goal(LifeGoal(title: "")) } label: { Label("Новая цель", systemImage: "plus") }.buttonStyle(GreenButton(prominent: section == .goals))
                }
                if section != .goals {
                    Button { editor = .task(LifeTask(title: "")) } label: { Label("Новая задача", systemImage: "plus") }.buttonStyle(GreenButton())
                }
            }
        }
    }
    private var pageTitle: String {
        switch section { case .overview: return "Всё начинается с шага"; case .goals: return "Мои жизненные цели"; case .tasks: return "От планов к действиям"; case .notes: return "Задачи всегда под рукой"; case .data: return "Ваши данные" }
    }
    private var pageSubtitle: String {
        switch section {
        case .overview: return "Важные цели и небольшие дела, которые приближают к ним."
        case .goals: return "Выберите направление и отслеживайте свой прогресс."
        case .tasks: return "Один список для того, что нужно сделать."
        case .notes: return "Перенесите список задач в Apple Заметки на Mac и iPhone."
        case .data: return "Резервные копии и локальное хранение."
        }
    }
    private var demoBanner: some View {
        HStack {
            Label("Это пример. Цели и задачи здесь демонстрационные.", systemImage: "sparkles").font(.system(size: 11))
            Spacer()
            Button("Начать с чистого листа") { resetDemo = true }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain)
        }.foregroundStyle(Color(hex: 0x817549)).padding(13).background(Color(hex: 0xF0EDDF), in: RoundedRectangle(cornerRadius: 8))
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 26) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                StatCard(label: "Жизненные цели", value: "\(store.goals.count)", symbol: "scope", footnote: "\(store.goals.filter { $0.progress(in: store.tasks) >= 1 }.count) достигнуто")
                StatCard(label: "Общий прогресс", value: "\(Int((store.averageProgress * 100).rounded()))%", symbol: "chart.bar", footnote: "Среднее по всем целям")
                StatCard(label: "Задачи на сегодня", value: "\(store.tasks.filter { TaskFilter.today.includes($0, now: now) }.count)", symbol: "sun.max", footnote: "\(store.tasks.filter { TaskFilter.overdue.includes($0, now: now) }.count) просрочено")
                StatCard(label: "Выполнено задач", value: "\(store.tasks.filter(\.isDone).count)", symbol: "checkmark.circle", footnote: "Из \(store.tasks.count) в списке")
            }
            SectionHeading(title: "Мои цели", count: store.goals.count, action: "Все цели") { section = .goals }
            if store.goals.isEmpty {
                Panel {
                    VStack(spacing: 6) {
                        EmptyPlaceholder(symbol: "location.north.circle", title: "Какая цель сейчас важнее всего?", message: "Добавьте первую цель, а затем разбейте её на небольшие задачи.", actionTitle: "Добавить первую цель") { editor = .goal(LifeGoal(title: "")) }
                        if store.tasks.isEmpty {
                            Button("Посмотреть пример") { _ = store.save(.sample()) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 16) { ForEach(Array(store.goals.prefix(4))) { goal in goalCard(goal) } }
            }
            HStack(alignment: .top, spacing: 22) {
                Panel {
                    VStack(alignment: .leading, spacing: 17) {
                        SectionHeading(title: "Ближайшие задачи", action: "Все задачи") { section = .tasks }
                        if upcoming.isEmpty {
                            EmptyPlaceholder(symbol: "checkmark.circle", title: "Здесь спокойно", message: "Нет активных задач. Добавьте следующий шаг к своей цели.", actionTitle: "Добавить задачу") { editor = .task(LifeTask(title: "")) }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(upcoming) { task in
                                    taskRow(task)
                                    if task.id != upcoming.last?.id { Divider().overlay(Palette.line.opacity(0.4)) }
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity)
                VStack(spacing: 17) {
                    WeekActivityView(tasks: store.tasks, now: now)
                    VStack(alignment: .leading, spacing: 13) {
                        Label("С собой на iPhone", systemImage: "note.text").font(.system(size: 13, weight: .semibold))
                        Text("Отправьте список в Apple Заметки. Заметка в iCloud будет доступна и на iPhone.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                        Button("Перенести задачи", systemImage: "square.and.arrow.up") { section = .notes }.buttonStyle(GreenButton(prominent: false))
                    }.padding(21).frame(maxWidth: .infinity, alignment: .leading).background(Palette.soft, in: RoundedRectangle(cornerRadius: 14))
                }.frame(width: 280)
            }
        }
    }
    private var upcoming: [LifeTask] { Array(store.tasks.filter { !$0.isDone }.sorted(by: taskOrder).prefix(5)) }
    private var goalsPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                TextField("Найти цель…", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                Picker("Сфера", selection: $area) { Text("Все сферы").tag("all"); ForEach(LifeArea.allCases) { Text($0.title).tag($0.rawValue) } }.frame(width: 220)
                Spacer()
            }
            if filteredGoals.isEmpty {
                Panel { EmptyPlaceholder(symbol: "scope", title: store.goals.isEmpty ? "Пока нет целей" : "Ничего не найдено", message: store.goals.isEmpty ? "Добавьте цель, которая задаст направление." : "Попробуйте другой запрос или сферу.", actionTitle: store.goals.isEmpty ? "Добавить цель" : nil) { editor = .goal(LifeGoal(title: "")) } }
            } else {
                LazyVGrid(columns: columns, spacing: 16) { ForEach(filteredGoals) { goalCard($0) } }
            }
        }
    }
    private var filteredGoals: [LifeGoal] {
        store.goals.filter { (area == "all" || $0.area.rawValue == area) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
    }
    private var tasksPage: some View {
        let shown = filteredTasks
        return VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 15) {
                TextField("Найти задачу…", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                Picker("Цель", selection: $goalFilter) {
                    Text("Все цели").tag(Optional<UUID>.none)
                    ForEach(store.goals) { Text($0.title).tag(Optional($0.id)) }
                }.frame(maxWidth: 300)
                Spacer()
            }
            Picker("Список", selection: $filter) { ForEach(TaskFilter.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Panel {
                if shown.isEmpty { EmptyPlaceholder(symbol: "checklist", title: "В этом списке нет задач", message: "Добавьте задачу или выберите другой фильтр.", actionTitle: "Добавить задачу") { editor = .task(LifeTask(title: "", goalID: goalFilter)) } }
                else {
                    LazyVStack(spacing: 0) {
                        ForEach(shown) { task in taskRow(task); if task.id != shown.last?.id { Divider().overlay(Palette.line.opacity(0.4)) } }
                    }
                }
            }
            Text("\(shown.count) задач в выбранном списке").font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }
    private var filteredTasks: [LifeTask] {
        store.tasks.filter { filter.includes($0, now: now) && (goalFilter == nil || $0.goalID == goalFilter) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }.sorted(by: taskOrder)
    }
    private func goalCard(_ goal: LifeGoal) -> some View {
        GoalCard(goal: goal, tasks: store.tasks, onOpen: { editor = .detail(goal.id) }, onEdit: { editor = .goal(goal) }, onDelete: { deletion = .goal(goal) })
    }
    private func taskRow(_ task: LifeTask) -> some View {
        TaskRow(task: task, onEdit: { editor = .task(task) }, onDelete: { deletion = .task(task) })
    }
}

struct WeekActivityView: View {
    let tasks: [LifeTask]
    let now: Date
    private var days: [Date] { (-6...0).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: now)) } }
    private func count(_ date: Date) -> Int { tasks.filter { $0.isDone && $0.completedAt.map { Calendar.current.isDate($0, inSameDayAs: date) } == true }.count }
    private var total: Int { days.reduce(0) { $0 + count($1) } }
    private var maximum: Int { max(1, days.map(count).max() ?? 1) }
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("Маленькие победы").font(.system(size: 14, weight: .semibold)); Spacer(); Text("7 дней").font(.system(size: 10)).foregroundStyle(Palette.muted) }
                Text("Выполненные задачи за последние дни").font(.system(size: 10)).foregroundStyle(Palette.muted)
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 7) {
                            Text("\(count(day))").font(.system(size: 9)).foregroundStyle(Palette.muted)
                            RoundedRectangle(cornerRadius: 4).fill(Calendar.current.isDateInToday(day) ? Palette.green.opacity(0.6) : Color(hex: 0xDBE4CE)).frame(width: 20, height: max(3, CGFloat(count(day)) / CGFloat(maximum) * 74))
                            Text(day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "ru_RU")))).font(.system(size: 9)).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }.frame(height: 115).accessibilityElement(children: .ignore).accessibilityLabel("Выполнено \(total) задач за последние семь дней")
                Divider()
                HStack { Text("Всего за 7 дней"); Spacer(); Text("\(total) задач").fontWeight(.medium).foregroundStyle(Palette.green) }.font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
    }
}
