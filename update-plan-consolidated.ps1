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

    # Debug output to check task statuses
    if (-not $Silent) {
        Write-Host "Debug - Task Status Check:" -ForegroundColor Cyan
        foreach ($Task in $AllTasks) {
            Write-Host "Task ID: $($Task.ID), Status: $($Task.Status)" -ForegroundColor Cyan
        }
    }

    # Ensure we're using the correct status values
    $TodoCount = ($AllTasks | Where-Object { $_.Status -eq $TaskStatusTodo }).Count
    $InProgressCount = ($AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress }).Count
    $DoneCount = ($AllTasks | Where-Object { $_.Status -eq $TaskStatusDone }).Count

    # Verify the counts add up to the total
    $TotalStatusCount = $TodoCount + $InProgressCount + $DoneCount
    if ($TotalStatusCount -ne $TotalTasks) {
        Write-Warning "Task status counts ($TotalStatusCount) don't match total tasks ($TotalTasks). This may indicate a problem with task status values."
        Write-Warning "Todo: $TodoCount, InProgress: $InProgressCount, Done: $DoneCount"

        # Force recounting by folder location as a fallback
        $TodoPath = "project planning/todo"
        $InProgressPath = "project planning/inprogress"
        $DonePath = "project planning/done"

        $TodoCount = (Get-ChildItem -Path $TodoPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $InProgressCount = (Get-ChildItem -Path $InProgressPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $DoneCount = (Get-ChildItem -Path $DonePath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count

        Write-Host "Recounted by folder: Todo: $TodoCount, InProgress: $InProgressCount, Done: $DoneCount" -ForegroundColor Yellow
    }

    # Calculate completion rate correctly
    $CompletionRate = if ($TotalTasks -gt 0) { [math]::Round(($DoneCount / $TotalTasks) * 100) } else { 0 }

    # Ensure completion rate is not greater than 100%
    if ($CompletionRate -gt 100) {
        Write-Warning "Calculated completion rate ($CompletionRate%) exceeds 100%. Setting to 100%."
        $CompletionRate = 100
    }

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

# Function to update README.md with project metadata
function Update-ReadmeMetadata {
    param (
        [hashtable]$ProjectStats,
        [array]$AllTasks
    )

    $ReadmePath = "README.md"
    if (-not (Test-Path -Path $ReadmePath)) {
        Write-Warning "README.md not found, skipping metadata update"
        return $false
    }

    try {
        $ReadmeContent = Get-Content -Path $ReadmePath -Raw -Encoding UTF8 -ErrorAction Stop

        # Create metadata section
        $MetadataSection = "## 📊 Project Metadata`n" +
                           "- **Last Updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n" +
                           "- **Total Tasks:** $($ProjectStats.TotalTasks)`n" +
                           "- **Todo Tasks:** $($ProjectStats.TodoCount)`n" +
                           "- **In Progress Tasks:** $($ProjectStats.InProgressCount)`n" +
                           "- **Done Tasks:** $($ProjectStats.DoneCount)`n" +
                           "- **Completion Rate:** $($ProjectStats.CompletionRate)%`n" +
                           "- **Estimated Hours:** $($ProjectStats.TotalEstimatedHours)`n" +
                           "- **Hours Logged:** $($ProjectStats.TotalActualHours)`n"

        # Get the last task if there are any tasks
        if ($ProjectStats.TotalTasks -gt 0) {
            $LastTask = $AllTasks | Sort-Object -Property {
                if ($_.ID -match "TASK-(\d+)") {
                    [int]$matches[1]
                } else {
                    0
                }
            } -Descending | Select-Object -First 1

            $MetadataSection += "- **Last Task:** $($LastTask.ID) - $($LastTask.Title)`n"
        }

        # Check if metadata section already exists
        if ($ReadmeContent -match "## 📊 Project Metadata\r?\n") {
            # Update existing metadata section
            $ReadmeContent = $ReadmeContent -replace "## 📊 Project Metadata\r?\n((?:- \*\*.*\r?\n)+)", "$MetadataSection"
        } else {
            # Add metadata section after the title and description
            $TitleAndDescriptionPattern = "# .*?\r?\n\r?\n.*?\r?\n\r?\n"
            if ($ReadmeContent -match $TitleAndDescriptionPattern) {
                $MatchLength = $matches[0].Length
                $InsertPosition = $matches[0].Length
                $ReadmeContent = $ReadmeContent.Insert($InsertPosition, "$MetadataSection`n")
            } else {
                # If pattern not found, add after the first line
                $FirstLineEnd = $ReadmeContent.IndexOf("`n") + 1
                $ReadmeContent = $ReadmeContent.Insert($FirstLineEnd, "`n$MetadataSection`n")
            }
        }

        # Save updated README.md
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($ReadmePath, $ReadmeContent, $Utf8NoBomEncoding)

        if (-not $Silent) {
            Write-Host "README.md metadata has been updated successfully!" -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Error "Failed to update README.md metadata: $($_.Exception.Message)"
        return $false
    }
}

function Update-PlanFile {
    $TaskData = Get-AllTasks
    $AllTasks = $TaskData.Tasks
    $ProjectStats = Get-ProjectStats -AllTasks $AllTasks
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"
    $PlanTemplatePath = "project templates/plan-template.md"

    if (-not (Test-Path -Path $PlanTemplatePath)) {
        Write-Error "Plan template not found at $PlanTemplatePath"
        return $false
    }

    try {
        $PlanContent = Get-Content -Path $PlanTemplatePath -Raw -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to read plan template: $($_.Exception.Message)"
        return $false
    }

    # Populate placeholders
    $PlanContent = $PlanContent -replace '\{\{ProjectName\}\}', "Project Plan" # Or use a variable

    # Debug output to verify the values
    if (-not $Silent) {
        Write-Host "Debug - Task Stats:" -ForegroundColor Yellow
        Write-Host "Total Tasks: $($ProjectStats.TotalTasks)" -ForegroundColor Yellow
        Write-Host "Todo Count: $($ProjectStats.TodoCount)" -ForegroundColor Yellow
        Write-Host "In Progress Count: $($ProjectStats.InProgressCount)" -ForegroundColor Yellow
        Write-Host "Done Count: $($ProjectStats.DoneCount)" -ForegroundColor Yellow
        Write-Host "Completion Rate: $($ProjectStats.CompletionRate)%" -ForegroundColor Yellow
    }

    # Ensure we're using the correct values
    $PlanContent = $PlanContent -replace '\{\{TotalTasks\}\}', $ProjectStats.TotalTasks
    $PlanContent = $PlanContent -replace '\{\{DoneCount\}\}', $ProjectStats.DoneCount
    $PlanContent = $PlanContent -replace '\{\{InProgressCount\}\}', $ProjectStats.InProgressCount
    $PlanContent = $PlanContent -replace '\{\{TodoCount\}\}', $ProjectStats.TodoCount
    $PlanContent = $PlanContent -replace '\{\{CompletionRate\}\}', $ProjectStats.CompletionRate
    $PlanContent = $PlanContent -replace '\{\{TotalEstimatedHours\}\}', $ProjectStats.TotalEstimatedHours
    $PlanContent = $PlanContent -replace '\{\{TotalActualHours\}\}', $ProjectStats.TotalActualHours
    $PlanContent = $PlanContent -replace '\{\{CurrentDate\}\}', $CurrentDate

    # Kanban Tasks
    $KanbanTodoTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusTodo } | Sort-Object -Property Sequence) | ForEach-Object {
        # Combine task details and metadata into a single task block
        $TaskContent = "$($_.ID) - $($_.Title)`nPriority: $($_.Priority) | Due: $($_.DueDate) | Assigned: $($_.AssignedTo) | Progress: $($_.Progress)%"
        $KanbanTodoTasks += "        task-$($_.ID)[$TaskContent]`n" # Use task ID as identifier and combine details in one block
    }
    $EscapedKanbanTodoTasks = $KanbanTodoTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanTodoTasks\}\}', $EscapedKanbanTodoTasks

    $KanbanInProgressTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress } | Sort-Object -Property Sequence) | ForEach-Object {
        # Combine task details and metadata into a single task block
        $TaskContent = "$($_.ID) - $($_.Title)`nPriority: $($_.Priority) | Due: $($_.DueDate) | Assigned: $($_.AssignedTo) | Progress: $($_.Progress)%"
        $KanbanInProgressTasks += "        task-$($_.ID)[$TaskContent]`n" # Use task ID as identifier and combine details in one block
    }
    $EscapedKanbanInProgressTasks = $KanbanInProgressTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanInProgressTasks\}\}', $EscapedKanbanInProgressTasks

    $KanbanDoneTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusDone } | Sort-Object -Property Sequence) | ForEach-Object {
        # Combine task details and metadata into a single task block
        $TaskContent = "$($_.ID) - $($_.Title)`nPriority: $($_.Priority) | Due: $($_.DueDate) | Assigned: $($_.AssignedTo) | Progress: 100%"
        $KanbanDoneTasks += "        task-$($_.ID)[$TaskContent]`n" # Use task ID as identifier and combine details in one block
    }
    $EscapedKanbanDoneTasks = $KanbanDoneTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanDoneTasks\}\}', $EscapedKanbanDoneTasks

    # Task Summary Table Rows
    $TaskSummaryTableRows = ""
    ($AllTasks | Sort-Object -Property Sequence) | ForEach-Object {
        $StatusIcon = switch ($_.Status) {
            $TaskStatusTodo       { "Todo" }
            $TaskStatusInProgress { "In Progress" }
            $TaskStatusDone       { "Done" }
            default               { "Unknown" }
        }
        $TaskSummaryTableRows += "| $($_.ID) | $StatusIcon | $($_.Title) | $($_.Priority) | $($_.DueDate) | $($_.AssignedTo) | $($_.Progress)% |`n"
    }
    $EscapedTaskSummaryTableRows = $TaskSummaryTableRows.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{TaskSummaryTableRows\}\}', $EscapedTaskSummaryTableRows

    # Task Dependencies Table Rows
    $TaskDependenciesTableRows = ""
    ($AllTasks | Sort-Object -Property Sequence) | ForEach-Object {
        $TaskDependenciesTableRows += "| $($_.ID) | $($_.Title) | $($_.DependsOn) | $($_.RequiredBy) |`n"
    }
    $EscapedTaskDependenciesTableRows = $TaskDependenciesTableRows.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{TaskDependenciesTableRows\}\}', $EscapedTaskDependenciesTableRows

    # Timeline Entries
    $TimelineEntries = ""
    # Group tasks by month based on due date
    $TasksByMonth = @{}
    $CurrentYearForTimeline = (Get-Date).Year

    foreach ($Task in $AllTasks) {
        $DueDateObj = $null
        $Year = $CurrentYearForTimeline
        $Month = "Unknown"
        try {
            if ($Task.DueDate -and [DateTime]::TryParse($Task.DueDate, [ref]$DueDateObj)) {
                $Year = $DueDateObj.Year
                $Month = $DueDateObj.ToString("MMMM")
            } else { $Month = (Get-Date).ToString("MMMM") }
        } catch { $Month = (Get-Date).ToString("MMMM") }

        if (-not $TasksByMonth.ContainsKey($Year)) { $TasksByMonth[$Year] = @{} }
        if (-not $TasksByMonth[$Year].ContainsKey($Month)) { $TasksByMonth[$Year][$Month] = @() }
        $TasksByMonth[$Year][$Month] += $Task
    }

    foreach ($Year in $TasksByMonth.Keys | Sort-Object) {
        $TimelineEntries += "    section $Year`n"
        foreach ($Month in $TasksByMonth[$Year].Keys | ForEach-Object {
            $MonthNumber = switch ($_) { "January"{"01"}; "February"{"02"}; "March"{"03"}; "April"{"04"}; "May"{"05"}; "June"{"06"}; "July"{"07"}; "August"{"08"}; "September"{"09"}; "October"{"10"}; "November"{"11"}; "December"{"12"}; default{"13"}}
            [PSCustomObject]@{ Name = $_; SortOrder = $MonthNumber }
        } | Sort-Object -Property SortOrder | Select-Object -ExpandProperty Name) {
            $FirstTaskInMonth = $true
            foreach ($Task in $TasksByMonth[$Year][$Month] | Sort-Object -Property @{Expression={switch($_.Status){$TaskStatusDone{1} $TaskStatusInProgress{2} $TaskStatusTodo{3} default{4}}}}, Sequence) {
                $TaskStatusText = switch($Task.Status) {$TaskStatusTodo{"Todo"} $TaskStatusInProgress{"In Progress"} $TaskStatusDone{"Done"} default{"Unknown"}}
                if ($FirstTaskInMonth) {
                    $TimelineEntries += "        $Month : $($Task.ID) - $($Task.Title) ($TaskStatusText)`n"
                    $FirstTaskInMonth = $false
                } else {
                    $TimelineEntries += "               : $($Task.ID) - $($Task.Title) ($TaskStatusText)`n"
                }
            }
        }
    }
    $PlanContent = $PlanContent -replace '\{\{TimelineEntries\}\}', $TimelineEntries.TrimEnd().Replace('$', '$$')

    # Recent Updates
    $ExistingUpdates = ""
    if (Test-Path "plan.md") {
        try {
            $CurrentPlanContent = Get-Content -Path "plan.md" -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($CurrentPlanContent -match "## 🔄 Recent Updates\r?\n((?:- .*\r?\n)+)- \d{4}-\d{2}-\d{2} - Plan updated.") { # Match existing updates excluding the last "Plan updated"
                 # Capture all lines starting with '-' under "Recent Updates"
                if ($CurrentPlanContent -match "## 🔄 Recent Updates\r?\n((?:- .*\r?\n)*?)(?=- \d{4}-\d{2}-\d{2} - Plan updated\.|\Z)") {
                    $CapturedUpdates = $matches[1]
                    # Ensure we only take lines that are actual update entries
                    $UpdateLines = $CapturedUpdates -split '\r?\n' | Where-Object {$_ -match "^\s*- .+"}
                    $ExistingUpdates = ($UpdateLines -join "`n").Trim()
                    if ($ExistingUpdates) {
                        $ExistingUpdates += "`n" # Add newline if there were existing updates
                    }
                }
            }
        } catch { Write-Warning "Could not read existing plan.md for updates: $($_.Exception.Message)" }
    }
    $EscapedExistingUpdates = $ExistingUpdates.Replace('$', '$$') # Escape $ here as well
    $PlanContent = $PlanContent -replace '\{\{RecentUpdates\}\}', $EscapedExistingUpdates

    # Save updated plan.md
    try {
        $FinalPlanContent = $PlanContent.Trim() + "`n" # Ensure a trailing newline
        # Create UTF8 encoding without BOM
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("plan.md", $FinalPlanContent, $Utf8NoBomEncoding)
        if (-not $Silent) {
            Write-Host "Plan.md has been updated successfully!" -ForegroundColor Green
        }

        # Update README.md with project metadata
        Update-ReadmeMetadata -ProjectStats $ProjectStats -AllTasks $AllTasks

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

# Function to update task status and move to appropriate folder
function Set-TaskStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskID,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Todo", "InProgress", "Done")]
        [string]$NewStatus
    )

    # Initialize required folders
    Initialize-RequiredFolders

    # Define folder paths
    $TodoPath = "project planning/todo"
    $InProgressPath = "project planning/inprogress"
    $DonePath = "project planning/done"

    # Find the task file across all folders
    $TaskFile = $null
    $AllFolders = @($TodoPath, $InProgressPath, $DonePath)

    foreach ($Folder in $AllFolders) {
        $PotentialFile = Get-ChildItem -Path $Folder -Filter "$TaskID*.md" -ErrorAction SilentlyContinue
        if ($PotentialFile) {
            $TaskFile = $PotentialFile
            break
        }
    }

    if (-not $TaskFile) {
        Write-Error "Task $TaskID not found in any folder."
        return $false
    }

    try {
        # Read the task content
        $TaskContent = Get-Content -Path $TaskFile.FullName -Raw -ErrorAction Stop

        # Update the status in the content
        $UpdatedContent = $TaskContent -replace "- \*\*Status:\*\* (?:Todo|InProgress|Done)", "- **Status:** $NewStatus"

        # Determine the target folder based on the new status
        $TargetFolder = switch ($NewStatus) {
            "Todo" { $TodoPath }
            "InProgress" { $InProgressPath }
            "Done" { $DonePath }
        }

        # Create the target path
        $TargetPath = Join-Path -Path $TargetFolder -ChildPath $TaskFile.Name

        # Write the updated content to the file
        Set-Content -Path $TaskFile.FullName -Value $UpdatedContent -ErrorAction Stop

        # Move the file to the appropriate folder if it's not already there
        if ($TaskFile.DirectoryName -ne (Resolve-Path $TargetFolder).Path) {
            Move-Item -Path $TaskFile.FullName -Destination $TargetPath -Force -ErrorAction Stop
            if (-not $Silent) {
                Write-Host "Task $TaskID moved to $TargetFolder" -ForegroundColor Green
            }
        }

        # Update the plan.md file
        Update-PlanFile

        if (-not $Silent) {
            Write-Host "Task $TaskID status updated to $NewStatus" -ForegroundColor Green
        }

        return $true
    }
    catch {
        Write-Error "Failed to update task status: $($_.Exception.Message)"
        return $false
    }
}

# Function to display task selection menu and update status
function Update-TaskMenu {
    param (
        [ValidateSet("Todo", "InProgress", "Done")]
        [string]$TargetStatus
    )

    Clear-Host

    # Get all tasks
    $AllTasks = Get-TaskList

    if ($AllTasks.Count -eq 0) {
        Write-Host "No tasks found." -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }

    # Display tasks
    Write-Host "Select a task to mark as $($TargetStatus):" -ForegroundColor Cyan
    Write-Host "ID | Current Status | Title" -ForegroundColor Cyan
    Write-Host "---------------------------" -ForegroundColor Cyan

    foreach ($Task in $AllTasks) {
        # Skip tasks that are already in the target status
        if (($TargetStatus -eq "Todo" -and $Task.Status -eq $TaskStatusTodo) -or
            ($TargetStatus -eq "InProgress" -and $Task.Status -eq $TaskStatusInProgress) -or
            ($TargetStatus -eq "Done" -and $Task.Status -eq $TaskStatusDone)) {
            continue
        }

        Write-Host "$($Task.ID) | $($Task.Status) | $($Task.Title)"
    }

    Write-Host "0 | Cancel and return to main menu" -ForegroundColor Yellow

    # Get user selection
    $SelectedTaskID = Read-Host "Enter task ID"

    if ($SelectedTaskID -eq "0") {
        return
    }

    # Validate the task ID
    $SelectedTask = $AllTasks | Where-Object { $_.ID -eq $SelectedTaskID }

    if (-not $SelectedTask) {
        Write-Host "Invalid task ID. Please try again." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    # Confirm the action
    $Confirmation = Read-Host "Are you sure you want to change the status of task $SelectedTaskID to $($TargetStatus)? (y/n)"

    if ($Confirmation -ne "y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }

    # Update the task status
    $Result = Set-TaskStatus -TaskID $SelectedTaskID -NewStatus $TargetStatus

    if ($Result) {
        Write-Host "Task $SelectedTaskID status updated to $TargetStatus successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Failed to update task status." -ForegroundColor Red
    }

    Read-Host "Press Enter to continue"
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
    Write-Host "7: Mark task as done" -ForegroundColor Green
    Write-Host "8: Move task to in-progress" -ForegroundColor Yellow
    Write-Host "9: Move task to todo" -ForegroundColor Blue
    Write-Host "10: Reset project (archive all tasks)" -ForegroundColor Red
    Write-Host "11: Exit" -ForegroundColor White
    Write-Host "=======================================" -ForegroundColor Cyan
}

# Main script logic
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptPath

# Initialize required folders
Initialize-RequiredFolders

# Check if any action-specific switch is present for direct execution
$IsActionSwitchPresent = $UpdatePlan.IsPresent -or $GenerateReport.IsPresent -or $ListTasks.IsPresent -or $ResetTasks.IsPresent -or $GenerateComprehensiveReport.IsPresent

if ($IsActionSwitchPresent) {
    # Direct action mode (verbosity controlled by $Silent switch within functions)
    if ($UpdatePlan.IsPresent) {
        Update-PlanFile
    }
    if ($GenerateReport.IsPresent) {
        New-ProjectReport -OutputPath $ReportPath # Uses $ReportPath from params
    }
    if ($GenerateComprehensiveReport.IsPresent) {
        New-ComprehensiveProjectPlanReport -OutputPath $ComprehensiveReportPath # Uses $ComprehensiveReportPath from params
    }
    if ($ListTasks.IsPresent) {
        # $TaskStatus and $AssignedTo are already available from params
        $TasksToListDirect = Get-TaskList -Status $TaskStatus -AssignedTo $AssignedTo
        Show-TaskList -Tasks $TasksToListDirect
    }
    if ($ResetTasks.IsPresent) {
        Reset-ProjectTasks -Force:$true # Force non-interactive reset for direct action
    }
    exit # Exit after performing specified actions
}

# Interactive mode (if no action switches were passed)
$exitLoop = $false # Renamed from $exit

while (-not $exitLoop) {
    Show-Menu
    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" {
            Update-PlanFile
            Read-Host "Press Enter to continue"
        }
        "2" {
            $InteractiveReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md" # Use a local var for interactive mode
            New-ProjectReport -OutputPath $InteractiveReportPath
            Read-Host "Press Enter to continue"
        }
        "3" {
            $AllTasksInteractive = Get-TaskList
            Show-TaskList -Tasks $AllTasksInteractive
            Read-Host "Press Enter to continue"
        }
        "4" {
            $OpenTasksInteractive = Get-TaskList -Status "open"
            Show-TaskList -Tasks $OpenTasksInteractive
            Read-Host "Press Enter to continue"
        }
        "5" {
            Clear-Host
            Write-Host "Select status to filter by:" -ForegroundColor Cyan
            Write-Host "1: Todo" -ForegroundColor White
            Write-Host "2: In Progress" -ForegroundColor White
            Write-Host "3: Done" -ForegroundColor White
            Write-Host "4: All" -ForegroundColor White

            $statusChoiceInteractive = Read-Host "Enter your choice"
            $statusToFilterInteractive = switch ($statusChoiceInteractive) {
                "1" { "todo" }
                "2" { "inprogress" }
                "3" { "done" }
                "4" { "all" }
                default { "all" }
            }

            $TasksByStatusInteractive = Get-TaskList -Status $statusToFilterInteractive
            Show-TaskList -Tasks $TasksByStatusInteractive
            Read-Host "Press Enter to continue"
        }
        "6" {
            $assigneeInteractive = Read-Host "Enter assignee name (or part of name)"
            $TasksByAssigneeInteractive = Get-TaskList -AssignedTo $assigneeInteractive
            Show-TaskList -Tasks $TasksByAssigneeInteractive
            Read-Host "Press Enter to continue"
        }
        "7" {
            # Mark task as done
            Update-TaskMenu -TargetStatus "Done"
        }
        "8" {
            # Move task to in-progress
            Update-TaskMenu -TargetStatus "InProgress"
        }
        "9" {
            # Move task to todo
            Update-TaskMenu -TargetStatus "Todo"
        }
        "10" {
            Reset-ProjectTasks # This will prompt if -Force is not used, which is fine for interactive
            Read-Host "Press Enter to continue"
        }
        "11" {
            $exitLoop = $true
        }
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Read-Host "Press Enter to continue" # Ensured quotes are correct
        }
    }
}
