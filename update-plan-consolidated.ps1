# Project Planning Management - Consolidated Script
# This script combines plan.md updating and reporting functionality with interactive and silent modes

param (
    [switch]$Silent,
    [switch]$UpdatePlan,
    [switch]$GenerateReport,
    [switch]$ListTasks,
    [string]$TaskStatus = "all",
    [string]$AssignedTo = "",
    [string]$ReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md"
)

# Function to calculate task progress based on acceptance criteria
function Get-TaskProgress {
    param (
        [string]$TaskPath
    )

    $Content = Get-Content -Path $TaskPath -Raw
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
        [string]$TaskPath
    )

    $Content = Get-Content -Path $TaskPath -Raw
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
        [string]$TaskPath
    )

    $Content = Get-Content -Path $TaskPath -Raw
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

# Function to get all tasks
function Get-AllTasks {
    $TodoTasks = Get-ChildItem -Path "project planning/todo" -Filter "TASK-*.md" -ErrorAction SilentlyContinue
    $InProgressTasks = Get-ChildItem -Path "project planning/inprogress" -Filter "TASK-*.md" -ErrorAction SilentlyContinue
    $DoneTasks = Get-ChildItem -Path "project planning/done" -Filter "TASK-*.md" -ErrorAction SilentlyContinue

    $AllTasks = @()
    $TotalEstimatedHours = 0
    $TotalActualHours = 0

    # Process todo tasks
    foreach ($Task in $TodoTasks) {
        $Metadata = Get-TaskMetadata -TaskPath $Task.FullName
        $Progress = Get-TaskProgress -TaskPath $Task.FullName
        $Dependencies = Get-TaskDependencies -TaskPath $Task.FullName

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = "Todo"
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
        $Metadata = Get-TaskMetadata -TaskPath $Task.FullName
        $Progress = Get-TaskProgress -TaskPath $Task.FullName
        $Dependencies = Get-TaskDependencies -TaskPath $Task.FullName

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = "InProgress"
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
        $Metadata = Get-TaskMetadata -TaskPath $Task.FullName
        $Dependencies = Get-TaskDependencies -TaskPath $Task.FullName

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = "Done"
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
function Update-PlanFile {
    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks
    $TotalEstimatedHours = $TaskData.TotalEstimatedHours
    $TotalActualHours = $TaskData.TotalActualHours

    # Update project stats
    $TotalTasks = $AllTasks.Count
    $TodoCount = ($AllTasks | Where-Object { $_.Status -eq "Todo" }).Count
    $InProgressCount = ($AllTasks | Where-Object { $_.Status -eq "InProgress" }).Count
    $DoneCount = ($AllTasks | Where-Object { $_.Status -eq "Done" }).Count
    $CompletionRate = if ($TotalTasks -gt 0) { [math]::Round(($DoneCount / $TotalTasks) * 100) } else { 0 }

    $PlanContent = Get-Content -Path "plan.md" -Raw

    # Update project stats
    $StatsPattern = '## Project Stats[\s\S]*?- \*\*Hours Logged:\*\* \d+'
    $StatsReplacement = @"
## Project Stats
- **Total Tasks:** $TotalTasks
- **Todo:** $TodoCount
- **In Progress:** $InProgressCount
- **Done:** $DoneCount
- **Completion Rate:** $CompletionRate%
- **Estimated Total Hours:** $TotalEstimatedHours
- **Hours Logged:** $TotalActualHours
"@

    $PlanContent = $PlanContent -replace $StatsPattern, $StatsReplacement

    # Create Kanban board
    $KanbanMermaid = @'
```mermaid
kanban
'@

    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "Todo" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    Todo `"$($Task.ID): $($Task.Title)`" `"Priority: $($Task.Priority)`" `"Due: $($Task.DueDate)`" `"Assigned: $($Task.AssignedTo)`" `"Progress: $($Task.Progress)%`"`n"
    }

    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "InProgress" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    InProgress `"$($Task.ID): $($Task.Title)`" `"Priority: $($Task.Priority)`" `"Due: $($Task.DueDate)`" `"Assigned: $($Task.AssignedTo)`" `"Progress: $($Task.Progress)%`"`n"
    }

    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "Done" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    Done `"$($Task.ID): $($Task.Title)`" `"Priority: $($Task.Priority)`" `"Due: $($Task.DueDate)`" `"Assigned: $($Task.AssignedTo)`" `"Progress: $($Task.Progress)%`"`n"
    }

    $KanbanMermaid += '```'

    # Create task summary table
    $TaskSummaryTable = "| ID | Status | Title | Priority | Due Date | Assigned To | Progress |\n|----|--------|-------|----------|----------|-------------|----------|\n"

    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $StatusIcon = switch ($Task.Status) {
            "Todo" { "[Todo]" }
            "InProgress" { "[In Progress]" }
            "Done" { "[Done]" }
        }

        $TaskSummaryTable += "| $($Task.ID) | $StatusIcon | $($Task.Title) | $($Task.Priority) | $($Task.DueDate) | $($Task.AssignedTo) | $($Task.Progress)% |\n"
    }

    # Update Kanban board and task summary in plan.md
    $KanbanPattern = '## Kanban Board[\s\S]*?## Task Summary[\s\S]*?\| ID \| Status \| Title \| Priority \| Due Date \| Assigned To \| Progress \|[\s\S]*?(?=##)'

    $KanbanReplacement = @"
## Kanban Board

$KanbanMermaid

## Task Summary

$TaskSummaryTable

"@

    $PlanContent = $PlanContent -replace $KanbanPattern, $KanbanReplacement

    # Update task dependencies table
    $DependenciesTable = "| Task ID | Task Name | Depends On | Required By |\n|---------|-----------|------------|------------|\n"
    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $DependenciesTable += "| $($Task.ID) | $($Task.Title) | $($Task.DependsOn) | $($Task.RequiredBy) |\n"
    }

    $DependenciesPattern = '## Task Dependencies[\s\S]*?\| Task ID \| Task Name \| Depends On \| Required By \|[\s\S]*?(?=##)'
    $DependenciesReplacement = @"
## Task Dependencies

$DependenciesTable

"@

    $PlanContent = $PlanContent -replace $DependenciesPattern, $DependenciesReplacement

    # Update recent updates
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"
    $UpdatesPattern = '## Recent Updates[\s\S]*?(?=##|$)'
    $UpdatesMatch = [regex]::Match($PlanContent, $UpdatesPattern).Value
    $NewUpdate = "- $CurrentDate - Updated plan.md with latest task statuses"

    if ($UpdatesMatch -notmatch [regex]::Escape($NewUpdate)) {
        $UpdatesReplacement = $UpdatesMatch -replace '(## Recent Updates\r?\n)', "`$1$NewUpdate`n"
        $PlanContent = $PlanContent -replace [regex]::Escape($UpdatesMatch), $UpdatesReplacement
    }

    # Save updated plan.md
    Set-Content -Path "plan.md" -Value $PlanContent

    if (-not $Silent) {
        Write-Host "Plan.md has been updated successfully!" -ForegroundColor Green
    }

    return $true
}

# Function to generate a project report
function New-ProjectReport {
    param (
        [string]$OutputPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md"
    )

    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks
    $TotalEstimatedHours = $TaskData.TotalEstimatedHours
    $TotalActualHours = $TaskData.TotalActualHours

    # Calculate project stats
    $TotalTasks = $AllTasks.Count
    $TodoCount = ($AllTasks | Where-Object { $_.Status -eq "Todo" }).Count
    $InProgressCount = ($AllTasks | Where-Object { $_.Status -eq "InProgress" }).Count
    $DoneCount = ($AllTasks | Where-Object { $_.Status -eq "Done" }).Count
    $CompletionRate = if ($TotalTasks -gt 0) { [math]::Round(($DoneCount / $TotalTasks) * 100) } else { 0 }

    # Find overdue tasks
    $Today = Get-Date
    $OverdueTasks = $AllTasks | Where-Object {
        $_.Status -ne "Done" -and
        [DateTime]::TryParse($_.DueDate, [ref]$null) -and
        [DateTime]::Parse($_.DueDate) -lt $Today
    }

    # Find upcoming deadlines
    $UpcomingDeadlines = $AllTasks | Where-Object {
        $_.Status -ne "Done" -and
        [DateTime]::TryParse($_.DueDate, [ref]$null) -and
        [DateTime]::Parse($_.DueDate) -ge $Today -and
        [DateTime]::Parse($_.DueDate) -le $Today.AddDays(14)
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
    $RecentDoneTasks = $AllTasks | Where-Object { $_.Status -eq "Done" } | Sort-Object -Property { [DateTime]::Parse($_.DueDate) } -Descending | Select-Object -First 3

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
        foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "InProgress" }) {
            $ReportContent += "- $($Task.ID): $($Task.Title) ($($Task.Progress) percent complete)`n"
        }
    }
    else {
        $ReportContent += "- No tasks currently in progress`n"
    }

    $ReportContent += "`n## Blockers & Risks`n"

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

    $ReportContent += "`n## Burndown Chart`n````n"

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

    $ReportContent += "[Progress] $ProgressBar $PercentComplete percent`n"
    $ReportContent += "````n`n"

    $ReportContent += "## Notes & Action Items`n"
    $ReportContent += "- Continue focus on completing high-priority tasks`n"
    $ReportContent += "- Review dependencies to ensure no blocking issues`n"
    $ReportContent += "- Update task statuses regularly`n"

    # Save report
    Set-Content -Path $OutputPath -Value $ReportContent

    if (-not $Silent) {
        Write-Host "Project report has been generated: $OutputPath" -ForegroundColor Green
    }

    return $OutputPath
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
        "todo" { $AllTasks | Where-Object { $_.Status -eq "Todo" } }
        "inprogress" { $AllTasks | Where-Object { $_.Status -eq "InProgress" } }
        "done" { $AllTasks | Where-Object { $_.Status -eq "Done" } }
        "open" { $AllTasks | Where-Object { $_.Status -ne "Done" } }
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

    foreach ($Task in $Tasks) {
        $StatusIcon = switch ($Task.Status) {
            "Todo" { "[T]" }
            "InProgress" { "[I]" }
            "Done" { "[D]" }
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
    $TodoCount = ($Tasks | Where-Object { $_.Status -eq "Todo" }).Count
    $InProgressCount = ($Tasks | Where-Object { $_.Status -eq "InProgress" }).Count
    $DoneCount = ($Tasks | Where-Object { $_.Status -eq "Done" }).Count

    Write-Host "Todo: $TodoCount | In Progress: $InProgressCount | Done: $DoneCount" -ForegroundColor Cyan
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
    Write-Host "7: Exit" -ForegroundColor White
    Write-Host "=======================================" -ForegroundColor Cyan
}

# Main script logic
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptPath

# Handle silent mode
if ($Silent) {
    if ($UpdatePlan) {
        Update-PlanFile
    }

    if ($GenerateReport) {
        New-ProjectReport -OutputPath $ReportPath
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
            Read-Host "Press Enter to continue"
        }
        "2" {
            $ReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md"
            New-ProjectReport -OutputPath $ReportPath
            Read-Host "Press Enter to continue"
        }
        "3" {
            $Tasks = Get-TaskList
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue"
        }
        "4" {
            $Tasks = Get-TaskList -Status "open"
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue"
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
            Read-Host "Press Enter to continue"
        }
        "6" {
            $assignee = Read-Host "Enter assignee name (or part of name)"
            $Tasks = Get-TaskList -AssignedTo $assignee
            Show-TaskList -Tasks $Tasks
            Read-Host "Press Enter to continue"
        }
        "7" {
            $exit = $true
        }
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Read-Host "Press Enter to continue"
        }
    }
}
