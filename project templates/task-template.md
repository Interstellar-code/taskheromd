# Task: TASK-ID - TASK-TITLE

## Metadata
- **Priority:** PRIORITY
- **Due:** DUE-DATE
- **Status:** STATUS
- **Assigned to:** ASSIGNEE
- **Task Type:** TASK-TYPE
- **Sequence:** SEQUENCE
- **Tags:** TAGS

## Description
DESCRIPTION

## Acceptance Criteria
- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Criteria 3

## Time Tracking
- **Estimated hours:** ESTIMATED-HOURS
- **Actual hours:** ACTUAL-HOURS

## Dependencies
### Required By This Task
- None

### Dependent On This Task
- None

## Implementation Steps with Checklists
- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

## 1. Overview
[Brief description of the task and its purpose]

## 2. Flow Diagram
```mermaid
flowchart TD
    A[Start] --> B[Process 1]
    B --> C{Decision}
    C -->|Yes| D[Process 2]
    C -->|No| E[Process 3]
    D --> F[End]
    E --> F
```
[Add description of the flow if needed]

## 3. Implementation Status

| Step | Description | Status | Target Date |
|------|-------------|--------|-------------|
| 1 | [Step description] | ⏳ Pending | YYYY-MM-DD |
| 2 | [Step description] | ⏳ Pending | YYYY-MM-DD |
| 3 | [Step description] | ⏳ Pending | YYYY-MM-DD |

## 4. Detailed Description
[Detailed description of the task, including its purpose, benefits, and any relevant background information]

## 5. Testing
[Describe the testing approach for this task]
- [ ] **5.4.1. Create Test Plan**: Create test plan for task
- [ ] **5.4.2. Implement Tests**: Develop tests

## 6. Dependencies
### 6.1. Required By This Task
- [Task ID] - [Task Title] - [Status]

### 6.2. Dependent On This Task
- [Task ID] - [Task Title] - [Status]

### 6.3. Dependency Type
- **Blocking**: This task cannot start until the dependency is completed
- **Informational**: This task can start but may need information from the dependency
- **Related**: Tasks are related but not directly dependent

## 7. Testing Strategy
Create testing script based on task during testing phase.

## 8. Technical Considerations
[Any technical considerations, potential challenges, or architectural decisions]

### 8.1. Database Changes
[If applicable, describe any database schema changes required]

```mermaid
erDiagram
    %% Replace this with your actual database schema if needed
    TABLE1 ||--o{ TABLE2 : "relationship"
    TABLE1 {
        id int PK
        field1 string
    }
    TABLE2 {
        id int PK
        table1_id int FK
    }
```

## 9. Time Tracking
- **Estimated hours:** [X]
- **Actual hours:** [X]

## 10. References
- [Reference 1]
- [Reference 2]

## 11. Updates
- [YYYY-MM-DD] - [Update description]
