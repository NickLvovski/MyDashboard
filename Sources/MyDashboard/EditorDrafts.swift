import Foundation

/// The same validation and conversion used by the native editors, without UI or I/O.
func validatedGoalDraft(_ source: LifeGoal, currentText: String, targetText: String,
                        deadline: CivilDate?) throws -> LifeGoal {
    var draft = source
    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !draft.title.isEmpty, draft.title.count <= 140 else {
        throw DataError.invalid("Введите название до 140 символов.")
    }
    guard draft.details.count <= 2000, draft.unit.count <= 30 else {
        throw DataError.invalid("Описание — до 2000 символов, единица измерения — до 30.")
    }
    if draft.mode == .metric {
        guard let current = parseNumber(currentText), current.isFinite, current >= 0,
              let target = parseNumber(targetText), target.isFinite, target > 0 else {
            throw DataError.invalid("Текущее значение должно быть неотрицательным числом, а целевое — больше нуля.")
        }
        draft.current = current; draft.target = target
    } else { draft.current = 0; draft.target = 1; draft.unit = "" }
    draft.deadline = deadline
    return draft
}

func validatedTaskDraft(_ source: LifeTask, dueDate: CivilDate?, now: Date = Date()) throws -> LifeTask {
    var draft = source
    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !draft.title.isEmpty, draft.title.count <= 240 else {
        throw DataError.invalid("Введите название задачи до 240 символов.")
    }
    draft.dueDate = dueDate
    draft.completedAt = draft.isDone ? (draft.completedAt ?? now) : nil
    return draft
}
