# {{ProjectName}}

## 📊 Project Stats
- **Total Tasks:** {{TotalTasks}}
- **✅ Done:** {{DoneCount}}
- **🧪 Testing:** {{TestingCount}}
- **🔄 Dev Done:** {{DevDoneCount}}
- **⏳ In Progress:** {{InProgressCount}}
- **📋 Todo:** {{TodoCount}}
- **📊 Backlog:** {{BacklogCount}}
- **🎯 Completion Rate:** {{CompletionRate}}%
- **⏱️ Estimated Total Hours:** {{TotalEstimatedHours}}
- **⏱️ Hours Logged:** {{TotalActualHours}}

## 📋 Kanban Board
```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://project.atlassian.net/browse/#TICKET#'
---
kanban
  [Backlog]
    {{KanbanBacklogTasks}}
  Todo
    {{KanbanTodoTasks}}
  [In Progress]
    {{KanbanInProgressTasks}}
  [Dev Done]
    {{KanbanDevDoneTasks}}
  [Testing]
    {{KanbanTestingTasks}}
  [Done]
    {{KanbanDoneTasks}}
```

## 📝 Task Summary
| ID | Status | Title | Type | Priority | Due Date | Assigned To | Progress |
|----|--------|-------|------|----------|----------|-------------|----------|
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
