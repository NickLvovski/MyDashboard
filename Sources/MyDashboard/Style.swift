import SwiftUI

// Keep using the property-wrapper API on SDKs whose new State macro plugin
// is not bundled with Command Line Tools.
typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let background = Color(hex: 0xF5F5F0)
    static let green = Color(hex: 0x405C45)
    static let ink = Color(hex: 0x30372E)
    static let muted = Color(hex: 0x87917C)
    static let line = Color(hex: 0xE3E7DB)
    static let soft = Color(hex: 0xEAF0E1)
}
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
extension LifeArea {
    var color: Color {
        switch self {
        case .health: return Color(hex: 0x73966D)
        case .career: return Color(hex: 0x8F80B3)
        case .learning: return Color(hex: 0xC29350)
        case .finances: return Color(hex: 0x6297A1)
        case .personal: return Color(hex: 0xBF8393)
        }
    }
}
struct GreenButton: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 15).padding(.vertical, 11)
            .foregroundStyle(prominent ? Color.white : Palette.green)
            .background(prominent ? Palette.green : Color.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(prominent ? Color.clear : Palette.line))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(21).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line))
    }
}
struct SectionHeading: View {
    var title: String
    var count: Int? = nil
    var action: String? = nil
    var onAction: () -> Void = {}
    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 17, weight: .semibold))
            if let count { Text("\(count)").font(.system(size: 10, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 3).background(Palette.soft, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(Palette.muted) }
            Spacer()
            if let action { Button(action, systemImage: "arrow.right", action: onAction).font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Palette.muted) }
        }
    }
}
struct EmptyPlaceholder: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: () -> Void = {}
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(Palette.muted)
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message).font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(4)
            if let actionTitle { Button(actionTitle, action: action).buttonStyle(GreenButton()).padding(.top, 4) }
        }.padding(32).frame(maxWidth: .infinity)
    }
}
struct StatCard: View {
    let label: String
    let value: String
    let symbol: String
    let footnote: String
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Text(label); Spacer(); Image(systemName: symbol) }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                Text(value).font(.system(size: 30, weight: .medium, design: .rounded)).foregroundStyle(Palette.ink)
                Text(footnote).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(2)
            }
        }
    }
}
struct GoalCard: View {
    let goal: LifeGoal
    let tasks: [LifeTask]
    var onOpen: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var body: some View {
        Button(action: onOpen) {
            Panel {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Image(systemName: goal.area.symbol).font(.system(size: 16)).foregroundStyle(goal.area.color)
                            .frame(width: 34, height: 34).background(goal.area.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        Spacer()
                        Text(goal.area.title).font(.system(size: 9)).foregroundStyle(Palette.muted).padding(.horizontal, 7).padding(.vertical, 4)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.line))
                    }
                    Text(goal.title).font(.system(size: 14, weight: .medium)).lineLimit(2).frame(height: 40, alignment: .topLeading)
                    Text(goal.mode == .tasks ? "Прогресс по задачам" : "Прогресс по показателю").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    Spacer(minLength: 0)
                    HStack {
                        Text(goal.progressDescription(in: tasks)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                        Spacer()
                        Text("\(Int((goal.progress(in: tasks) * 100).rounded()))%" ).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.green)
                    }
                    ProgressView(value: goal.progress(in: tasks)).tint(goal.area.color)
                    Label(goal.deadline.map(russianDate) ?? "Без срока", systemImage: "calendar").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }.frame(height: 196, alignment: .topLeading)
            }
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(goal.title), \(Int(goal.progress(in: tasks) * 100)) процентов")
            .contextMenu {
                Button("Редактировать", systemImage: "pencil", action: onEdit)
                Button("Удалить цель…", systemImage: "trash", role: .destructive, action: onDelete)
            }
    }
}
struct TaskRow: View {
    @EnvironmentObject var store: DashboardStore
    let task: LifeTask
    var onEdit: () -> Void
    var onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button { store.toggle(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle").font(.system(size: 19, weight: .light))
                    .foregroundStyle(task.isDone ? Palette.green : Color(hex: 0xBCC6AF))
                    .frame(width: 26, height: 32)
            }.buttonStyle(.plain).help(task.isDone ? "Вернуть в активные" : "Отметить выполненной")
                .accessibilityLabel("\(task.isDone ? "Вернуть в активные" : "Выполнить"): \(task.title)")
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title).font(.system(size: 12)).strikethrough(task.isDone).foregroundStyle(task.isDone ? Palette.muted : Palette.ink).lineLimit(2)
                    HStack(spacing: 5) {
                        if let goal = store.goal(for: task) {
                            Circle().fill(goal.area.color).frame(width: 5, height: 5)
                            Text(goal.title).lineLimit(1)
                        } else { Text("Без цели") }
                        if task.priority == .high { Text("·"); Text("Важно").foregroundStyle(Color(hex: 0xAC8250)) }
                    }.font(.system(size: 9)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("Редактировать задачу")
            if let due = task.dueDate {
                Text(TaskFilter.today.includes(task) ? "Сегодня" : russianDate(due))
                    .font(.system(size: 10)).foregroundStyle(TaskFilter.overdue.includes(task) ? Color(hex: 0xB77B61) : Palette.muted)
            }
            Menu {
                Button("Редактировать", systemImage: "pencil", action: onEdit)
                Button("Удалить задачу…", systemImage: "trash", role: .destructive, action: onDelete)
            } label: { Image(systemName: "ellipsis").frame(width: 22, height: 24) }.menuStyle(.borderlessButton).fixedSize().foregroundStyle(Palette.muted)
        }.padding(.vertical, 12)
    }
}
