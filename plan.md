# Project Plan

## 📊 Project Stats
- **Total Tasks:** 2
- **✅ Done:** 1
- **⏳ In Progress:** 1
- **📋 Todo:** 0
- **🎯 Completion Rate:** 50%
- **⏱️ Estimated Total Hours:** 13
- **⏱️ Hours Logged:** 3

## 📋 Kanban Board
```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://project.atlassian.net/browse/#TICKET#'
---
kanban
  Todo
    
  [In Progress]
        task-001[TASK-001 - Sample Task for Testing]@{ priority: 'High', assigned: 'Developer', type: 'Development', due: '2025-06-01' }
  [Done]
        task-002[TASK-002 - Sample In Progress Task]@{ priority: 'Medium', assigned: 'Developer', type: 'Bug', due: '2025-06-05' }
```

## 📝 Task Summary
| ID | Status | Title | Type | Priority | Due Date | Assigned To | Progress |
|----|--------|-------|------|----------|----------|-------------|----------|
| TASK-001 | In Progress | Sample Task for Testing | Development | High | 2025-06-01 | Developer | 0% |
| TASK-002 | Done | Sample In Progress Task | Bug | Medium | 2025-06-05 | Developer | 100% |

## 🔗 Task Dependencies
| Task ID | Task Name | Depends On | Required By |
|---------|-----------|------------|-------------|
| TASK-001 | Sample Task for Testing |  |  |
| TASK-002 | Sample In Progress Task |  |  |

## ⏳ Timeline
```mermaid
timeline
    title Project Timeline
        section 2025
        May : TASK-002 - Sample In Progress Task (Done)
               : TASK-001 - Sample Task for Testing (In Progress)
```

## 🔄 Recent Updates

- 2025-05-22 - Plan updated.
