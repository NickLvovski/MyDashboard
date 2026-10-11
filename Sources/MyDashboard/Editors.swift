import SwiftUI

struct GoalEditor: View {
    @EnvironmentObject var store: DashboardStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft: LifeGoal
    @ViewState private var currentText: String
    @ViewState private var targetText: String
    @ViewState private var hasDeadline: Bool
    @ViewState private var deadline: Date
    @ViewState private var error = ""
    @FocusState private var titleFocused: Bool

    init(goal: LifeGoal) {
        _draft = State(initialValue: goal)
        _currentText = State(initialValue: editableNumberText(goal.current))
        _targetText = State(initialValue: editableNumberText(goal.target))
        _hasDeadline = State(initialValue: goal.deadline != nil)
        _deadline = State(initialValue: goal.deadline?.date() ?? Date())
    }
    private var isNew: Bool { !store.goals.contains { $0.id == draft.id } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(isNew ? "Новая жизненная цель" : "Редактировать цель").font(.system(size: 22, weight: .semibold))
            Form {
                TextField("Название", text: $draft.title).focused($titleFocused)
                Picker("Сфера жизни", selection: $draft.area) { ForEach(LifeArea.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) } }
                LabeledContent("Для чего мне это") {
                    TextEditor(text: $draft.details).font(.system(size: 12)).frame(height: 65).padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line))
                        .accessibilityLabel("Описание цели")
                }
                Section {
                    Picker("Как считать прогресс", selection: $draft.mode) { ForEach(ProgressMode.allCases) { Text($0.title).tag($0) } }
                    if draft.mode == .metric {
                        TextField("Текущее значение", text: $currentText)
                        TextField("Целевое значение", text: $targetText)
                        TextField("Единица измерения", text: $draft.unit, prompt: Text("км, книг, ₸…"))
                        Text("Обновляйте показатель вручную по мере продвижения к цели.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    } else {
                        Text("Прогресс = выполненные задачи / все задачи этой цели. Добавляйте задачи, чтобы разбить цель на шаги.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                    }
                }
                Section {
                    Toggle("У цели есть срок", isOn: $hasDeadline)
                    if hasDeadline { DatePicker("Достичь к", selection: $deadline, displayedComponents: .date) }
                }
            }.formStyle(.grouped).textFieldStyle(.roundedBorder)
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.red).accessibilityLabel("Ошибка: \(error)") }
            HStack {
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(GreenButton(prominent: false))
                Spacer()
                Button(isNew ? "Добавить цель" : "Сохранить") { save() }.keyboardShortcut(.defaultAction).buttonStyle(GreenButton())
            }
        }.padding(26).frame(width: 540).tint(Palette.green).onAppear { titleFocused = true }
    }
    private func save() {
        do {
            draft = try validatedGoalDraft(draft, currentText: currentText, targetText: targetText,
                                           deadline: hasDeadline ? CivilDate(deadline) : nil)
        } catch { self.error = error.localizedDescription; return }
        if store.upsert(draft) { dismiss() }
        else { error = store.notice?.message ?? "Не удалось сохранить цель."; store.notice = nil }
    }
}

struct TaskEditor: View {
    @EnvironmentObject var store: DashboardStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft: LifeTask
    @ViewState private var hasDue: Bool
    @ViewState private var due: Date
    @ViewState private var error = ""
    @FocusState private var titleFocused: Bool

    init(task: LifeTask) {
        _draft = State(initialValue: task)
        _hasDue = State(initialValue: task.dueDate != nil)
        _due = State(initialValue: task.dueDate?.date() ?? Date())
    }
    private var isNew: Bool { !store.tasks.contains { $0.id == draft.id } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(isNew ? "Новая задача" : "Редактировать задачу").font(.system(size: 22, weight: .semibold))
            Form {
                TextField("Что нужно сделать", text: $draft.title).focused($titleFocused)
                Picker("Жизненная цель", selection: $draft.goalID) {
                    Text("Без цели").tag(Optional<UUID>.none)
                    ForEach(store.goals) { Text($0.title).tag(Optional($0.id)) }
                }
                Picker("Приоритет", selection: $draft.priority) { ForEach(TaskPriority.allCases) { Text($0.title).tag($0) } }
                Toggle("У задачи есть срок", isOn: $hasDue)
                if hasDue { DatePicker("Сделать до", selection: $due, displayedComponents: .date) }
                if !isNew { Toggle("Выполнена", isOn: $draft.isDone) }
                if let goal = store.goals.first(where: { $0.id == draft.goalID }), goal.mode == .metric {
                    Text("У этой цели числовой показатель. Выполнение задачи не меняет его — обновляйте показатель в самой цели.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                }
            }.formStyle(.grouped).textFieldStyle(.roundedBorder)
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(GreenButton(prominent: false))
                Spacer()
                Button(isNew ? "Добавить задачу" : "Сохранить") { save() }.keyboardShortcut(.defaultAction).buttonStyle(GreenButton())
            }
        }.padding(26).frame(width: 520).tint(Palette.green).onAppear { titleFocused = true }
    }
    private func save() {
        do { draft = try validatedTaskDraft(draft, dueDate: hasDue ? CivilDate(due) : nil) }
        catch { self.error = error.localizedDescription; return }
        if store.upsert(draft) { dismiss() }
        else { error = store.notice?.message ?? "Не удалось сохранить задачу."; store.notice = nil }
    }
}

struct GoalDetailView: View {
    @EnvironmentObject var store: DashboardStore
    @Environment(\.dismiss) private var dismiss
    let goalID: UUID
    var onEdit: (LifeGoal) -> Void
    var onNewTask: () -> Void
    var onEditTask: (LifeTask) -> Void
    @ViewState private var deleting: LifeTask?
    private var goal: LifeGoal? { store.goals.first { $0.id == goalID } }
    private var linked: [LifeTask] { store.tasks.filter { $0.goalID == goalID }.sorted(by: taskOrder) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let goal {
                HStack {
                    Label(goal.area.title, systemImage: goal.area.symbol).foregroundStyle(goal.area.color).font(.system(size: 12))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }.buttonStyle(.plain).help("Закрыть")
                }
                Text(goal.title).font(.system(size: 26, weight: .medium))
                if !goal.details.isEmpty { Text(goal.details).font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(5) }
                Panel {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack { Text(goal.progressDescription(in: store.tasks)); Spacer(); Text("\(Int((goal.progress(in: store.tasks) * 100).rounded()))%" ).fontWeight(.semibold) }.font(.system(size: 13))
                        ProgressView(value: goal.progress(in: store.tasks)).tint(goal.area.color)
                        Label(goal.deadline.map(russianDate) ?? "Без срока", systemImage: "calendar").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                }
                HStack {
                    Button(goal.mode == .metric ? "Обновить показатель" : "Редактировать цель", systemImage: "pencil") { onEdit(goal) }.buttonStyle(GreenButton(prominent: false))
                    Spacer()
                    Button("Добавить шаг", systemImage: "plus", action: onNewTask).buttonStyle(GreenButton())
                }
                SectionHeading(title: "Задачи цели", count: linked.count)
                ScrollView {
                    if linked.isEmpty { EmptyPlaceholder(symbol: "checklist", title: "Первый шаг ещё впереди", message: "Добавьте небольшую задачу, с которой удобно начать.") }
                    else { VStack(spacing: 0) { ForEach(linked) { task in TaskRow(task: task, onEdit: { onEditTask(task) }, onDelete: { deleting = task }); Divider() } } }
                }.frame(maxHeight: 280)
            } else { EmptyPlaceholder(symbol: "scope", title: "Цель удалена", message: "Закройте окно, чтобы вернуться к списку.") }
        }.padding(28).frame(width: 610).tint(Palette.green)
            .confirmationDialog("Удалить задачу?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                if let target = deleting {
                    Button("Удалить", role: .destructive) { store.removeTask(target.id); deleting = nil }
                }
            }
    }
}
