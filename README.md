# Project Planning and Documentation System - Taskheromd

This repository contains a comprehensive Markdown-based project planning and documentation system.

## Project Metadata
- **Last Updated:** 2025-05-22 07:48
- **Total Tasks:** 2
- **Todo Tasks:** 0
- **In Progress Tasks:** 1
- **Done Tasks:** 1
- **Completion Rate:** 50%
- **Estimated Hours:** 13
- **Hours Logged:** 3
- **Last Task:** TASK-002 - Sample In Progress Task

## 📁 Folder Structure

- `project docs/` - Project documentation templates
  - `about.md` - Product context template
  - `db_schema_mermaid.md` - Database schema visualization template
  - `model_relationships.md` - Model relationships template
  - `projectbrief.md` - Project brief template
  - `table_dependencies_analysis.md` - Table dependencies analysis template
  - `techstack.md` - Technical stack documentation template

- `project planning/` - Project planning and task management
  - `todo/` - Tasks that haven't been started yet
  - `inprogress/` - Tasks currently being worked on
  - `done/` - Completed tasks
  - `archive/` - Archived tasks from previous project phases (created automatically when using the reset function)

- `project templates/` - Additional project templates

- `plan.md` - Main Kanban board with overview of all tasks
- `update-plan-consolidated.ps1` - Consolidated PowerShell script with interactive menu for managing tasks
- `update-plan.ps1` - PowerShell script to update the plan.md file
- `update-plan-kanban.ps1` - PowerShell script to update the plan.md file with Kanban format

## 🔄 Project Planning Workflow

1. **Project Documentation**
   - Use the templates in the `project docs/` folder to document your project
   - Customize each template by replacing the placeholder text with your project-specific information
   - Keep documentation up-to-date as the project evolves

2. **Task Management**
   - Create new tasks using the task template in the `project templates/` folder
   - Complete all required metadata fields, including the Task Type
   - Save new tasks in the `project planning/todo/` folder with the filename format: `TASK-XXX-[TYPE]-descriptive-name.md`
   - Update the `plan.md` file to include the new task in the TODO section
   - Use the PowerShell scripts to automatically update the plan.md file

3. **Task Progression**
   - Move tasks between folders (`todo/` → `inprogress/` → `done/`) as they progress
   - Update each task's status and details as work progresses
   - Run the consolidated script to keep the main plan.md file in sync with the task files
   - Use the reset option when you want to archive all tasks and start fresh

4. **Task Naming Convention**
   - Use the format: `TASK-XXX-[TYPE]-descriptive-name.md`
   - Where:
     - XXX is a sequential number (001, 002, etc.)
     - [TYPE] is the task type abbreviation (DEV, BUG, TEST, DOC, etc.)
     - descriptive-name should be brief but clear
   - Examples:
     - `TASK-001-DEV-user-authentication.md`
     - `TASK-002-BUG-login-validation-error.md`
     - `TASK-003-TEST-payment-gateway.md`
   
   > **Note:** The task type abbreviation in the filename should match the Task Type field in the metadata section. For example, a task with filename `TASK-001-DEV-feature.md` should have `Task Type: Development` in its metadata. The standard abbreviations are:
   > - DEV = Development
   > - BUG = Bug
   > - TEST = Test Case
   > - DOC = Documentation
   > - DES = Design

## 📊 Project Management Tools

### Kanban Board
The `plan.md` file serves as a Kanban board with three columns:
- TODO: Tasks that haven't been started
- IN PROGRESS: Tasks currently being worked on
- DONE: Completed tasks

Each task in the board includes:
- ID and Title
- Task Type (displayed in parentheses after the title, e.g., "Task Title (Development)")
- Priority
- Due Date
- Assigned To
- Progress percentage

The task type is displayed directly after the task title for immediate visual identification, making it easier to quickly scan and categorize tasks by their type.

The Kanban board is visualized using Mermaid's Kanban syntax, which displays all task details in a single card for better readability. The board is color-coded:
- Todo tasks: Light red
- In Progress tasks: Light blue
- Done tasks: Light green

### Task Type Classification
The Task Type field allows you to categorize tasks by their nature:

- **Development**: Tasks related to implementing new features or functionality
- **Bug**: Tasks focused on fixing issues or defects
- **Test Case**: Tasks dedicated to creating or running tests
- **Documentation**: Tasks for creating or updating documentation
- **Design**: Tasks involving UI/UX design or architecture design

Using Task Types helps team members quickly identify the nature of work required and can be used to filter and prioritize tasks based on the current project phase.

#### Filtering by Task Type
You can use the PowerShell script's list tasks functionality to filter tasks by task type using the tags field, since task types are included in the task metadata:

```powershell
# Example: List all bug tasks
.\update-plan-consolidated.ps1 -Silent -ListTasks -AssignedTo "" | Where-Object { $_.TaskType -eq "Bug" }

# Example: List all development tasks in progress
.\update-plan-consolidated.ps1 -Silent -ListTasks -TaskStatus "inprogress" | Where-Object { $_.TaskType -eq "Development" }
```

This filtering capability allows teams to focus on specific types of work during different project phases or for specialized team members to quickly identify relevant tasks.

### Automation Scripts
The PowerShell scripts automate the maintenance of the plan.md file:

#### Consolidated Script (Recommended)
- `update-plan-consolidated.ps1` - All-in-one script with interactive menu and silent mode options:
  - Update plan.md with current task statuses
  - Generate project status reports
  - Generate comprehensive project plan reports with detailed visualizations
  - List tasks (all, by status, by assignee)
  - Reset project by archiving all tasks

  **Usage:**
  - Interactive mode: `.\update-plan-consolidated.ps1`
  - Silent mode examples:
    - Update plan: `.\update-plan-consolidated.ps1 -Silent -UpdatePlan`
    - Generate status report: `.\update-plan-consolidated.ps1 -Silent -GenerateReport -ReportPath "custom-report.md"`
    - Generate comprehensive plan report: `.\update-plan-consolidated.ps1 -Silent -GenerateComprehensiveReport -ComprehensiveReportPath "custom-plan-report.md"`
    - List tasks: `.\update-plan-consolidated.ps1 -Silent -ListTasks -TaskStatus "todo" -AssignedTo "John"`
    - Reset project: `.\update-plan-consolidated.ps1 -Silent -ResetTasks`

#### Legacy Scripts
- `update-plan.ps1` - Updates the plan.md file based on task files in the folders
- `update-plan-kanban.ps1` - Updates the plan.md file with a Kanban board format

## 📝 Documentation Templates

### Project Documentation Templates
The `project docs/` folder contains templates for comprehensive project documentation:

- **about.md**: Product context template
  - Why the product exists
  - Vision statement
  - Problems solved
  - User experience goals
  - Target users
  - Key user journeys
  - Success metrics

- **db_schema_mermaid.md**: Database schema visualization template
  - Entity-relationship diagrams using Mermaid
  - Table definitions and relationships
  - Database schema evolution

- **model_relationships.md**: Model relationships template
  - Object relationships diagrams
  - Implementation examples
  - Naming conventions

- **projectbrief.md**: Project brief template
  - Vision and mission
  - Requirements and goals
  - Project scope and boundaries
  - Development focus and priorities

- **table_dependencies_analysis.md**: Table dependencies analysis template
  - Database table dependency levels
  - Migration order
  - Foreign key constraints

- **techstack.md**: Technical stack documentation template
  - Frontend and backend technologies
  - Development environment
  - Technical constraints
  - Performance optimization patterns

These project documentation templates can be updated using AI agents for your project.

### Task Template Fields
The task template includes:

- **Task ID and Title**: Unique identifier and descriptive name
- **Metadata**: Created date, due date, priority, status, assignee, task type, sequence, tags
- **Overview**: Brief description of the task and its purpose
- **Implementation Status**: Table showing progress of individual steps
- **Detailed Description**: Comprehensive explanation of the task
- **Acceptance Criteria**: Specific requirements that must be met
- **Implementation Steps**: Detailed breakdown of how to complete the task
- **Dependencies**: Other tasks that this task depends on
- **Testing Strategy**: How the implementation will be tested (automated tests only)
- **Technical Considerations**: Any technical details or challenges
- **Database Changes**: If applicable, any database schema changes required
- **Time Tracking**: Estimated and actual hours
- **References**: Links to relevant documentation or resources
- **Updates**: Chronological list of updates to the task

## 🔍 Tips for Effective Project Management

1. **Documentation First**: Start with comprehensive project documentation using the templates
2. **Keep Tasks Small**: Break down work into small, focused tasks
3. **Automate Updates**: Use the consolidated script to keep the plan.md file in sync and generate reports
4. **Consistent Formatting**: Follow the templates for all documentation and task files
5. **Clear Criteria**: Include detailed acceptance criteria for all tasks
6. **Track Dependencies**: Document and monitor dependencies between tasks
7. **Regular Reviews**: Periodically review and update documentation and task statuses
8. **Use Tags**: Categorize tasks with tags for better organization and filtering
9. **Evolve Documentation**: Update project documentation as the project evolves
10. **Archive Regularly**: Use the reset function to archive completed project phases
11. **Customize Templates**: Adapt the templates to fit your specific project needs

## 📚 Getting Started

1. **Set Up Documentation**:
   - Copy and customize the templates in `project docs/` for your project
   - Replace all placeholder text with your project-specific information

2. **Create Your Task Structure**:
   - Set up your task template in `project templates/`
   - Create initial tasks in `project planning/todo/`
   - Run the consolidated script (`.\update-plan-consolidated.ps1`) to generate your initial plan.md

3. **Start Working**:
   - Begin working on tasks according to priority
   - Move tasks through the workflow as they progress
   - Use the consolidated script to manage tasks, generate reports, and keep plan.md updated
   - Archive completed project phases using the reset function when needed

This project planning and documentation system is designed to be flexible and adaptable to different types of projects. Feel free to modify it to better suit your specific needs.
