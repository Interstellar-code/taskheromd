# {{ProjectName}}

## 📊 Project Stats
- **Total Tasks:** {{TotalTasks}}
- **✅ Done:** {{DoneCount}}
- **⏳ In Progress:** {{InProgressCount}}
- **📋 Todo:** {{TodoCount}}
- **🎯 Completion Rate:** {{CompletionRate}}%
- **⏱️ Estimated Total Hours:** {{TotalEstimatedHours}}
- **⏱️ Hours Logged:** {{TotalActualHours}}

## 📋 Kanban Board
```mermaid
kanban
    Todo
    {{KanbanTodoTasks}}
    InProgress
    {{KanbanInProgressTasks}}
    Done
    {{KanbanDoneTasks}}
```

## 📝 Task Summary
| ID | Status | Title | Priority | Due Date | Assigned To | Progress |
|----|--------|-------|----------|----------|-------------|----------|
{{TaskSummaryTableRows}}

## 🔗 Task Dependencies
| Task ID | Task Name | Depends On | Required By |
|---------|-----------|------------|-------------|
{{TaskDependenciesTableRows}}

## ⏳ Timeline
```mermaid
timeline
    title Project Timeline
    {{TimelineEntries}}
```

## 🔄 Recent Updates
{{RecentUpdates}}
- {{CurrentDate}} - Plan updated.
