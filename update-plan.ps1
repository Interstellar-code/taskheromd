# SubsHero Task Management - Plan Updater Script
# This script automatically updates the plan.md file based on task statuses

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

# Function to update plan.md
function Update-PlanFile {
    $TodoTasks = Get-ChildItem -Path "todo" -Filter "TASK-*.md"
    $InProgressTasks = Get-ChildItem -Path "inprogress" -Filter "TASK-*.md"
    $DoneTasks = Get-ChildItem -Path "done" -Filter "TASK-*.md"

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
            Progress = $Progress
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
            RequiredBy = $Dependencies.RequiredBy -join ", "
            DependsOn = $Dependencies.DependsOn -join ", "
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
            Progress = $Progress
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
            RequiredBy = $Dependencies.RequiredBy -join ", "
            DependsOn = $Dependencies.DependsOn -join ", "
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
            Progress = 100
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
            RequiredBy = $Dependencies.RequiredBy -join ", "
            DependsOn = $Dependencies.DependsOn -join ", "
        }

        $AllTasks += $TaskInfo
        $TotalEstimatedHours += $Metadata.EstimatedHours
        $TotalActualHours += $Metadata.ActualHours
    }

    # Update project stats
    $TotalTasks = $AllTasks.Count
    $TodoCount = ($AllTasks | Where-Object { $_.Status -eq "Todo" }).Count
    $InProgressCount = ($AllTasks | Where-Object { $_.Status -eq "InProgress" }).Count
    $DoneCount = ($AllTasks | Where-Object { $_.Status -eq "Done" }).Count
    $CompletionRate = [math]::Round(($DoneCount / $TotalTasks) * 100)

    $PlanContent = Get-Content -Path "plan.md" -Raw

    # Update project stats
    $StatsPattern = "## 📊 Project Stats\r?\n- \*\*Total Tasks:\*\* \d+\r?\n- \*\*Todo:\*\* \d+\r?\n- \*\*In Progress:\*\* \d+\r?\n- \*\*Done:\*\* \d+\r?\n- \*\*Completion Rate:\*\* \d+%\r?\n- \*\*Estimated Total Hours:\*\* \d+\r?\n- \*\*Hours Logged:\*\* \d+"
    $StatsReplacement = @"
## 📊 Project Stats
- **Total Tasks:** $TotalTasks
- **Todo:** $TodoCount
- **In Progress:** $InProgressCount
- **Done:** $DoneCount
- **Completion Rate:** $CompletionRate%
- **Estimated Total Hours:** $TotalEstimatedHours
- **Hours Logged:** $TotalActualHours
"@

    $PlanContent = $PlanContent -replace $StatsPattern, $StatsReplacement

    # Update Kanban board and task summary
    $KanbanMermaid = "```mermaid\r\nkanban\r\n"

    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "Todo" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    Todo \"$($Task.ID): $($Task.Title)\" \"Priority: $($Task.Priority)\" \"Due: $($Task.DueDate)\" \"Assigned: $($Task.AssignedTo)\" \"Progress: $($Task.Progress)%\"\r\n"
    }

    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "InProgress" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    InProgress \"$($Task.ID): $($Task.Title)\" \"Priority: $($Task.Priority)\" \"Due: $($Task.DueDate)\" \"Assigned: $($Task.AssignedTo)\" \"Progress: $($Task.Progress)%\"\r\n"
    }

    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "Done" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    Done \"$($Task.ID): $($Task.Title)\" \"Priority: $($Task.Priority)\" \"Due: $($Task.DueDate)\" \"Assigned: $($Task.AssignedTo)\" \"Progress: $($Task.Progress)%\"\r\n"
    }

    $KanbanMermaid += "```"

    # Create task summary table
    $TaskSummaryTable = "| ID | Status | Title | Priority | Due Date | Assigned To | Progress |\r\n|----|--------|-------|----------|----------|-------------|----------|\r\n"

    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $StatusIcon = switch ($Task.Status) {
            "Todo" { "📌 Todo" }
            "InProgress" { "🔨 In Progress" }
            "Done" { "✅ Done" }
        }

        $TaskSummaryTable += "| $($Task.ID) | $StatusIcon | $($Task.Title) | $($Task.Priority) | $($Task.DueDate) | $($Task.AssignedTo) | $($Task.Progress)% |\r\n"
    }

    # Update Kanban board and task summary in plan.md
    $TaskBoardsPattern = "## 📋 Kanban Board\r?\n\r?\n```mermaid\r?\nkanban\r?\n(?:    (?:Todo|InProgress|Done).*\r?\n)*```\r?\n\r?\n## 📊 Task Summary\r?\n\r?\n\| ID \| Status \| Title \| Priority \| Due Date \| Assigned To \| Progress \|\r?\n\|----\|--------\|-------\|----------\|----------\|-------------\|----------\|\r?\n(?:\|.*\r?\n)*"

    $TaskBoardsReplacement = @"
## 📋 Kanban Board

$KanbanMermaid

## 📊 Task Summary

$TaskSummaryTable
"@

    $PlanContent = $PlanContent -replace $TaskBoardsPattern, $TaskBoardsReplacement

    # Update task dependencies table
    $DependenciesTable = "## 🔄 Task Dependencies\r?\n\r?\n\| Task ID \| Task Name \| Depends On \| Required By \|\r?\n\|---------|-----------|------------|------------\|\r?\n"
    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $DependenciesTable += "| $($Task.ID) | $($Task.Title) | $($Task.DependsOn) | $($Task.RequiredBy) |\r\n"
    }

    $DependenciesPattern = "## 🔄 Task Dependencies\r?\n\r?\n\| Task ID \| Task Name \| Depends On \| Required By \|\r?\n\|---------|-----------|------------|------------\|\r?\n(?:\|.*\r?\n)*"
    $PlanContent = $PlanContent -replace $DependenciesPattern, $DependenciesTable

    # Update recent updates
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"
    $UpdatesPattern = "## 📅 Recent Updates\r?\n(?:- .*\r?\n)*"
    $UpdatesSection = $PlanContent -match $UpdatesPattern
    $UpdatesMatch = $matches[0]
    $NewUpdate = "- $CurrentDate - Updated plan.md with latest task statuses"

    if ($UpdatesMatch -notmatch [regex]::Escape($NewUpdate)) {
        $UpdatesReplacement = $UpdatesMatch + $NewUpdate + "`r`n"
        $PlanContent = $PlanContent -replace $UpdatesPattern, $UpdatesReplacement
    }

    # Save updated plan.md
    Set-Content -Path "plan.md" -Value $PlanContent

    Write-Host "Plan.md has been updated successfully!"
}

# Function to generate a project report
function New-ProjectReport {
    param (
        [string]$OutputPath = "project-report.md"
    )

    $TodoTasks = Get-ChildItem -Path "todo" -Filter "TASK-*.md"
    $InProgressTasks = Get-ChildItem -Path "inprogress" -Filter "TASK-*.md"
    $DoneTasks = Get-ChildItem -Path "done" -Filter "TASK-*.md"

    $AllTasks = @()
    $TotalEstimatedHours = 0
    $TotalActualHours = 0

    # Process all tasks
    foreach ($Task in ($TodoTasks + $InProgressTasks + $DoneTasks)) {
        $Metadata = Get-TaskMetadata -TaskPath $Task.FullName
        $Progress = 0

        if ($Task.Directory.Name -eq "done") {
            $Progress = 100
        }
        elseif ($Task.Directory.Name -eq "inprogress") {
            $Progress = Get-TaskProgress -TaskPath $Task.FullName
        }

        $TaskInfo = @{
            ID = $Metadata.ID
            Title = $Metadata.Title
            Priority = $Metadata.Priority
            DueDate = $Metadata.DueDate
            Status = $Task.Directory.Name
            AssignedTo = $Metadata.AssignedTo
            Progress = $Progress
            EstimatedHours = $Metadata.EstimatedHours
            ActualHours = $Metadata.ActualHours
        }

        $AllTasks += $TaskInfo
        $TotalEstimatedHours += $Metadata.EstimatedHours
        $TotalActualHours += $Metadata.ActualHours
    }

    # Calculate project stats
    $TotalTasks = $AllTasks.Count
    $TodoCount = ($AllTasks | Where-Object { $_.Status -eq "todo" }).Count
    $InProgressCount = ($AllTasks | Where-Object { $_.Status -eq "inprogress" }).Count
    $DoneCount = ($AllTasks | Where-Object { $_.Status -eq "done" }).Count
    $CompletionRate = [math]::Round(($DoneCount / $TotalTasks) * 100)

    # Find overdue tasks
    $Today = Get-Date
    $OverdueTasks = $AllTasks | Where-Object {
        $_.Status -ne "done" -and
        [DateTime]::Parse($_.DueDate) -lt $Today
    }

    # Find upcoming deadlines
    $UpcomingDeadlines = $AllTasks | Where-Object {
        $_.Status -ne "done" -and
        [DateTime]::Parse($_.DueDate) -ge $Today -and
        [DateTime]::Parse($_.DueDate) -le $Today.AddDays(14)
    } | Sort-Object -Property DueDate

    # Generate report content
    $ReportContent = @"
# SubsHero Project Status Report - $(Get-Date -Format "yyyy-MM-dd")

## 📊 Project Overview
- **Total Tasks:** $TotalTasks
- **Completed Tasks:** $DoneCount ($CompletionRate%)
- **In Progress Tasks:** $InProgressCount ($(if ($TotalTasks -gt 0) { [math]::Round(($InProgressCount / $TotalTasks) * 100) } else { 0 })%)
- **Todo Tasks:** $TodoCount ($(if ($TotalTasks -gt 0) { [math]::Round(($TodoCount / $TotalTasks) * 100) } else { 0 })%)
- **Overdue Tasks:** $($OverdueTasks.Count)
- **Estimated Total Hours:** $TotalEstimatedHours
- **Hours Logged:** $TotalActualHours

## 🏆 Recent Accomplishments
"@

    # Add recent accomplishments
    foreach ($Task in $DoneTasks | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 3) {
        $Metadata = Get-TaskMetadata -TaskPath $Task.FullName
        $ReportContent += "- Completed $($Metadata.ID): $($Metadata.Title)`r`n"
    }

    $ReportContent += @"

## 🚧 Current Work
"@

    # Add current work
    foreach ($Task in $InProgressTasks) {
        $Metadata = Get-TaskMetadata -TaskPath $Task.FullName
        $Progress = Get-TaskProgress -TaskPath $Task.FullName
        $ReportContent += "- $($Metadata.ID): $($Metadata.Title) ($Progress% complete)`r`n"
    }

    $ReportContent += @"

## 🚩 Blockers & Risks
"@

    # Add blockers and risks
    if ($OverdueTasks.Count -gt 0) {
        foreach ($Task in $OverdueTasks) {
            $DaysOverdue = [math]::Round(([DateTime]::Today - [DateTime]::Parse($Task.DueDate)).TotalDays)
            $ReportContent += "- $($Task.ID) is overdue by $DaysOverdue days (Due: $($Task.DueDate))`r`n"
        }
    }
    else {
        $ReportContent += "- No major blockers or risks identified at this time`r`n"
    }

    $ReportContent += @"

## 📅 Upcoming Deadlines
| Task ID | Title | Due Date | Assigned To | Status | Progress |
|---------|-------|----------|-------------|--------|----------|
"@

    # Add upcoming deadlines
    if ($UpcomingDeadlines.Count -gt 0) {
        foreach ($Task in $UpcomingDeadlines) {
            $ReportContent += "| $($Task.ID) | $($Task.Title) | $($Task.DueDate) | $($Task.AssignedTo) | $($Task.Status) | $($Task.Progress)% |`r`n"
        }
    }
    else {
        $ReportContent += "| - | No upcoming deadlines in the next 14 days | - | - | - | - |`r`n"
    }

    $ReportContent += @"

## 📈 Burndown Chart
```
"@

    # Generate simple ASCII burndown chart
    $TotalWork = $TotalTasks
    $RemainingWork = $TodoCount + $InProgressCount
    $PercentComplete = [math]::Round(($DoneCount / $TotalTasks) * 100)
    $PercentRemaining = 100 - $PercentComplete

    $CompleteBars = [math]::Round($PercentComplete / 5)
    $RemainingBars = 20 - $CompleteBars

    $ReportContent += "[Progress] $("█" * $CompleteBars)$("░" * $RemainingBars) $PercentComplete%`r`n"

    $ReportContent += @"
```

## 📝 Notes & Action Items
- Continue focus on completing high-priority tasks
- Review dependencies to ensure no blocking issues
- Update task statuses regularly
"@

    # Save report
    Set-Content -Path $OutputPath -Value $ReportContent

    Write-Host "Project report has been generated: $OutputPath"
}

# Main script
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptPath

# Show menu
function Show-Menu {
    Clear-Host
    Write-Host "===== SubsHero Plan Updater ====="
    Write-Host "1: Update plan.md with current task statuses"
    Write-Host "2: Generate project report"
    Write-Host "3: Do both"
    Write-Host "4: Exit"
    Write-Host "=================================="
}

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
            Update-PlanFile
            $ReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md"
            New-ProjectReport -OutputPath $ReportPath
            Read-Host "Press Enter to continue"
        }
        "4" {
            $exit = $true
        }
        default {
            Write-Host "Invalid choice. Please try again."
            Read-Host "Press Enter to continue"
        }
    }
}
