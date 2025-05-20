# SubsHero Task Management System

This folder contains a simple Markdown-based task management system for the SubsHero project.

## 📁 Folder Structure

- `docs/planning/`
  - `plan.md` - Main Kanban board with overview of all tasks
  - `task-template.md` - Template for creating new tasks
  - `todo/` - Tasks that haven't been started yet
  - `inprogress/` - Tasks currently being worked on
  - `done/` - Completed tasks

## 🔄 Workflow

1. **Creating a New Task**
   - Copy the `task-template.md` file
   - Fill in all required information
   - Save it in the `todo/` folder with a filename format: `TASK-XXX-descriptive-name.md`
   - Update the `plan.md` file to include the new task in the TODO section

2. **Starting Work on a Task**
   - Move the task file from `todo/` to `inprogress/`
   - Update the task's Status to "InProgress"
   - Update the `plan.md` file to reflect this change

3. **Completing a Task**
   - Move the task file from `inprogress/` to `done/`
   - Update the task's Status to "Done"
   - Update the task with actual hours spent
   - Add a completion date in the Updates section
   - Update the `plan.md` file to reflect this change

4. **Task Naming Convention**
   - Use the format: `TASK-XXX-descriptive-name.md`
   - Where XXX is a sequential number (001, 002, etc.)
   - The descriptive name should be brief but clear

## 📊 Task Tracking

The `plan.md` file serves as a Kanban board with three columns:
- TODO: Tasks that haven't been started
- IN PROGRESS: Tasks currently being worked on
- DONE: Completed tasks

Each task in the board includes:
- ID
- Title
- Priority
- Due Date
- Assigned To

## 📝 Task Template Fields

The task template combines elements from a standard task template and the implementation plan template:

- **Task ID and Title**: Unique identifier and descriptive name
- **Metadata**: Created date, due date, priority, status, assignee, sequence, tags
- **Overview**: Brief description of the task and its purpose
- **Implementation Status**: Table showing progress of individual steps
- **Detailed Description**: Comprehensive explanation of the task
- **Acceptance Criteria**: Specific requirements that must be met
- **Implementation Steps**: Detailed breakdown of how to complete the task
- **Dependencies**: Other tasks that this task depends on
- **Testing Strategy**: How the implementation will be tested
- **Technical Considerations**: Any technical details or challenges
- **Database Changes**: If applicable, any database schema changes required
- **Time Tracking**: Estimated and actual hours
- **References**: Links to relevant documentation or resources
- **Updates**: Chronological list of updates to the task

## 🔍 Tips for Effective Task Management

1. Keep tasks small and focused
2. Update the plan.md file whenever task statuses change
3. Use consistent formatting for all task files
4. Include detailed acceptance criteria for clarity
5. Track dependencies between tasks
6. Regularly review and update task statuses
7. Use tags to categorize and filter tasks
