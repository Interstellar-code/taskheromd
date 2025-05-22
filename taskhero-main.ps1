# Project Planning Management - TaskHero Main Script
# This script combines plan.md updating and reporting functionality with interactive and silent modes
# and provides AI-powered features

param (
    [switch]$Silent,
    [switch]$UpdatePlan,
    [switch]$GenerateReport,
    [switch]$ListTasks,
    [switch]$ResetTasks,
    [switch]$ArchiveDoneTasks,
    [string]$TaskStatus = "all",
    [string]$AssignedTo = "",
    [string]$ReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md",
    [switch]$GenerateComprehensiveReport,
    [string]$ComprehensiveReportPath = "project-comprehensive-report-$(Get-Date -Format 'yyyy-MM-dd').md",
    [switch]$ConfigureAI,
    [switch]$GenerateAIDocumentation,
    [string]$AIDocumentationPath = "project docs/ai-generated-documentation.md",
    [switch]$UseCodebaseForAIDoc,
    [switch]$GetAITaskSuggestions,
    [string]$TaskIDForSuggestions = ""
)

# Define constants
$TaskStatusTodo = "Todo"
$TaskStatusInProgress = "InProgress"
$TaskStatusDevDone = "DevDone"
$TaskStatusTesting = "Testing"
$TaskStatusDone = "Done"
$TaskStatusBacklog = "Backlog"

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

        $TotalCriteria += $CriteriaLines.Count
        $CompletedCriteria += ($CriteriaLines | Where-Object { $_ -match "- \[x\]" }).Count
    }

    # Check Implementation Steps with Checklists section
    if ($Content -match "## Implementation Steps with Checklists\r?\n((?:.|\r?\n)+?)(?:\r?\n##\s|$)") {
        $ChecklistSection = $matches[1]
        $ChecklistLines = $ChecklistSection -split "\r?\n" | Where-Object { $_ -match "- \[[ x]\]" }

        $TotalCriteria += $ChecklistLines.Count
        $CompletedCriteria += ($ChecklistLines | Where-Object { $_ -match "- \[x\]" }).Count
    }
    # Also check the old subtasks checklist section for backward compatibility
    elseif ($Content -match "## Subtasks Checklist\r?\n((?:- \[[ x]\].*\r?\n)+)") {
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

    # Extract task ID and title (stop at end of line)
    if ($Content -match "# Task: (TASK-\d+) - ([^\r\n]+)") {
        $Metadata.ID = $matches[1].Trim()
        $Metadata.Title = $matches[2].Trim()
    }

    # Extract metadata section (allow blank lines)
    if ($Content -match "## Metadata\r?\n((?:\r?\n|(?:- \*\*.*\r?\n))+)") {
        $MetadataSection = $matches[1]

        # Extract priority (stop at end of line)
        if ($MetadataSection -match "- \*\*Priority:\*\* ([^\r\n]+)") {
            $Metadata.Priority = $matches[1].Trim()
        }

        # Extract due date (stop at end of line)
        if ($MetadataSection -match "- \*\*Due:\*\* ([^\r\n]+)") {
            $Metadata.DueDate = $matches[1].Trim()
        }

        # Extract status (stop at end of line)
        if ($MetadataSection -match "- \*\*Status:\*\* ([^\r\n]+)") {
            $Metadata.Status = $matches[1].Trim()
        }

        # Extract assigned to (stop at end of line)
        if ($MetadataSection -match "- \*\*Assigned to:\*\* ([^\r\n]+)") {
            $Metadata.AssignedTo = $matches[1].Trim()
        }

        # Extract task type (stop at end of line)
        if ($MetadataSection -match "- \*\*Task Type:\*\* ([^\r\n]+)") {
            $Metadata.TaskType = $matches[1].Trim()
        }

        # Extract sequence (stop at end of line)
        if ($MetadataSection -match "- \*\*Sequence:\*\* ([^\r\n]+)") {
            $Metadata.Sequence = $matches[1].Trim()
        }

        # Extract tags (stop at end of line)
        if ($MetadataSection -match "- \*\*Tags:\*\* ([^\r\n]+)") {
            $Metadata.Tags = $matches[1].Trim()
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
    $DevDonePath = "project planning/devdone"
    $TestingPath = "project planning/testing"
    $DonePath = "project planning/done"
    $ArchivePath = "project planning/archive"
    $BacklogPath = "project planning/backlog"
    $TemplatesPath = "project templates"
    $DocsPath = "project docs"

    # Create folders if they don't exist
    $Folders = @($ProjectPlanningPath, $TodoPath, $InProgressPath, $DevDonePath, $TestingPath, $DonePath, $ArchivePath, $BacklogPath, $TemplatesPath, $DocsPath)

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

# Function to load settings from taskhero_settings.json is now in taskhero-ai-commands.ps1

# Function to save settings to taskhero_settings.json is now in taskhero-ai-commands.ps1

# Function to invoke OpenRouter API is now in taskhero-ai-commands.ps1

# Function to configure OpenRouter settings is now in taskhero-ai-commands.ps1

# Function to generate AI project documentation is now in taskhero-ai-commands.ps1

# Function to analyze codebase structure is now in taskhero-ai-commands.ps1

# Function to get AI suggestions for task improvement is now in taskhero-ai-commands.ps1

# Function to get all tasks
function Get-AllTasks {
    # Initialize required folders
    Initialize-RequiredFolders

    $TodoPath = "project planning/todo"
    $InProgressPath = "project planning/inprogress"
    $DevDonePath = "project planning/devdone"
    $TestingPath = "project planning/testing"
    $DonePath = "project planning/done"
    $BacklogPath = "project planning/backlog"

    $TodoTasks = if (Test-Path $TodoPath) { Get-ChildItem -Path $TodoPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $InProgressTasks = if (Test-Path $InProgressPath) { Get-ChildItem -Path $InProgressPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $DevDoneTasks = if (Test-Path $DevDonePath) { Get-ChildItem -Path $DevDonePath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $TestingTasks = if (Test-Path $TestingPath) { Get-ChildItem -Path $TestingPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $DoneTasks = if (Test-Path $DonePath) { Get-ChildItem -Path $DonePath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }
    $BacklogTasks = if (Test-Path $BacklogPath) { Get-ChildItem -Path $BacklogPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue } else { @() }

    $AllTasks = @()
    $TotalEstimatedHours = 0
    $TotalActualHours = 0

    # Process backlog tasks
    foreach ($Task in $BacklogTasks) {
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
            Status = $TaskStatusBacklog
            AssignedTo = $Metadata.AssignedTo
            TaskType = $Metadata.TaskType
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
            TaskType = $Metadata.TaskType
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
            TaskType = $Metadata.TaskType
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

    # Process dev done tasks
    foreach ($Task in $DevDoneTasks) {
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
            Status = $TaskStatusDevDone
            AssignedTo = $Metadata.AssignedTo
            TaskType = $Metadata.TaskType
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

    # Process testing tasks
    foreach ($Task in $TestingTasks) {
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
            Status = $TaskStatusTesting
            AssignedTo = $Metadata.AssignedTo
            TaskType = $Metadata.TaskType
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
            TaskType = $Metadata.TaskType
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

    # Task status verification (silently)
    # No debug output

    # Clear counters for task statuses
    $TodoCount = 0
    $InProgressCount = 0
    $DevDoneCount = 0
    $TestingCount = 0
    $DoneCount = 0
    $BacklogCount = 0

    # Ensure we're using the correct status values
    foreach ($Task in $AllTasks) {
        if ($Task.Status -eq $TaskStatusTodo) {
            $TodoCount++
        }
        elseif ($Task.Status -eq $TaskStatusInProgress) {
            $InProgressCount++
        }
        elseif ($Task.Status -eq $TaskStatusDevDone) {
            $DevDoneCount++
        }
        elseif ($Task.Status -eq $TaskStatusTesting) {
            $TestingCount++
        }
        elseif ($Task.Status -eq $TaskStatusDone) {
            $DoneCount++
        }
        elseif ($Task.Status -eq $TaskStatusBacklog) {
            $BacklogCount++
        }
    }

    # Verify the counts add up to the total
    $TotalStatusCount = $TodoCount + $InProgressCount + $DevDoneCount + $TestingCount + $DoneCount + $BacklogCount
    if ($TotalStatusCount -ne $TotalTasks) {
        Write-Warning "Task status counts ($TotalStatusCount) don't match total tasks ($TotalTasks). This may indicate a problem with task status values."
        Write-Warning "Todo: $TodoCount, InProgress: $InProgressCount, DevDone: $DevDoneCount, Testing: $TestingCount, Done: $DoneCount, Backlog: $BacklogCount"

        # Force recounting by folder location as a fallback
        $TodoPath = "project planning/todo"
        $InProgressPath = "project planning/inprogress"
        $DevDonePath = "project planning/devdone"
        $TestingPath = "project planning/testing"
        $DonePath = "project planning/done"
        $BacklogPath = "project planning/backlog"

        $TodoCount = (Get-ChildItem -Path $TodoPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $InProgressCount = (Get-ChildItem -Path $InProgressPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $DevDoneCount = (Get-ChildItem -Path $DevDonePath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $TestingCount = (Get-ChildItem -Path $TestingPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $DoneCount = (Get-ChildItem -Path $DonePath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $BacklogCount = (Get-ChildItem -Path $BacklogPath -Filter "TASK-*.md" -ErrorAction SilentlyContinue).Count
        $TotalTasks = $TodoCount + $InProgressCount + $DevDoneCount + $TestingCount + $DoneCount + $BacklogCount
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
        DevDoneCount = $DevDoneCount
        TestingCount = $TestingCount
        DoneCount = $DoneCount
        BacklogCount = $BacklogCount
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
        $MetadataSection = "## Project Metadata`n" +
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
        if ($ReadmeContent -match "## Project Metadata\r?\n") {
            # Update existing metadata section
            $ReadmeContent = $ReadmeContent -replace "## Project Metadata\r?\n((?:- \*\*.*\r?\n)+)", "$MetadataSection"
        } else {
            # Add metadata section after the title and description
            $TitleAndDescriptionPattern = "# .*?\r?\n\r?\n.*?\r?\n\r?\n"
            if ($ReadmeContent -match $TitleAndDescriptionPattern) {
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

    # No debug output for stats

    # Ensure we're using the correct values
    $PlanContent = $PlanContent -replace '\{\{TotalTasks\}\}', $ProjectStats.TotalTasks
    $PlanContent = $PlanContent -replace '\{\{DoneCount\}\}', $ProjectStats.DoneCount
    $PlanContent = $PlanContent -replace '\{\{TestingCount\}\}', $ProjectStats.TestingCount
    $PlanContent = $PlanContent -replace '\{\{DevDoneCount\}\}', $ProjectStats.DevDoneCount
    $PlanContent = $PlanContent -replace '\{\{InProgressCount\}\}', $ProjectStats.InProgressCount
    $PlanContent = $PlanContent -replace '\{\{TodoCount\}\}', $ProjectStats.TodoCount
    $PlanContent = $PlanContent -replace '\{\{BacklogCount\}\}', $ProjectStats.BacklogCount
    $PlanContent = $PlanContent -replace '\{\{CompletionRate\}\}', $ProjectStats.CompletionRate
    $PlanContent = $PlanContent -replace '\{\{TotalEstimatedHours\}\}', $ProjectStats.TotalEstimatedHours
    $PlanContent = $PlanContent -replace '\{\{TotalActualHours\}\}', $ProjectStats.TotalActualHours
    $PlanContent = $PlanContent -replace '\{\{CurrentDate\}\}', $CurrentDate

    # Kanban Tasks
    $KanbanBacklogTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusBacklog } | Sort-Object -Property Sequence) | ForEach-Object {
        # Create simple task name for Mermaid Kanban syntax
        $TaskTitle = $_.Title
        # Escape special characters that might break Mermaid syntax
        $TaskTitle = $TaskTitle -replace '[[\](){}]', ''
        $TaskTitle = $TaskTitle -replace '["]', "'"

        # Format: Simple task name for Mermaid Kanban
        $FormattedTask = "    $($_.ID): $TaskTitle"
        $KanbanBacklogTasks += "$FormattedTask`n"
    }
    # Ensure it's not null before calling methods
    if ($null -eq $KanbanBacklogTasks) { $KanbanBacklogTasks = "" }
    $EscapedKanbanBacklogTasks = $KanbanBacklogTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanBacklogTasks\}\}', $EscapedKanbanBacklogTasks

    $KanbanTodoTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusTodo } | Sort-Object -Property Sequence) | ForEach-Object {
        # Create simple task name for Mermaid Kanban syntax
        $TaskTitle = $_.Title
        # Escape special characters that might break Mermaid syntax
        $TaskTitle = $TaskTitle -replace '[[\](){}]', ''
        $TaskTitle = $TaskTitle -replace '["]', "'"

        # Format: Simple task name for Mermaid Kanban
        $FormattedTask = "    $($_.ID): $TaskTitle"
        $KanbanTodoTasks += "$FormattedTask`n"
    }
    # Ensure it's not null before calling methods
    if ($null -eq $KanbanTodoTasks) { $KanbanTodoTasks = "" }
    $EscapedKanbanTodoTasks = $KanbanTodoTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanTodoTasks\}\}', $EscapedKanbanTodoTasks

    $KanbanInProgressTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusInProgress } | Sort-Object -Property Sequence) | ForEach-Object {
        # Create simple task name for Mermaid Kanban syntax
        $TaskTitle = $_.Title
        # Escape special characters that might break Mermaid syntax
        $TaskTitle = $TaskTitle -replace '[[\](){}]', ''
        $TaskTitle = $TaskTitle -replace '["]', "'"

        # Format: Simple task name for Mermaid Kanban
        $FormattedTask = "    $($_.ID): $TaskTitle"
        $KanbanInProgressTasks += "$FormattedTask`n"
    }
    # Ensure it's not null before calling methods
    if ($null -eq $KanbanInProgressTasks) { $KanbanInProgressTasks = "" }
    $EscapedKanbanInProgressTasks = $KanbanInProgressTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanInProgressTasks\}\}', $EscapedKanbanInProgressTasks

    $KanbanDevDoneTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusDevDone } | Sort-Object -Property Sequence) | ForEach-Object {
        # Create simple task name for Mermaid Kanban syntax
        $TaskTitle = $_.Title
        # Escape special characters that might break Mermaid syntax
        $TaskTitle = $TaskTitle -replace '[[\](){}]', ''
        $TaskTitle = $TaskTitle -replace '["]', "'"

        # Format: Simple task name for Mermaid Kanban
        $FormattedTask = "    $($_.ID): $TaskTitle"
        $KanbanDevDoneTasks += "$FormattedTask`n"
    }
    # Ensure it's not null before calling methods
    if ($null -eq $KanbanDevDoneTasks) { $KanbanDevDoneTasks = "" }
    $EscapedKanbanDevDoneTasks = $KanbanDevDoneTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanDevDoneTasks\}\}', $EscapedKanbanDevDoneTasks

    $KanbanTestingTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusTesting } | Sort-Object -Property Sequence) | ForEach-Object {
        # Create simple task name for Mermaid Kanban syntax
        $TaskTitle = $_.Title
        # Escape special characters that might break Mermaid syntax
        $TaskTitle = $TaskTitle -replace '[[\](){}]', ''
        $TaskTitle = $TaskTitle -replace '["]', "'"

        # Format: Simple task name for Mermaid Kanban
        $FormattedTask = "    $($_.ID): $TaskTitle"
        $KanbanTestingTasks += "$FormattedTask`n"
    }
    # Ensure it's not null before calling methods
    if ($null -eq $KanbanTestingTasks) { $KanbanTestingTasks = "" }
    $EscapedKanbanTestingTasks = $KanbanTestingTasks.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{KanbanTestingTasks\}\}', $EscapedKanbanTestingTasks

    $KanbanDoneTasks = ""
    ($AllTasks | Where-Object { $_.Status -eq $TaskStatusDone } | Sort-Object -Property Sequence) | ForEach-Object {
        # Create simple task name for Mermaid Kanban syntax
        $TaskTitle = $_.Title
        # Escape special characters that might break Mermaid syntax
        $TaskTitle = $TaskTitle -replace '[[\](){}]', ''
        $TaskTitle = $TaskTitle -replace '["]', "'"

        # Format: Simple task name for Mermaid Kanban
        $FormattedTask = "    $($_.ID): $TaskTitle"
        $KanbanDoneTasks += "$FormattedTask`n"
    }
    # Ensure it's not null before calling methods
    if ($null -eq $KanbanDoneTasks) { $KanbanDoneTasks = "" }
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

        # No debug output for tasks

        # Sanitize fields to remove newlines and problematic characters
        $CleanTitle = if ($_.Title) { $_.Title -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }
        $CleanTaskType = if ($_.TaskType) { $_.TaskType -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }
        $CleanPriority = if ($_.Priority) { $_.Priority -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }
        $CleanDueDate = if ($_.DueDate) { $_.DueDate -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }
        $CleanAssignedTo = if ($_.AssignedTo) { $_.AssignedTo -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }

        $TaskSummaryTableRows += "| $($_.ID) | $StatusIcon | $CleanTitle | $CleanTaskType | $CleanPriority | $CleanDueDate | $CleanAssignedTo | $($_.Progress)% |`n"
    }
    $EscapedTaskSummaryTableRows = $TaskSummaryTableRows.TrimEnd().Replace('$', '$$')
    $PlanContent = $PlanContent -replace '\{\{TaskSummaryTableRows\}\}', $EscapedTaskSummaryTableRows

    # Task Dependencies Table Rows
    $TaskDependenciesTableRows = ""
    ($AllTasks | Sort-Object -Property Sequence) | ForEach-Object {
        # Sanitize fields to remove newlines and problematic characters
        $CleanTitle = if ($_.Title) { $_.Title -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }
        $CleanDependsOn = if ($_.DependsOn) { $_.DependsOn -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }
        $CleanRequiredBy = if ($_.RequiredBy) { $_.RequiredBy -replace '\r?\n', ' ' -replace '\|', '-' } else { "" }

        $TaskDependenciesTableRows += "| $($_.ID) | $CleanTitle | $CleanDependsOn | $CleanRequiredBy |`n"
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

# Function to archive done tasks
function Archive-DoneTasks {
    param (
        [switch]$Force
    )

    # Confirm with user unless Force is specified
    if (-not $Force -and -not $Silent) {
        $confirmation = Read-Host "This will move all done tasks to the archive folder. Are you sure? (y/n)"
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

    # Get all done tasks
    $TaskData = Get-AllTasks
    $DoneTasks = $TaskData.Tasks | Where-Object { $_.Status -eq $TaskStatusDone }

    if ($DoneTasks.Count -eq 0) {
        if (-not $Silent) {
            Write-Host "No done tasks found to archive." -ForegroundColor Yellow
        }
        return $true
    }

    $ArchivedCount = 0
    $ErrorCount = 0

    # Move all done tasks to archive
    foreach ($Task in $DoneTasks) {
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

    # Update plan.md to reflect changes
    try {
        Update-PlanFile
    }
    catch {
        Write-Error "Failed to update plan.md after archiving tasks: $($_.Exception.Message)"
    }

    if (-not $Silent) {
        Write-Host "Archiving complete." -ForegroundColor Green
        Write-Host "Archived $ArchivedCount done tasks to $ArchiveDateFolder" -ForegroundColor Green
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
        "devdone" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusDevDone } }
        "testing" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusTesting } }
        "done" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusDone } }
        "backlog" { $AllTasks | Where-Object { $_.Status -eq $TaskStatusBacklog } }
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
        [ValidateSet("Todo", "InProgress", "DevDone", "Testing", "Done", "Backlog")]
        [string]$NewStatus
    )

    # Initialize required folders
    Initialize-RequiredFolders

    # Define folder paths
    $TodoPath = "project planning/todo"
    $InProgressPath = "project planning/inprogress"
    $DevDonePath = "project planning/devdone"
    $TestingPath = "project planning/testing"
    $DonePath = "project planning/done"
    $BacklogPath = "project planning/backlog"

    # Find the task file across all folders
    $TaskFile = $null
    $AllFolders = @($TodoPath, $InProgressPath, $DevDonePath, $TestingPath, $DonePath, $BacklogPath)

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
        $UpdatedContent = $TaskContent -replace "- \*\*Status:\*\* (?:Todo|InProgress|DevDone|Testing|Done|Backlog)", "- **Status:** $NewStatus"

        # Determine the target folder based on the new status
        $TargetFolder = switch ($NewStatus) {
            "Todo" { $TodoPath }
            "InProgress" { $InProgressPath }
            "DevDone" { $DevDonePath }
            "Testing" { $TestingPath }
            "Done" { $DonePath }
            "Backlog" { $BacklogPath }
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
        [ValidateSet("Todo", "InProgress", "DevDone", "Testing", "Done", "Backlog")]
        [string]$TargetStatus
    )

    Clear-Host

    # Get all tasks
    $AllTasks = Get-TaskList

    if ($AllTasks.Count -eq 0) {
        Write-Host "No tasks found." -ForegroundColor Yellow
        Start-Sleep -Seconds 2 # Show message briefly
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
            ($TargetStatus -eq "DevDone" -and $Task.Status -eq $TaskStatusDevDone) -or
            ($TargetStatus -eq "Testing" -and $Task.Status -eq $TaskStatusTesting) -or
            ($TargetStatus -eq "Done" -and $Task.Status -eq $TaskStatusDone) -or
            ($TargetStatus -eq "Backlog" -and $Task.Status -eq $TaskStatusBacklog)) {
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
        Start-Sleep -Seconds 2 # Show error message briefly
        return
    }

    # Confirm the action
    $Confirmation = Read-Host "Are you sure you want to change the status of task $SelectedTaskID to $($TargetStatus)? (y/n)"

    if ($Confirmation -ne "y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 2 # Show message briefly
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

    Show-CountdownTimer -Message "Returning to tasks menu"
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
        "$TaskStatusDevDone" = 0
        "$TaskStatusTesting" = 0
        "$TaskStatusDone" = 0
        "$TaskStatusBacklog" = 0
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
        elseif ($Task.Status -eq $TaskStatusDevDone) {
            $TaskStatusCounts["$TaskStatusDevDone"]++
        }
        elseif ($Task.Status -eq $TaskStatusTesting) {
            $TaskStatusCounts["$TaskStatusTesting"]++
        }
        elseif ($Task.Status -eq $TaskStatusDone) {
            $TaskStatusCounts["$TaskStatusDone"]++
        }
        elseif ($Task.Status -eq $TaskStatusBacklog) {
            $TaskStatusCounts["$TaskStatusBacklog"]++
        }
        else {
            $TaskStatusCounts["Other"]++
        }

        $StatusIcon = switch ($Task.Status) {
            $TaskStatusTodo { "[T]" }
            $TaskStatusInProgress { "[I]" }
            $TaskStatusDevDone { "[DD]" }
            $TaskStatusTesting { "[TS]" }
            $TaskStatusDone { "[D]" }
            $TaskStatusBacklog { "[B]" }
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
    if ($TaskStatusCounts["$TaskStatusTodo"] -gt 0) {
        Write-Host "  Todo: $($TaskStatusCounts["$TaskStatusTodo"])" -ForegroundColor White
    }
    if ($TaskStatusCounts["$TaskStatusBacklog"] -gt 0) {
        Write-Host "  Backlog: $($TaskStatusCounts["$TaskStatusBacklog"])" -ForegroundColor Blue
    }
    if ($TaskStatusCounts["$TaskStatusInProgress"] -gt 0) {
        Write-Host "  In Progress: $($TaskStatusCounts["$TaskStatusInProgress"])" -ForegroundColor Yellow
    }
    if ($TaskStatusCounts["$TaskStatusDevDone"] -gt 0) {
        Write-Host "  Dev Done: $($TaskStatusCounts["$TaskStatusDevDone"])" -ForegroundColor Cyan
    }
    if ($TaskStatusCounts["$TaskStatusTesting"] -gt 0) {
        Write-Host "  Testing: $($TaskStatusCounts["$TaskStatusTesting"])" -ForegroundColor Magenta
    }
    if ($TaskStatusCounts["$TaskStatusDone"] -gt 0) {
        Write-Host "  Done: $($TaskStatusCounts["$TaskStatusDone"])" -ForegroundColor Green
    }
    if ($TaskStatusCounts["Other"] -gt 0) {
        Write-Host "  Other: $($TaskStatusCounts["Other"])" -ForegroundColor Gray
    }
}

# Function to show interactive menu
function Show-Menu {
    Clear-Host
    Write-Host "===== Taskhero Project Manager =====" -ForegroundColor Cyan
    Write-Host "1: Update plan.md with current task statuses" -ForegroundColor White
    Write-Host "2: Generate project report" -ForegroundColor White
    Write-Host "3: TaskHero Tasks" -ForegroundColor White
    
    # Only show AI menu option if the functions are available
    if ($AIFunctionsAvailable) {
        Write-Host "4: AI Assistant" -ForegroundColor Magenta
    }
    
    Write-Host "5: Reset project (archive all tasks)" -ForegroundColor Red
    Write-Host "0: Exit" -ForegroundColor White
    Write-Host "=======================================" -ForegroundColor Cyan
}

# Function to display countdown timer before returning to menu
function Show-CountdownTimer {
    param (
        [Parameter(Mandatory=$false)]
        [int]$Seconds = 4,
        
        [Parameter(Mandatory=$false)]
        [string]$Message = "Returning to menu"
    )
    
    Write-Host ""
    for ($i = $Seconds; $i -gt 0; $i--) {
        Write-Host "$i... $Message" -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "`r                                          " -NoNewline
    }
    Write-Host ""
}

# Function to show TaskHero Tasks sub-menu
function Show-TasksMenu {
    Clear-Host
    Write-Host "===== TaskHero Tasks =====" -ForegroundColor Cyan
    Write-Host "1: List all tasks" -ForegroundColor White
    Write-Host "2: List open tasks (Todo + In Progress)" -ForegroundColor White
    Write-Host "3: List tasks by status" -ForegroundColor White
    Write-Host "4: List tasks by assignee" -ForegroundColor White
    Write-Host "5: Mark task as done" -ForegroundColor Green
    Write-Host "6: Move task to in-progress" -ForegroundColor Yellow
    Write-Host "7: Move task to todo" -ForegroundColor Blue
    Write-Host "8: Move task to backlog" -ForegroundColor Magenta
    Write-Host "9: Move task to dev-done" -ForegroundColor Cyan
    Write-Host "10: Move task to testing" -ForegroundColor Magenta
    Write-Host "11: Archive done tasks" -ForegroundColor Yellow
    Write-Host "0: Back to main menu" -ForegroundColor White
    Write-Host "=========================" -ForegroundColor Cyan
}

# Function to show AI Assistant sub-menu
function Show-AIMenu {
    Clear-Host
    Write-Host "===== AI Assistant =====" -ForegroundColor Magenta
    Write-Host "1: Configure AI Assistant" -ForegroundColor Magenta
    Write-Host "2: Generate AI project documentation (from tasks)" -ForegroundColor Magenta
    Write-Host "3: Generate AI project documentation (from codebase)" -ForegroundColor Magenta
    Write-Host "4: Get AI suggestions for task improvement" -ForegroundColor Magenta
    Write-Host "0: Back to main menu" -ForegroundColor White
    Write-Host "======================" -ForegroundColor Magenta
}

# Main script logic
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptPath

# Initialize required folders
Initialize-RequiredFolders

# Load the AI commands module
$AIModulePath = Join-Path -Path $ScriptPath -ChildPath "taskhero-ai-commands.ps1"

if (Test-Path $AIModulePath) {
    # Import the AI commands
    . $AIModulePath
} else {
    Write-Warning "AI commands module not found at $AIModulePath. AI features will not be available."
}

# Check if AI functions are available
$AIFunctionsAvailable = $null -ne (Get-Item -Path "Function:Set-OpenRouterSettings" -ErrorAction SilentlyContinue)

# No need to load settings here, they will be loaded on demand when needed

# Check if any action-specific switch is present for direct execution
$IsActionSwitchPresent = $UpdatePlan.IsPresent -or $GenerateReport.IsPresent -or $ListTasks.IsPresent -or $ResetTasks.IsPresent -or $ArchiveDoneTasks.IsPresent -or $GenerateComprehensiveReport.IsPresent -or $ConfigureAI.IsPresent -or $GenerateAIDocumentation.IsPresent -or $GetAITaskSuggestions.IsPresent

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
    if ($ArchiveDoneTasks.IsPresent) {
        Archive-DoneTasks -Force:$true # Force non-interactive archive for direct action
    }
    
    # Handle AI-related command-line parameters if the functions are available
    if ($AIFunctionsAvailable) {
        if ($ConfigureAI.IsPresent) {
            Set-OpenRouterSettings
        }
        if ($GenerateAIDocumentation.IsPresent) {
            New-AIGeneratedDocumentation -OutputPath $AIDocumentationPath -UseCodebase:$UseCodebaseForAIDoc
        }
        if ($GetAITaskSuggestions.IsPresent) {
            if ([string]::IsNullOrEmpty($TaskIDForSuggestions)) {
                Write-Error "TaskIDForSuggestions parameter is required when using GetAITaskSuggestions"
            } else {
                Get-AITaskSuggestions -TaskID $TaskIDForSuggestions
            }
        }
    } else {
        # Warn about AI features not being available
        if ($ConfigureAI.IsPresent -or $GenerateAIDocumentation.IsPresent -or $GetAITaskSuggestions.IsPresent) {
            Write-Warning "AI commands module not found. AI features are not available."
        }
    }
    
    exit # Exit after performing specified actions
}

# Interactive mode (if no action switches were passed)
$exitLoop = $false

while (-not $exitLoop) {
    Show-Menu
    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1" {
            Update-PlanFile
            Show-CountdownTimer -Message "Returning to main menu"
        }
        "2" {
            $InteractiveReportPath = "project-report-$(Get-Date -Format 'yyyy-MM-dd').md" # Use a local var for interactive mode
            New-ProjectReport -OutputPath $InteractiveReportPath
            Write-Host "`nPress Enter to return to main menu..." -ForegroundColor Cyan
            Read-Host | Out-Null
        }
        "3" {
            # Show TaskHero Tasks sub-menu
            $tasksExitLoop = $false
            while (-not $tasksExitLoop) {
                Show-TasksMenu
                $tasksChoice = Read-Host "Enter your choice"
                
                switch ($tasksChoice) {
                    "1" {
                        $AllTasksInteractive = Get-TaskList
                        Show-TaskList -Tasks $AllTasksInteractive
                        Write-Host "`nPress Enter to return to tasks menu..." -ForegroundColor Cyan
                        Read-Host | Out-Null
                    }
                    "2" {
                        $OpenTasksInteractive = Get-TaskList -Status "open"
                        Show-TaskList -Tasks $OpenTasksInteractive
                        Write-Host "`nPress Enter to return to tasks menu..." -ForegroundColor Cyan
                        Read-Host | Out-Null
                    }
                    "3" {
                        Clear-Host
                        Write-Host "Select status to filter by:" -ForegroundColor Cyan
                        Write-Host "1: Todo" -ForegroundColor White
                        Write-Host "2: In Progress" -ForegroundColor White
                        Write-Host "3: Dev Done" -ForegroundColor Cyan
                        Write-Host "4: Testing" -ForegroundColor Magenta
                        Write-Host "5: Done" -ForegroundColor Green
                        Write-Host "6: Backlog" -ForegroundColor Blue
                        Write-Host "7: All" -ForegroundColor White

                        $statusChoiceInteractive = Read-Host "Enter your choice"
                        $statusToFilterInteractive = switch ($statusChoiceInteractive) {
                            "1" { "todo" }
                            "2" { "inprogress" }
                            "3" { "devdone" }
                            "4" { "testing" }
                            "5" { "done" }
                            "6" { "backlog" }
                            "7" { "all" }
                            default { "all" }
                        }

                        $TasksByStatusInteractive = Get-TaskList -Status $statusToFilterInteractive
                        Show-TaskList -Tasks $TasksByStatusInteractive
                        Write-Host "`nPress Enter to return to tasks menu..." -ForegroundColor Cyan
                        Read-Host | Out-Null
                    }
                    "4" {
                        $assigneeInteractive = Read-Host "Enter assignee name (or part of name)"
                        $TasksByAssigneeInteractive = Get-TaskList -AssignedTo $assigneeInteractive
                        Show-TaskList -Tasks $TasksByAssigneeInteractive
                        Write-Host "`nPress Enter to return to tasks menu..." -ForegroundColor Cyan
                        Read-Host | Out-Null
                    }
                    "5" {
                        # Mark task as done
                        Update-TaskMenu -TargetStatus "Done"
                    }
                    "6" {
                        # Move task to in-progress
                        Update-TaskMenu -TargetStatus "InProgress"
                    }
                    "7" {
                        # Move task to todo
                        Update-TaskMenu -TargetStatus "Todo"
                    }
                    "8" {
                        # Move task to backlog
                        Update-TaskMenu -TargetStatus "Backlog"
                    }
                    "9" {
                        # Move task to dev-done
                        Update-TaskMenu -TargetStatus "DevDone"
                    }
                    "10" {
                        # Move task to testing
                        Update-TaskMenu -TargetStatus "Testing"
                    }
                    "11" {
                        Archive-DoneTasks # This will prompt if -Force is not used, which is fine for interactive
                        Show-CountdownTimer -Message "Returning to tasks menu"
                    }
                    "0" {
                        $tasksExitLoop = $true
                    }
                    default {
                        Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                        Start-Sleep -Seconds 2 # Show error message briefly
                    }
                }
            }
        }
        "4" {
            # Show AI Assistant sub-menu (only if AI functions are available)
            if ($AIFunctionsAvailable) {
                $aiExitLoop = $false
                while (-not $aiExitLoop) {
                    Show-AIMenu
                    $aiChoice = Read-Host "Enter your choice"
                    
                    switch ($aiChoice) {
                        "1" {
                            Set-OpenRouterSettings
                            Show-CountdownTimer -Message "Returning to AI menu"
                        }
                        "2" {
                            New-AIGeneratedDocumentation -UseCodebase:$false
                            Write-Host "`nPress Enter to return to AI menu..." -ForegroundColor Cyan
                            Read-Host | Out-Null
                        }
                        "3" {
                            New-AIGeneratedDocumentation -UseCodebase:$true
                            Write-Host "`nPress Enter to return to AI menu..." -ForegroundColor Cyan
                            Read-Host | Out-Null
                        }
                        "4" {
                            Clear-Host
                            Write-Host "=== Get AI Suggestions for Task ===" -ForegroundColor Cyan
                            
                            # Display tasks for selection
                            $OpenTasksForSuggestions = Get-TaskList -Status "open"
                            if ($OpenTasksForSuggestions.Count -eq 0) {
                                Write-Host "No open tasks found." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2 # Show message briefly
                                continue
                            }
                            
                            Show-TaskList -Tasks $OpenTasksForSuggestions
                            
                            $SelectedTaskID = Read-Host "Enter the Task ID to get AI suggestions for (e.g., TASK-123)"
                            
                            if ([string]::IsNullOrEmpty($SelectedTaskID)) {
                                Write-Host "No task selected. Returning to menu." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2 # Show message briefly
                                continue
                            }
                            
                            Get-AITaskSuggestions -TaskID $SelectedTaskID
                            Write-Host "`nPress Enter to return to AI menu..." -ForegroundColor Cyan
                            Read-Host | Out-Null
                        }
                        "0" {
                            $aiExitLoop = $true
                        }
                        default {
                            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                            Start-Sleep -Seconds 2 # Show error message briefly
                        }
                    }
                }
            } else {
                Write-Host "AI features are not available. Make sure taskhero-ai-commands.ps1 is in the same directory." -ForegroundColor Red
                Start-Sleep -Seconds 3 # Show error message for a bit longer
            }
        }
        "5" {
            Reset-ProjectTasks
            Show-CountdownTimer -Message "Returning to main menu"
        }
        "0" {
            $exitLoop = $true
        }
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2 # Show error message briefly
        }
    }
}


