# SubsHero Task Management - Plan Updater Script (Kanban Version)
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
    
    # Create Kanban board
    $KanbanMermaid = "```mermaid`nkanban`n"
    
    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "Todo" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    Todo `"$($Task.ID): $($Task.Title)`" `"Priority: $($Task.Priority)`" `"Due: $($Task.DueDate)`" `"Assigned: $($Task.AssignedTo)`" `"Progress: $($Task.Progress)%`"`n"
    }
    
    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "InProgress" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    InProgress `"$($Task.ID): $($Task.Title)`" `"Priority: $($Task.Priority)`" `"Due: $($Task.DueDate)`" `"Assigned: $($Task.AssignedTo)`" `"Progress: $($Task.Progress)%`"`n"
    }
    
    foreach ($Task in $AllTasks | Where-Object { $_.Status -eq "Done" } | Sort-Object -Property Sequence) {
        $KanbanMermaid += "    Done `"$($Task.ID): $($Task.Title)`" `"Priority: $($Task.Priority)`" `"Due: $($Task.DueDate)`" `"Assigned: $($Task.AssignedTo)`" `"Progress: $($Task.Progress)%`"`n"
    }
    
    $KanbanMermaid += "```"
    
    # Create task summary table
    $TaskSummaryTable = "| ID | Status | Title | Priority | Due Date | Assigned To | Progress |`n|----|--------|-------|----------|----------|-------------|----------|`n"
    
    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $StatusIcon = switch ($Task.Status) {
            "Todo" { "📌 Todo" }
            "InProgress" { "🔨 In Progress" }
            "Done" { "✅ Done" }
        }
        
        $TaskSummaryTable += "| $($Task.ID) | $StatusIcon | $($Task.Title) | $($Task.Priority) | $($Task.DueDate) | $($Task.AssignedTo) | $($Task.Progress)% |`n"
    }
    
    # Update Kanban board and task summary in plan.md
    $KanbanPattern = "## 📋 Kanban Board\r?\n\r?\n```mermaid\r?\nkanban\r?\n(?:    (?:Todo|InProgress|Done).*\r?\n)*```\r?\n\r?\n## 📊 Task Summary\r?\n\r?\n\| ID \| Status \| Title \| Priority \| Due Date \| Assigned To \| Progress \|\r?\n\|----\|--------\|-------\|----------\|----------\|-------------\|----------\|\r?\n(?:\|.*\r?\n)*"
    
    $KanbanReplacement = @"
## 📋 Kanban Board

$KanbanMermaid

## 📊 Task Summary

$TaskSummaryTable
"@
    
    $PlanContent = $PlanContent -replace $KanbanPattern, $KanbanReplacement
    
    # Update task dependencies table
    $DependenciesTable = "| Task ID | Task Name | Depends On | Required By |`n|---------|-----------|------------|------------|`n"
    foreach ($Task in $AllTasks | Sort-Object -Property Sequence) {
        $DependenciesTable += "| $($Task.ID) | $($Task.Title) | $($Task.DependsOn) | $($Task.RequiredBy) |`n"
    }
    
    $DependenciesPattern = "## 🔄 Task Dependencies\r?\n\r?\n\| Task ID \| Task Name \| Depends On \| Required By \|\r?\n\|---------|-----------|------------|------------\|\r?\n(?:\|.*\r?\n)*"
    $PlanContent = $PlanContent -replace $DependenciesPattern, "## 🔄 Task Dependencies`n`n$DependenciesTable"
    
    # Update recent updates
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"
    $UpdatesPattern = "## 📅 Recent Updates\r?\n(?:- .*\r?\n)*"
    $UpdatesMatch = [regex]::Match($PlanContent, $UpdatesPattern).Value
    $NewUpdate = "- $CurrentDate - Updated plan.md with latest task statuses"
    
    if ($UpdatesMatch -notmatch [regex]::Escape($NewUpdate)) {
        $UpdatesReplacement = $UpdatesMatch + $NewUpdate + "`n"
        $PlanContent = $PlanContent -replace $UpdatesPattern, $UpdatesReplacement
    }
    
    # Save updated plan.md
    Set-Content -Path "plan.md" -Value $PlanContent
    
    Write-Host "Plan.md has been updated successfully!"
}

# Main script
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptPath

# Run the update
Update-PlanFile
