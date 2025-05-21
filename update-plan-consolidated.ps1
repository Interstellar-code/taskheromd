# Project Planning Management - Consolidated Script
# This script combines plan.md updating and reporting functionality with interactive and silent modes

param (
    [switch]$Silent,
    [switch]$UpdatePlan,
    [switch]$GenerateReport,
    [switch]$ListTasks,
    [switch]$ResetTasks,
    [string]$TaskStatus = "all",
    [string]$AssignedTo = "",
    [string]$ReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md",
    [switch]$GenerateComprehensiveReport,
    [string]$ComprehensiveReportPath = "project-comprehensive-report-$(Get-Date -Format 'yyyy-MM-dd').md"
)

# Define constants
$TaskStatusTodo = "Todo"
$TaskStatusInProgress = "InProgress"
$TaskStatusDone = "Done"

# Function to calculate task progress based on acceptance criteria
function Get-TaskProgress {
    param (
        [string]$Content # Raw content of the task file
    )
    $TotalCriteria = 0
    $CompletedCriteria = 0

    # Extract acceptance criteria section
    if ($Content -match "## Acceptance Criteria\r?\n((?:- \[[ x]\].*\r?\n)+)") {
        $CriteriaSection = $matches[1]
        $CriteriaLines = $CriteriaSection -split "\r?\n" | Where-Object { $_ -match "- \[[ x]\]" }

        $TotalCriteria = $CriteriaLines.Count
        $CompletedCriteria = ($CriteriaLines | Where-Object { $_ -match "- \[x\]" }).Count
    }

    # Also check subtasks checklist if present
    if ($Content -match "## Subtasks Checklist\r?\n((?:- \[[ x]\].*\r?\n)+)") {
        $ChecklistSection = $matches[1]
        $ChecklistLines = $ChecklistSection -split "\r?\n" | Where-Object { $_ -match "- \[[ x]\]" }

        $TotalCriteria += $ChecklistLines.Count
        $CompletedCriteria += ($ChecklistLines | Where-Object { $_ -match "- \[x\]" }).Count
    }

    if ($TotalCriteria -eq 0) {
        return 0
    }

    return [math]::Round(($CompletedCriteria / $TotalCriteria) * 100)
}

# Function to get task dependencies
function Get-TaskDependencies {
    param (
        [string]$Content # Raw content of the task file
    )
    $RequiredBy = @()
    $DependsOn = @()

    # Extract "Required By This Task" section
    if ($Content -match "### Required By This Task\r?\n((?:- .*\r?\n)+)") {
        $RequiredBySection = $matches[1]
        $RequiredByLines = $RequiredBySection -split "\r?\n" | Where-Object { $_ -match "- " }

        foreach ($Line in $RequiredByLines) {
            if ($Line -match "- (TASK-\d+)") {
                $RequiredBy += $matches[1]
            }
        }
    }

    # Extract "Dependent On This Task" section
    if ($Content -match "### Dependent On This Task\r?\n((?:- .*\r?\n)+)") {
        $DependentOnSection = $matches[1]
        $DependentOnLines = $DependentOnSection -split "\r?\n" | Where-Object { $_ -match "- " }

        foreach ($Line in $DependentOnLines) {
            if ($Line -match "- (TASK-\d+)") {
                $DependsOn += $matches[1]
            }
        }
    }

    return @{
        RequiredBy = $RequiredBy
        DependsOn = $DependsOn
    }
}

# Function to get task metadata
function Get-TaskMetadata {
    param (
        [string]$Content # Raw content of the task file
    )
    $Metadata = @{}

    # Extract task ID and title
    if ($Content -match "# Task: (TASK-\d+) - (.+)") {
        $Metadata.ID = $matches[1]
        $Metadata.Title = $matches[2]
    }

    # Extract metadata section
    if ($Content -match "## Metadata\r?\n((?:- \*\*.*\r?\n)+)") {
        $MetadataSection = $matches[1]

        # Extract priority
        if ($MetadataSection -match "- \*\*Priority:\*\* (.+)") {
            $Metadata.Priority = $matches[1]
        }

        # Extract due date
        if ($MetadataSection -match "- \*\*Due:\*\* (.+)") {
            $Metadata.DueDate = $matches[1]
        }

        # Extract status
        if ($MetadataSection -match "- \*\*Status:\*\* (.+)") {
            $Metadata.Status = $matches[1]
        }

        # Extract assigned to
        if ($MetadataSection -match "- \*\*Assigned to:\*\* (.+)") {
            $Metadata.AssignedTo = $matches[1]
        }

        # Extract sequence
        if ($MetadataSection -match "- \*\*Sequence:\*\* (.+)") {
            $Metadata.Sequence = $matches[1]
        }

        # Extract tags
        if ($MetadataSection -match "- \*\*Tags:\*\* (.+)") {
            $Metadata.Tags = $matches[1]
        }
    }

    # Extract time tracking
    if ($Content -match "## Time Tracking\r?\n- \*\*Estimated hours:\*\* (\d+)") {
        $Metadata.EstimatedHours = [int]$matches[1]
    }

    if ($Content -match "## Time Tracking\r?\n- \*\*Estimated hours:\*\* \d+\r?\n- \*\*Actual hours:\*\* (\d+)") {
        $Metadata.ActualHours = [int]$matches[1]
    }
    elseif ($Content -match "## Time Tracking\r?\n- \*\*Estimated hours:\*\* \d+\r?\n- \*\*Actual hours:\*\* (\d+) \(in progress\)") {
        $Metadata.ActualHours = [int]$matches[1]
    }
    else {
        $Metadata.ActualHours = 0
    }

    return $Metadata
}

# Function to initialize required folders
function Initialize-RequiredFolders {
    $ProjectPlanningPath = "project planning"
    $TodoPath = "project planning/todo"
    $InProgressPath = "project planning/inprogress"
    $DonePath = "project planning/done"
    $ArchivePath = "project planning/archive"
    $TemplatesPath = "project templates"
    $DocsPath = "project docs"

    # Create folders if they don't exist
    $Folders = @($ProjectPlanningPath, $TodoPath, $InProgressPath, $DonePath, $ArchivePath, $TemplatesPath, $DocsPath)

    foreach ($Folder in $Folders) {
        if (-not (Test-Path -Path $Folder)) {
            try {
                New-Item -Path $Folder -ItemType Directory -Force | Out-Null
                if (-not $Silent) {
                    Write-Host "Created folder: $Folder" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Failed to create folder $($Folder): $($_.Exception.Message)"
            }
        }
    }
}

# Function to get all tasks
function Get-AllTasks {
    # Initialize required folders
    Initialize-RequiredFolders

    $TodoPath = "project planning/todo"
    $InProgressPath = "project planning/inprogress"
    $DonePath = "project planning/done"

    $TodoTasks = if (Test-Path $TodoPath) { Get-ChildItem -Path $TodoPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $InProgressTasks = if (Test-Path $InProgressPath) { Get-ChildItem -Path $InProgressPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $DoneTasks = if (Test-Path $DonePath) { Get-ChildItem -Path $DonePath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }

    $AllTasks = @()
    $TotalEstimatedHours = 0
    $TotalActualHours = 0

    # Process todo tasks
    foreach ($Task in $TodoTasks) {
        try {
            $TaskContent = Get-Content -Path $Task.FullName -Raw -ErrorAction Stop
            $Metadata = Get-TaskMetadata -Content $TaskContent
            $Progress = Get-TaskProgress -Content $TaskContent
            $Dependencies = Get-TaskDependencies -Content $TaskContent
        }
        catch {
            Write-Warning "Could not read task file $($Task.FullName): $($_.Exception.Message)"
            continue # Skip to next task
        }

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = $TaskStatusTodo
            AssignedTo = $Metadata.AssignedTo
            Sequence = $Metadata.Sequence
            Tags = $Metadata.Tags
            Progress = $Progress
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
            RequiredBy = $Dependencies.RequiredBy -join ", "
            DependsOn = $Dependencies.DependsOn -join ", "
            FilePath = $Task.FullName
        }

        $AllTasks += $TaskInfo
        $TotalEstimatedHours += $Metadata.EstimatedHours
        $TotalActualHours += $Metadata.ActualHours
    }

    # Process in progress tasks
    foreach ($Task in $InProgressTasks) {
        try {
            $TaskContent = Get-Content -Path $Task.FullName -Raw -ErrorAction Stop
            $Metadata = Get-TaskMetadata -Content $TaskContent
            $Progress = Get-TaskProgress -Content $TaskContent
            $Dependencies = Get-TaskDependencies -Content $TaskContent
        }
        catch {
            Write-Warning "Could not read task file $($Task.FullName): $($_.Exception.Message)"
            continue # Skip to next task
        }

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = $TaskStatusInProgress
            AssignedTo = $Metadata.AssignedTo
            Sequence = $Metadata.Sequence
            Tags = $Metadata.Tags
            Progress = $Progress
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
            RequiredBy = $Dependencies.RequiredBy -join ", "
            DependsOn = $Dependencies.DependsOn -join ", "
            FilePath = $Task.FullName
        }

        $AllTasks += $TaskInfo
        $TotalEstimatedHours += $Metadata.EstimatedHours
        $TotalActualHours += $Metadata.ActualHours
    }

    # Process done tasks
    foreach ($Task in $DoneTasks) {
        try {
            $TaskContent = Get-Content -Path $Task.FullName -Raw -ErrorAction Stop
            $Metadata = Get-TaskMetadata -Content $TaskContent
            $Dependencies = Get-TaskDependencies -Content $TaskContent
        }
        catch {
            Write-Warning "Could not read task file $($Task.FullName): $($_.Exception.Message)"
            continue # Skip to next task
        }

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = $TaskStatusDone
            AssignedTo = $Metadata.AssignedTo
            Sequence = $Metadata.Sequence
            Tags = $Metadata.Tags
            Progress = 100
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
            RequiredBy = $Dependencies.RequiredBy -join ", "
            DependsOn = $Dependencies.DependsOn -join ", "
            FilePath = $Task.FullName
        }

        $AllTasks += $TaskInfo
        $TotalEstimatedHours += $Metadata.EstimatedHours
        $TotalActualHours += $Metadata.ActualHours
    }

    return @{
        Tasks = $AllTasks
        TotalEstimatedHours = $TotalEstimatedHours
        TotalActualHours = $TotalActualHours
    }
}

# Function to update plan.md
function Get-ProjectStats {
    param (
        [array]$AllTasks
    )

    $TotalTasks = $AllTasks.Count
    $TodoCount = ($AllTasks | Where-Object { $_.Status -eq $TaskStatusTodo }).Count
    $InProgressCount = ($AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress }).Count
    $DoneCount = ($AllTasks | Where-Object { $_.Status -eq $TaskStatusDone }).Count
    $CompletionRate = if ($TotalTasks -gt 0) { [math]::Round(($DoneCount / $TotalTasks) * 100) } else { 0 }
    $TotalEstimatedHours = 0
    $TotalActualHours = 0

    foreach ($Task in $AllTasks) {
        if ($null -ne $Task.EstimatedHours) {
            $TotalEstimatedHours += $Task.EstimatedHours
        }
        if ($null -ne $Task.ActualHours) {
            $TotalActualHours += $Task.ActualHours
        }
    }

    return @{
        TotalTasks = $TotalTasks
        TodoCount = $TodoCount
        InProgressCount = $InProgressCount
        DoneCount = $DoneCount
        CompletionRate = $CompletionRate
        TotalEstimatedHours = $TotalEstimatedHours
        TotalActualHours = $TotalActualHours
    }
}

function Update-PlanFile {
    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks
    $ProjectStats = Get-ProjectStats -AllTasks $AllTasks
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"

    # Check if plan.md exists and has content
    $PlanExists = Test-Path -Path "plan.md"
    $PlanHasContent = $false

    if ($PlanExists) {
        try {
            $ExistingContent = Get-Content -Path "plan.md" -Raw -ErrorAction Stop
            $PlanHasContent = ($ExistingContent -and $ExistingContent.Trim().Length -gt 0)
        }
        catch {
            $PlanHasContent = $false
        }
    }

    # If plan.md doesn't exist or is empty, create a new one
    if (-not $PlanExists -or -not $PlanHasContent) {
        $ProjectName = "Project Plan"

        # Create a complete template with all necessary sections
        $NewPlanContent = @"
# $ProjectName

## 📋 Overview
This document tracks all tasks for the project using a Kanban-style approach with dependency tracking.

## 📊 Project Stats
- **Total Tasks:** $($ProjectStats.TotalTasks)
- **Todo:** $($ProjectStats.TodoCount)
- **In Progress:** $($ProjectStats.InProgressCount)
- **Done:** $($ProjectStats.DoneCount)
- **Completion Rate:** $($ProjectStats.CompletionRate)%
- **Estimated Total Hours:** $($ProjectStats.TotalEstimatedHours)
- **Hours Logged:** $($ProjectStats.TotalActualHours)

## 🔄 Workflow
1. New tasks are created using the task template and placed in the `todo` folder
2. When work begins on a task, move it to the `inprogress` folder
3. When a task is completed, move it to the `done` folder
4. Update this plan.md file to reflect the current state of all tasks
5. Update dependency information in related tasks

## 📝 Task Template
The task template (`project templates/task-template.md`) combines elements from a standard task template and the implementation plan template. It includes:

- **Metadata**: Basic task information (ID, title, dates, priority, status, etc.)
- **Implementation Status**: Table showing progress of individual steps
- **Detailed Description**: Comprehensive explanation of the task
- **Acceptance Criteria**: Checklist of requirements for completion
- **Implementation Steps**: Detailed breakdown of how to complete the task
- **Dependencies**: Tasks that this task depends on and tasks that depend on this task
- **Testing Strategy**: How the implementation will be tested
- **Technical Considerations**: Any technical details or challenges
- **Time Tracking**: Estimated and actual hours spent

Use this template for all new tasks to ensure consistency and completeness.

## 📊 Dependency Graph

```mermaid
graph TD
    classDef todo fill:#ff9999;
    classDef inprogress fill:#99ccff;
    classDef done fill:#99ff99;
```

## 📅 Timeline

```mermaid
timeline
    title Project Timeline
```

## 🔄 Task Dependencies

| Task ID | Task Name | Depends On | Required By |
|---------|-----------|------------|------------|

## 📋 Kanban Board

```mermaid
---
displayMode: compact
---
%%{
  init: {
    'theme': 'default',
    'themeVariables': {
      'cDoneColor': '#d0f0c0',
      'cInProgressColor': '#b0e0e6',
      'cToDoColor': '#ffe4e1'
    }
  }
}%%

kanban
    Todo
    In Progress
    Done
```

## 📊 Task Summary

| ID | Status | Title | Priority | Due Date | Assigned To | Progress |
|----|--------|-------|----------|----------|-------------|----------|

## 📅 Recent Updates

- $CurrentDate - Initial project plan created
"@

        # Save the new plan.md file
        try {
            Set-Content -Path "plan.md" -Value $NewPlanContent -ErrorAction Stop

            if (-not $Silent) {
                Write-Host "Created new plan.md file with template structure" -ForegroundColor Green
            }

            # Set the content for further processing
            $PlanContent = $NewPlanContent
        }
        catch {
            Write-Error "Failed to create plan.md file: $($_.Exception.Message)"
            return $false
        }
    }
    else {
        # Read the existing plan.md file
        try {
            $PlanContent = Get-Content -Path "plan.md" -Raw -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to read plan.md file: $($_.Exception.Message)"
            return $false
        }
    }

    # Update project stats
    $StatsPattern = '## 📊 Project Stats[\s\S]*?- \*\*Hours Logged:\*\* \d+'
    $StatsReplacement = @"
## 📊 Project Stats
- **Total Tasks:** $($ProjectStats.TotalTasks)
- **Todo:** $($ProjectStats.TodoCount)
- **In Progress:** $($ProjectStats.InProgressCount)
- **Done:** $($ProjectStats.DoneCount)
- **Completion Rate:** $($ProjectStats.CompletionRate)%
- **Estimated Total Hours:** $($ProjectStats.TotalEstimatedHours)
- **Hours Logged:** $($ProjectStats.TotalActualHours)
"@

    $PlanContent = $PlanContent -replace $StatsPattern, $StatsReplacement

    # Create Kanban board using proper Mermaid Kanban syntax
    $KanbanMermaid = @'
```mermaid
---
displayMode: compact
---
%%{
  init: {
    'theme': 'default',
    'themeVariables': {
      'cDoneColor': '#d0f0c0',
      'cInProgressColor': '#b0e0e6',
      'cToDoColor': '#ffe4e1'
    }
  }
}%%

kanban
'@

    # Add Todo tasks
    $KanbanMermaid += "    Todo`n"
    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq $TaskStatusTodo } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "        $($Task.ID): $($Task.Title)<br>Priority: $($Task.Priority)<br>Due: $($Task.DueDate)<br>Assigned: $($Task.AssignedTo)<br>Progress: $($Task.Progress)%`n"
    }

    # Add In Progress tasks
    $KanbanMermaid += "    In Progress`n"
    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "        $($Task.ID): $($Task.Title)<br>Priority: $($Task.Priority)<br>Due: $($Task.DueDate)<br>Assigned: $($Task.AssignedTo)<br>Progress: $($Task.Progress)%`n"
    }

    # Add Done tasks
    $KanbanMermaid += "    Done`n"
    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq $TaskStatusDone } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "        $($Task.ID): $($Task.Title)<br>Priority: $($Task.Priority)<br>Due: $($Task.DueDate)<br>Assigned: $($Task.AssignedTo)<br>Progress: $($Task.Progress)%`n"
    }

    $KanbanMermaid += '```'

    # Create task summary table
    $TaskSummaryTable = @"
| ID | Status | Title | Priority | Due Date | Assigned To | Progress |
|----|--------|-------|----------|----------|-------------|----------|
"@

    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $StatusIcon = switch ($Task.Status) {
            $TaskStatusTodo { "(Todo)" }
            $TaskStatusInProgress { "(In Progress)" }
            $TaskStatusDone { "(Done)" }
            default { "(Unknown)" }
        }

        $TaskSummaryTable += "`n| $($Task.ID) | $StatusIcon | $($Task.Title) | $($Task.Priority) | $($Task.DueDate) | $($Task.AssignedTo) | $($Task.Progress)% |"
    }

    # Update Kanban board and task summary in plan.md
    $KanbanPattern = '## 📋 Kanban Board[\s\S]*?## 📊 Task Summary[\s\S]*?\| ID \| Status \| Title \| Priority \| Due Date \| Assigned To \| Progress \|[\s\S]*?(?=##)'

    $KanbanReplacement = @"
## 📋 Kanban Board

$KanbanMermaid

## 📊 Task Summary

$TaskSummaryTable

"@

    $PlanContent = $PlanContent -replace $KanbanPattern, $KanbanReplacement

    # Update task dependencies table
    $DependenciesTable = @"
| Task ID | Task Name | Depends On | Required By |
|---------|-----------|------------|------------|

"@
    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $DependenciesTable = $DependenciesTable.TrimEnd() + "`n| $($Task.ID) | $($Task.Title) | $($Task.DependsOn) | $($Task.RequiredBy) |"
    }
    $DependenciesTable += "`n"

    $DependenciesPattern = '## 🔄 Task Dependencies[\s\S]*?\| Task ID \| Task Name \| Depends On \| Required By \|[\s\S]*?(?=##)'
    $DependenciesReplacement = @"
## 🔄 Task Dependencies

$DependenciesTable

"@

    $PlanContent = $PlanContent -replace $DependenciesPattern, $DependenciesReplacement

    # Update Timeline (using Mermaid timeline syntax)
    $TimelineMermaid = @'
```mermaid
timeline
    title Project Timeline

'@

    # Group tasks by month based on due date
    $TasksByMonth = @{}
    $CurrentYear = (Get-Date).Year

    foreach ($Task in $AllTasks) {
        $DueDateObj = $null
        $Year = $CurrentYear
        $Month = "Unknown"

        # Try to parse the due date
        try {
            if ($Task.DueDate -and [DateTime]::TryParse($Task.DueDate, [ref]$DueDateObj)) {
                $Year = $DueDateObj.Year
                $Month = $DueDateObj.ToString("MMMM")
            } else {
                # If parsing fails, use current month
                $Month = (Get-Date).ToString("MMMM")
            }
        } catch {
            # If parsing fails, use current month
            $Month = (Get-Date).ToString("MMMM")
        }

        # Create year section if it doesn't exist
        if (-not $TasksByMonth.ContainsKey($Year)) {
            $TasksByMonth[$Year] = @{}
        }

        # Create month section if it doesn't exist
        if (-not $TasksByMonth[$Year].ContainsKey($Month)) {
            $TasksByMonth[$Year][$Month] = @()
        }

        # Add task to the appropriate month
        $TasksByMonth[$Year][$Month] += $Task
    }

    # Add sections and tasks to the timeline
    foreach ($Year in $TasksByMonth.Keys | Sort-Object) {
        $TimelineMermaid += "    section $Year`n"

        foreach ($Month in $TasksByMonth[$Year].Keys | ForEach-Object {
            # Convert month names to numbers for sorting
            $MonthNumber = switch ($_) {
                "January" { "01" }
                "February" { "02" }
                "March" { "03" }
                "April" { "04" }
                "May" { "05" }
                "June" { "06" }
                "July" { "07" }
                "August" { "08" }
                "September" { "09" }
                "October" { "10" }
                "November" { "11" }
                "December" { "12" }
                default { "13" } # Unknown months at the end
            }
            [PSCustomObject]@{ Name = $_; SortOrder = $MonthNumber }
        } | Sort-Object -Property SortOrder | Select-Object -ExpandProperty Name) {

            # First task in the month gets the month name
            $FirstTask = $true

            # Group tasks by status for better organization
            $DoneTasks = $TasksByMonth[$Year][$Month] | Where-Object { $_.Status -eq $TaskStatusDone }
            $InProgressTasks = $TasksByMonth[$Year][$Month] | Where-Object { $_.Status -eq $TaskStatusInProgress }
            $TodoTasks = $TasksByMonth[$Year][$Month] | Where-Object { $_.Status -eq $TaskStatusTodo }

            # Process done tasks first
            foreach ($Task in $DoneTasks) {
                if ($FirstTask) {
                    $TimelineMermaid += "        $Month : $($Task.ID): $($Task.Title) (Done)`n"
                    $FirstTask = $false
                } else {
                    $TimelineMermaid += "                 : $($Task.ID): $($Task.Title) (Done)`n"
                }
            }

            # Then in-progress tasks
            foreach ($Task in $InProgressTasks) {
                if ($FirstTask) {
                    $TimelineMermaid += "        $Month : $($Task.ID): $($Task.Title) (In Progress)`n"
                    $FirstTask = $false
                } else {
                    $TimelineMermaid += "                 : $($Task.ID): $($Task.Title) (In Progress)`n"
                }
            }

            # Finally todo tasks
            foreach ($Task in $TodoTasks) {
                if ($FirstTask) {
                    $TimelineMermaid += "        $Month : $($Task.ID): $($Task.Title) (Todo)`n"
                    $FirstTask = $false
                } else {
                    $TimelineMermaid += "                 : $($Task.ID): $($Task.Title) (Todo)`n"
                }
            }
        }
    }

    $TimelineMermaid += '```'

    # Update Timeline in plan.md
    $TimelinePattern = '## 📅 Timeline[\s\S]*?```mermaid[\s\S]*?```'
    $TimelineReplacement = @"
## 📅 Timeline

$TimelineMermaid
"@

    $PlanContent = $PlanContent -replace $TimelinePattern, $TimelineReplacement

    # Update recent updates
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"
    $UpdatesPattern = '## 📅 Recent Updates[\s\S]*?(?=##|$)'
    $UpdatesMatch = [regex]::Match($PlanContent, $UpdatesPattern).Value
    $NewUpdate = "- $CurrentDate - Updated plan.md with latest task statuses"

    if ($UpdatesMatch -notmatch [regex]::Escape($NewUpdate)) {
        $UpdatesReplacement = $UpdatesMatch -replace '(## 📅 Recent Updates\r?\n)', "`$1`n$NewUpdate`n"
        $PlanContent = $PlanContent -replace [regex]::Escape($UpdatesMatch), $UpdatesReplacement
    }

    # Save updated plan.md
    try {
        Set-Content -Path "plan.md" -Value $PlanContent -ErrorAction Stop
        if (-not $Silent) {
            Write-Host "Plan.md has been updated successfully!" -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Error "Failed to update plan.md: $($_.Exception.Message)"
        return $false
    }
}

# Function to generate a comprehensive project plan report
function New-ComprehensiveProjectPlanReport {
    param (
        [string]$OutputPath = "project-plan-report-$(Get-Date -Format 'yyyy-MM-dd').md"
    )

    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks
    $ProjectStats = Get-ProjectStats -AllTasks $AllTasks
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"

    # Sort tasks by sequence
    $SortedTasks = $AllTasks | Sort-Object -Property Sequence

    # Group tasks by status
    $TodoTasks = $SortedTasks | Where-Object { $_.Status -eq $TaskStatusTodo }
    $InProgressTasks = $SortedTasks | Where-Object { $_.Status -eq $TaskStatusInProgress }
    $DoneTasks = $SortedTasks | Where-Object { $_.Status -eq $TaskStatusDone }

    # Create ASCII progress bar
    $PercentComplete = $ProjectStats.CompletionRate
    $CompleteBars = [math]::Round($PercentComplete / 5)
    $RemainingBars = 20 - $CompleteBars

    $ProgressBar = ""
    for ($i = 0; $i -lt $CompleteBars; $i++) {
        $ProgressBar += "█"
    }
    for ($i = 0; $i -lt $RemainingBars; $i++) {
        $ProgressBar += "░"
    }

    # Group tasks by assignee
    $TasksByAssignee = @{}

    foreach ($Task in $SortedTasks) {
        if (-not $Task.AssignedTo) {
            $Assignee = "Unassigned"
        } else {
            $Assignee = $Task.AssignedTo
        }

        if (-not $TasksByAssignee.ContainsKey($Assignee)) {
            $TasksByAssignee[$Assignee] = @{
                Todo = 0
                InProgress = 0
                Done = 0
                TotalEstimatedHours = 0
                TotalActualHours = 0
                Tasks = @()
            }
        }

        # Count tasks by status
        switch ($Task.Status) {
            $TaskStatusTodo { $TasksByAssignee[$Assignee].Todo++ }
            $TaskStatusInProgress { $TasksByAssignee[$Assignee].InProgress++ }
            $TaskStatusDone { $TasksByAssignee[$Assignee].Done++ }
        }

        # Add hours
        if ($null -ne $Task.EstimatedHours) {
            $TasksByAssignee[$Assignee].TotalEstimatedHours += $Task.EstimatedHours
        }

        if ($null -ne $Task.ActualHours) {
            $TasksByAssignee[$Assignee].TotalActualHours += $Task.ActualHours
        }

        # Add task to assignee's list
        $TasksByAssignee[$Assignee].Tasks += $Task
    }

    # Generate report content
    $ReportContent = @"
# Comprehensive Project Plan Report - $CurrentDate

## 📋 Project Overview

This document provides a comprehensive view of the project plan, including all tasks, their statuses, dependencies, and timelines.

## 📊 Project Statistics

### Summary
- **Total Tasks:** $($ProjectStats.TotalTasks)
- **Todo:** $($ProjectStats.TodoCount)
- **In Progress:** $($ProjectStats.InProgressCount)
- **Done:** $($ProjectStats.DoneCount)
- **Completion Rate:** $($ProjectStats.CompletionRate)%
- **Estimated Total Hours:** $($ProjectStats.TotalEstimatedHours)
- **Hours Logged:** $($ProjectStats.TotalActualHours)

### Progress Visualization

```text
Project Completion: $ProgressBar $PercentComplete%
```

### Task Distribution

```mermaid
pie title Task Distribution
    'Todo' : $($ProjectStats.TodoCount)
    'In Progress' : $($ProjectStats.InProgressCount)
    'Done' : $($ProjectStats.DoneCount)
```

## 📝 Detailed Task List

### Todo Tasks
"@

    # Add Todo tasks details
    if ($TodoTasks.Count -gt 0) {
        foreach ($Task in $TodoTasks) {
            $ReportContent += @"

#### $($Task.ID): $($Task.Title)

- **Priority:** $($Task.Priority)
- **Due Date:** $($Task.DueDate)
- **Assigned To:** $($Task.AssignedTo)
- **Progress:** $($Task.Progress)%
- **Estimated Hours:** $($Task.EstimatedHours)
- **Actual Hours:** $($Task.ActualHours)
- **Tags:** $($Task.Tags)
"@
        }
    } else {
        $ReportContent += "`nNo tasks in Todo status."
    }

    # Add In Progress tasks details
    $ReportContent += "`n`n### In Progress Tasks"
    if ($InProgressTasks.Count -gt 0) {
        foreach ($Task in $InProgressTasks) {
            $ReportContent += @"

#### $($Task.ID): $($Task.Title)

- **Priority:** $($Task.Priority)
- **Due Date:** $($Task.DueDate)
- **Assigned To:** $($Task.AssignedTo)
- **Progress:** $($Task.Progress)%
- **Estimated Hours:** $($Task.EstimatedHours)
- **Actual Hours:** $($Task.ActualHours)
- **Tags:** $($Task.Tags)
"@
        }
    } else {
        $ReportContent += "`nNo tasks in In Progress status."
    }

    # Add Done tasks details
    $ReportContent += "`n`n### Done Tasks"
    if ($DoneTasks.Count -gt 0) {
        foreach ($Task in $DoneTasks) {
            $ReportContent += @"

#### $($Task.ID): $($Task.Title)

- **Priority:** $($Task.Priority)
- **Due Date:** $($Task.DueDate)
- **Assigned To:** $($Task.AssignedTo)
- **Progress:** 100%
- **Estimated Hours:** $($Task.EstimatedHours)
- **Actual Hours:** $($Task.ActualHours)
- **Tags:** $($Task.Tags)
"@
        }
    } else {
        $ReportContent += "`nNo tasks in Done status."
    }

    # Resource Allocation Section
    $ReportContent += @"

## 👥 Resource Allocation

### Resource Workload

| Resource | Todo | In Progress | Done | Total Tasks | Estimated Hours | Actual Hours |
|----------|------|-------------|------|-------------|-----------------|--------------|
"@

    # Add resource allocation table
    foreach ($Assignee in $TasksByAssignee.Keys | Sort-Object) {
        $TotalTasks = $TasksByAssignee[$Assignee].Todo + $TasksByAssignee[$Assignee].InProgress + $TasksByAssignee[$Assignee].Done
        $ReportContent += "`n| $Assignee | $($TasksByAssignee[$Assignee].Todo) | $($TasksByAssignee[$Assignee].InProgress) | $($TasksByAssignee[$Assignee].Done) | $TotalTasks | $($TasksByAssignee[$Assignee].TotalEstimatedHours) | $($TasksByAssignee[$Assignee].TotalActualHours) |"
    }

    # Conclusion
    $ReportContent += @"

## (Conclusion) Conclusion

This comprehensive project plan report provides a complete overview of the project's current status, tasks, timelines, and resource allocation. Use this report to track progress, identify bottlenecks, and make informed decisions about project management.

Report generated on $CurrentDate
"@

    # Detailed breakdown by assignee (moved this section to be more logical)
    $ReportContent += "`n`n## 👥 Detailed Resource Breakdown`n"
    foreach ($Assignee in $TasksByAssignee.Keys | Sort-Object) {
        $ReportContent += "`n### $Assignee`n`n" # Changed from H4 to H3 for better structure
        $ReportContent += "- **Total Tasks:** $($TasksByAssignee[$Assignee].Todo + $TasksByAssignee[$Assignee].InProgress + $TasksByAssignee[$Assignee].Done)`n"
        $ReportContent += "- **Todo:** $($TasksByAssignee[$Assignee].Todo)`n"
        $ReportContent += "- **In Progress:** $($TasksByAssignee[$Assignee].InProgress)`n"
        $ReportContent += "- **Done:** $($TasksByAssignee[$Assignee].Done)`n"
        $ReportContent += "- **Estimated Hours:** $($TasksByAssignee[$Assignee].TotalEstimatedHours)`n"
        $ReportContent += "- **Actual Hours:** $($TasksByAssignee[$Assignee].TotalActualHours)`n`n"

        $ReportContent += "**Assigned Tasks:**`n`n"
        $ReportContent += "| Task ID | Status | Title | Priority | Due Date | Progress |`n"
        $ReportContent += "|---------|--------|-------|----------|----------|----------|`n"

        foreach ($Task in $TasksByAssignee[$Assignee].Tasks | Sort-Object -Property Status, Sequence) {
            $StatusText = switch ($Task.Status) {
                $TaskStatusTodo { "Todo" }
                $TaskStatusInProgress { "In Progress" }
                $TaskStatusDone { "Done" }
                default { "Unknown" }
            }

            $ReportContent += "| $($Task.ID) | $StatusText | $($Task.Title) | $($Task.Priority) | $($Task.DueDate) | $($Task.Progress)% |`n"
        }

        $ReportContent += "`n"
    }

    # Save report (moved before the final closing brace of the function)
    try {
        Set-Content -Path $OutputPath -Value $ReportContent -ErrorAction Stop
        if (-not $Silent) {
            Write-Host "Comprehensive project plan report has been generated: $OutputPath" -ForegroundColor Green
        }
        return $OutputPath
    }
    catch {
        Write-Error "Failed to generate comprehensive report: $($_.Exception.Message)"
        return $null
    }
} # Added missing closing brace for New-ComprehensiveProjectPlanReport

# Function to generate a project report
function New-ProjectReport {
    param (
        [string]$OutputPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md"
    )

    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks
    $ProjectStats = Get-ProjectStats -AllTasks $AllTasks

    # Use stats from Get-ProjectStats
    $TotalTasks = $ProjectStats.TotalTasks
    $TodoCount = $ProjectStats.TodoCount
    $InProgressCount = $ProjectStats.InProgressCount
    $DoneCount = $ProjectStats.DoneCount
    $CompletionRate = $ProjectStats.CompletionRate
    $TotalEstimatedHours = $ProjectStats.TotalEstimatedHours
    $TotalActualHours = $ProjectStats.TotalActualHours

    # Find overdue tasks
    $Today = Get-Date
    $OverdueTasks = $AllTasks | Where-Object {
        $_.Status -ne $TaskStatusDone -and
        $null -ne ($dueDate = $_.DueDate -as [DateTime]) -and
        $dueDate -lt $Today
    }

    # Find upcoming deadlines
    $UpcomingDeadlines = $AllTasks | Where-Object {
        $_.Status -ne $TaskStatusDone -and
        $null -ne ($dueDate = $_.DueDate -as [DateTime]) -and
        $dueDate -ge $Today -and
        $dueDate -le $Today.AddDays(14)
    } | Sort-Object -Property DueDate

    # Generate report content
    $ReportContent = "# Project Status Report - $(Get-Date -Format 'yyyy-MM-dd')`n`n"
    $ReportContent += "## Project Overview`n"
    $ReportContent += "- **Total Tasks:** $TotalTasks`n"
    $ReportContent += "- **Completed Tasks:** $DoneCount ($CompletionRate percent)`n"

    $InProgressPercent = if ($TotalTasks -gt 0) { [math]::Round(($InProgressCount / $TotalTasks) * 100) } else { 0 }
    $TodoPercent = if ($TotalTasks -gt 0) { [math]::Round(($TodoCount / $TotalTasks) * 100) } else { 0 }

    $ReportContent += "- **In Progress Tasks:** $InProgressCount ($InProgressPercent percent)`n"
    $ReportContent += "- **Todo Tasks:** $TodoCount ($TodoPercent percent)`n"
    $ReportContent += "- **Overdue Tasks:** $($OverdueTasks.Count)`n"
    $ReportContent += "- **Estimated Total Hours:** $TotalEstimatedHours`n"
    $ReportContent += "- **Hours Logged:** $TotalActualHours`n`n"

    $ReportContent += "## Recent Accomplishments`n"

    # Add recent accomplishments
    $RecentDoneTasks = $AllTasks | Where-Object { $_.Status -eq $TaskStatusDone } | Sort-Object -Property { [DateTime]::Parse($_.DueDate) } -Descending | Select-Object -First 3

    if ($RecentDoneTasks.Count -gt 0) {
        foreach ($Task in $RecentDoneTasks) {
            $ReportContent += "- Completed $($Task.ID): $($Task.Title)`n"
        }
    }
    else {
        $ReportContent += "- No tasks completed recently`n"
    }

    $ReportContent += "`n## Current Work`n"

    # Add current work
    if ($InProgressCount -gt 0) {
        foreach ($Task in $AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress }) {
            $ReportContent += "- $($Task.ID): $($Task.Title) ($($Task.Progress) percent complete)`n"
        }
    }
    else {
        $ReportContent += "- No tasks currently in progress`n"
    }

    $ReportContent += "`n## Blockers and Risks`n"

    # Add blockers and risks
    if ($OverdueTasks.Count -gt 0) {
        foreach ($Task in $OverdueTasks) {
            $DaysOverdue = [math]::Round(([DateTime]::Today - [DateTime]::Parse($Task.DueDate)).TotalDays)
            $ReportContent += "- $($Task.ID) is overdue by $DaysOverdue days (Due: $($Task.DueDate))`n"
        }
    }
    else {
        $ReportContent += "- No major blockers or risks identified at this time`n"
    }

    $ReportContent += "`n## Upcoming Deadlines`n"
    $ReportContent += "| Task ID | Title | Due Date | Assigned To | Status | Progress |`n"
    $ReportContent += "|---------|-------|----------|-------------|--------|----------|`n"

    # Add upcoming deadlines
    if ($UpcomingDeadlines.Count -gt 0) {
        foreach ($Task in $UpcomingDeadlines) {
            $ReportContent += "| $($Task.ID) | $($Task.Title) | $($Task.DueDate) | $($Task.AssignedTo) | $($Task.Status) | $($Task.Progress) percent |`n"
        }
    }
    else {
        $ReportContent += "| - | No upcoming deadlines in the next 14 days | - | - | - | - |`n"
    }

    $ReportContent += "`n## Burndown Chart`n`n" # Removed one backtick pair for correct markdown
    # Generate simple ASCII burndown chart
    $PercentComplete = if ($TotalTasks -gt 0) { [math]::Round(($DoneCount / $TotalTasks) * 100) } else { 0 }

    $CompleteBars = [math]::Round($PercentComplete / 5)
    $RemainingBars = 20 - $CompleteBars

    # Create the progress bar using string multiplication
    $ProgressBar = ""
    for ($i = 0; $i -lt $CompleteBars; $i++) {
        $ProgressBar += "█"
    }
    for ($i = 0; $i -lt $RemainingBars; $i++) {
        $ProgressBar += "░"
    }

    $ReportContent += "[Progress] $ProgressBar $PercentComplete percent`n" # Removed one backtick pair
    $ReportContent += "`n`n## Notes and Action Items`n" # Removed one backtick pair
    $ReportContent += "- Continue focus on completing high-priority tasks`n"
    $ReportContent += "- Review dependencies to ensure no blocking issues`n"
    $ReportContent += "- Update task statuses regularly`n"

    # Save report
    try {
        Set-Content -Path $OutputPath -Value $ReportContent -ErrorAction Stop
        if (-not $Silent) {
            Write-Host "Project report has been generated: $OutputPath" -ForegroundColor Green
        }
        return $OutputPath
    }
    catch {
        Write-Error "Failed to generate report: $($_.Exception.Message)"
        return $null
    }
}

# Function to reset project tasks by moving them to archive
function Reset-ProjectTasks {
    param (
        [switch]$Force
    )

    # Confirm with user unless Force is specified
    if (-not $Force -and -not $Silent) {
        $confirmation = Read-Host "WARNING: This will move all tasks to the archive folder. Are you sure? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return $false
        }
    }

    # Initialize all required folders
    Initialize-RequiredFolders

    # Create archive date folder
    $ArchivePath = "project planning/archive"
    $ArchiveDateFolder = Join-Path -Path $ArchivePath -ChildPath (Get-Date -Format "yyyy-MM-dd")

    # Create date-specific archive folder
    if (-not (Test-Path -Path $ArchiveDateFolder)) {
        try {
            New-Item -Path $ArchiveDateFolder -ItemType Directory -Force | Out-Null
            if (-not $Silent) {
                Write-Host "Created archive date folder: $ArchiveDateFolder" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to create archive date folder: $($_.Exception.Message)"
            return $false
        }
    }

    # Get all tasks
    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks

    if ($AllTasks.Count -eq 0) {
        if (-not $Silent) {
            Write-Host "No tasks found to archive." -ForegroundColor Yellow
        }
        return $true
    }

    $ArchivedCount = 0
    $ErrorCount = 0

    # Move all tasks to archive
    foreach ($Task in $AllTasks) {
        $TaskFile = $Task.FilePath
        $TaskFileName = Split-Path -Path $TaskFile -Leaf
        $DestinationFile = Join-Path -Path $ArchiveDateFolder -ChildPath $TaskFileName

        try {
            # Copy the file to archive
            Copy-Item -Path $TaskFile -Destination $DestinationFile -Force

            # Delete the original file
            Remove-Item -Path $TaskFile -Force

            $ArchivedCount++
        }
        catch {
            Write-Error "Failed to archive task $($Task.ID): $($_.Exception.Message)"
            $ErrorCount++
        }
    }

    # Update plan.md to reflect empty project
    try {
        Update-PlanFile
    }
    catch {
        Write-Error "Failed to update plan.md after archiving tasks: $($_.Exception.Message)"
    }

    if (-not $Silent) {
        Write-Host "Project reset complete." -ForegroundColor Green
        Write-Host "Archived $ArchivedCount tasks to $ArchiveDateFolder" -ForegroundColor Green
        if ($ErrorCount -gt 0) {
            Write-Host "Encountered $ErrorCount errors during archiving." -ForegroundColor Red
        }
    }

    return ($ErrorCount -eq 0)
}

# Function to list tasks
function Get-TaskList {
    param (
        [string]$Status = "all",
        [string]$AssignedTo = ""
    )

    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks

    # Filter tasks by status
    $FilteredTasks = switch ($Status.ToLower()) {
        "todo" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusTodo } }
        "inprogress" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress } }
        "done" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusDone } }
        "open" { $AllTasks | Where-Object { $_.Status -ne $TaskStatusDone } }
        default { $AllTasks }
    }

    # Filter tasks by assignee if specified
    if ($AssignedTo -ne "") {
        $FilteredTasks = $FilteredTasks | Where-Object { $_.AssignedTo -like "*$AssignedTo*" }
    }

    # Sort tasks by sequence
    $FilteredTasks = $FilteredTasks | Sort-Object -Property Sequence

    return $FilteredTasks
}

# Function to display tasks in a formatted table
function Show-TaskList {
    param (
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Host "No tasks found matching the criteria." -ForegroundColor Yellow
        return
    }

    # Create a formatted table
    $TaskTable = @()

    # Count tasks by status
    $TaskStatusCounts = @{
        "$TaskStatusTodo" = 0
        "$TaskStatusInProgress" = 0
        "$TaskStatusDone" = 0
        "Other" = 0
    }

    foreach ($Task in $Tasks) {
        # Count tasks by status
        if ($Task.Status -eq $TaskStatusTodo) {
            $TaskStatusCounts["$TaskStatusTodo"]++
        }
        elseif ($Task.Status -eq $TaskStatusInProgress) {
            $TaskStatusCounts["$TaskStatusInProgress"]++
        }
        elseif ($Task.Status -eq $TaskStatusDone) {
            $TaskStatusCounts["$TaskStatusDone"]++
        }
        else {
            $TaskStatusCounts["Other"]++
        }

        $StatusIcon = switch ($Task.Status) {
            $TaskStatusTodo { "[T]" }
            $TaskStatusInProgress { "[I]" }
            $TaskStatusDone { "[D]" }
            default { "[?]" }
        }

        $TaskObj = [PSCustomObject]@{
            ID = $Task.ID
            Status = "$StatusIcon $($Task.Status)"
            Title = $Task.Title
            Priority = $Task.Priority
            DueDate = $Task.DueDate
            AssignedTo = $Task.AssignedTo
            Progress = "$($Task.Progress)%"
        }

        $TaskTable += $TaskObj
    }

    # Display the table
    $TaskTable | Format-Table -AutoSize

    # Display summary
    Write-Host "Total: $($Tasks.Count) tasks" -ForegroundColor Cyan
    Write-Host "Todo: $($TaskStatusCounts["$TaskStatusTodo"]) | In Progress: $($TaskStatusCounts["$TaskStatusInProgress"]) | Done: $($TaskStatusCounts["$TaskStatusDone"])" -ForegroundColor Cyan
}

# Function to show interactive menu
function Show-Menu {
    Clear-Host
    Write-Host "===== Project Planning Management =====" -ForegroundColor Cyan
    Write-Host "1: Update plan.md with current task statuses" -ForegroundColor White
    Write-Host "2: Generate project report" -ForegroundColor White
    Write-Host "3: List all tasks" -ForegroundColor White
    Write-Host "4: List open tasks (Todo + In Progress)" -ForegroundColor White
    Write-Host "5: List tasks by status" -ForegroundColor White
    Write-Host "6: List tasks by assignee" -ForegroundColor White
    Write-Host "7: Reset project (archive all tasks)" -ForegroundColor Red
    Write-Host "8: Exit" -ForegroundColor White
    Write-Host "=======================================" -ForegroundColor Cyan
}

# Main script logic
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptPath

# Initialize required folders
Initialize-RequiredFolders

# Handle silent mode
if ($Silent) {
    if ($ResetTasks) {
        Reset-ProjectTasks -Force
    }

    if ($UpdatePlan) {
        Update-PlanFile
    }

    if ($GenerateReport) {
        New-ProjectReport -OutputPath $ReportPath
    }

    if ($GenerateComprehensiveReport) {
        New-ComprehensiveProjectPlanReport -OutputPath $ComprehensiveReportPath
    }

    if ($ListTasks) {
        $Tasks = Get-TaskList -Status $TaskStatus -AssignedTo $AssignedTo
        Show-TaskList -Tasks $Tasks
    }

    exit
}

# Handle interactive mode
$exit = $false

while (-not $exit) {
    Show-Menu
    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" {
            Update-PlanFile
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "2" {
            $ReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md"
            New-ProjectReport -OutputPath $ReportPath
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "3" {
            $Tasks = Get-TaskList
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "4" {
            $Tasks = Get-TaskList -Status "open"
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "5" {
            Clear-Host
            Write-Host "Select status to filter by:" -ForegroundColor Cyan
            Write-Host "1: Todo" -ForegroundColor White
            Write-Host "2: In Progress" -ForegroundColor White
            Write-Host "3: Done" -ForegroundColor White
            Write-Host "4: All" -ForegroundColor White

            $statusChoice = Read-Host "Enter your choice"
            $status = switch ($statusChoice) {
                "1" { "todo" }
                "2" { "inprogress" }
                "3" { "done" }
                "4" { "all" }
                default { "all" }
            }

            $Tasks = Get-TaskList -Status $status
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "6" {
            $assignee = Read-Host "Enter assignee name (or part of name)"
            $Tasks = Get-TaskList -AssignedTo $assignee
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "7" {
            Reset-ProjectTasks
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
        "8" {
            $exit = $true
        }
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
    }
}
