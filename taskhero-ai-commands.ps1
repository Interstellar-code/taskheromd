# TaskHero AI Commands Module
# This script contains AI-related functionality for the TaskHero project management system

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

# Function to load settings from taskhero_settings.json
function Get-TaskHeroSettings {
    $SettingsPath = 'taskhero_settings.json'
    
    if (Test-Path $SettingsPath) {
        try {
            $Settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json
            return $Settings
        }
        catch {
            Write-Warning "Failed to load settings from $SettingsPath. Using default settings."
            # Return default settings if file can't be parsed
            return [PSCustomObject]@{
                openrouter = [PSCustomObject]@{
                    api_key = ''
                    site_url = ''
                    site_name = 'TaskHero'
                    model = 'openai/gpt-4o'
                }
                user_preferences = [PSCustomObject]@{
                    default_report_path = 'project-report-auto.md'
                    default_comprehensive_report_path = 'project-comprehensive-report-auto.md'
                }
            }
        }
    }
    else {
        # Create default settings file if it doesn't exist
        $DefaultSettings = @{
            openrouter = @{
                api_key = ''
                site_url = ''
                site_name = 'TaskHero'
                model = 'openai/gpt-4o'
            }
            user_preferences = @{
                default_report_path = 'project-report-auto.md'
                default_comprehensive_report_path = 'project-comprehensive-report-auto.md'
            }
        }
        
        $DefaultSettings | ConvertTo-Json -Depth 3 | Set-Content -Path $SettingsPath
        
        Write-Host "Created default settings file at $SettingsPath" -ForegroundColor Green
        
        return $DefaultSettings
    }
}

# Function to save settings to taskhero_settings.json
function Save-TaskHeroSettings {
    param (
        [Parameter(Mandatory=$true)]
        [PSObject]$Settings
    )
    
    $SettingsPath = 'taskhero_settings.json'
    
    try {
        $Settings | ConvertTo-Json -Depth 3 | Set-Content -Path $SettingsPath
        Write-Host "Settings saved successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to save settings: $($_.Exception.Message)"
        return $false
    }
}

# Function to invoke OpenRouter API
function Invoke-OpenRouterAPI {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserPrompt,
        
        [Parameter(Mandatory=$false)]
        [string]$SystemPrompt = "You are a helpful AI assistant for project management using TaskHero. You help with task organization, documentation, and project planning."
    )
    
    $Settings = Get-TaskHeroSettings
    
    if ([string]::IsNullOrEmpty($Settings.openrouter.api_key)) {
        Write-Error "OpenRouter API key is not set. Please configure it using the 'Configure AI Assistant' option in the menu."
        return $null
    }
    
    try {
        $Headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $($Settings.openrouter.api_key)"
        }
        
        # Add optional headers if they exist
        if (-not [string]::IsNullOrEmpty($Settings.openrouter.site_url)) {
            $Headers["HTTP-Referer"] = $Settings.openrouter.site_url
        }
        
        if (-not [string]::IsNullOrEmpty($Settings.openrouter.site_name)) {
            $Headers["X-Title"] = $Settings.openrouter.site_name
        }
        
        $Body = @{
            model = $Settings.openrouter.model
            messages = @(
                @{
                    role = "system"
                    content = $SystemPrompt
                },
                @{
                    role = "user"
                    content = $UserPrompt
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $Response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" -Method Post -Headers $Headers -Body $Body
        
        return $Response.choices[0].message.content
    }
    catch {
        Write-Error "Failed to call OpenRouter API: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            $ResponseBody = $_.ErrorDetails.Message
            Write-Error "Status Code: $StatusCode"
            Write-Error "Response: $ResponseBody"
        }
        return $null
    }
}

# Function to set OpenRouter settings
function Set-OpenRouterSettings {
    $Settings = Get-TaskHeroSettings
    
    Clear-Host
    Write-Host "=== OpenRouter API Configuration ===" -ForegroundColor Cyan
    Write-Host "Current settings:" -ForegroundColor Yellow
    Write-Host "API Key: $($Settings.openrouter.api_key -replace '.', '*')" -ForegroundColor White
    Write-Host "Site URL: $($Settings.openrouter.site_url)" -ForegroundColor White
    Write-Host "Site Name: $($Settings.openrouter.site_name)" -ForegroundColor White
    Write-Host "Default Model: $($Settings.openrouter.model)" -ForegroundColor White
    Write-Host ""
    
    $ApiKey = Read-Host "Enter your OpenRouter API Key (leave blank to keep current)"
    if (-not [string]::IsNullOrEmpty($ApiKey)) {
        $Settings.openrouter.api_key = $ApiKey
    }
    
    $SiteUrl = Read-Host "Enter your site URL for attribution (leave blank to keep current)"
    if (-not [string]::IsNullOrEmpty($SiteUrl)) {
        $Settings.openrouter.site_url = $SiteUrl
    }
    
    $SiteName = Read-Host "Enter your site name for attribution (leave blank to keep current)"
    if (-not [string]::IsNullOrEmpty($SiteName)) {
        $Settings.openrouter.site_name = $SiteName
    }
    
    $Model = Read-Host "Enter default model (e.g., openai/gpt-4o) (leave blank to keep current)"
    if (-not [string]::IsNullOrEmpty($Model)) {
        $Settings.openrouter.model = $Model
    }
    
    $Result = Save-TaskHeroSettings -Settings $Settings
    
    if ($Result) {
        Write-Host "OpenRouter settings updated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Failed to update OpenRouter settings." -ForegroundColor Red
    }
    
    Show-CountdownTimer -Message "Returning to AI menu"
}

# Function to analyze codebase structure and extract key information
function Get-CodebaseAnalysis {
    # Initialize result object
    $Result = @{
        Structure = ""
        Snippets = ""
    }
    
    Write-Host "Analyzing project codebase..." -ForegroundColor Cyan
    
    try {
        # Get directory structure (exclude certain folders like .git, node_modules, etc.)
        $Directories = Get-ChildItem -Directory -Recurse -Force | 
            Where-Object { $_.FullName -notmatch '(\\\.git|\\node_modules|\\bin|\\obj|\\\.vs|\\packages)' } | 
            Select-Object FullName
        
        # Get all code files (limiting to common code file extensions)
        $CodeFiles = Get-ChildItem -File -Recurse -Force -Include *.cs, *.js, *.ts, *.py, *.php, *.java, *.rb, *.go, *.cpp, *.h, *.c, *.html, *.css, *.sql |
            Where-Object { $_.FullName -notmatch '(\\\.git|\\node_modules|\\bin|\\obj|\\\.vs|\\packages)' } |
            Select-Object FullName, Name, Length, LastWriteTime
        
        # Format directory structure
        $Result.Structure = "Directory Structure:" + [Environment]::NewLine
        foreach ($Dir in $Directories) {
            $RelativePath = $Dir.FullName.Replace($PWD.Path, "").TrimStart("\\").TrimStart("/")
            if (-not [string]::IsNullOrEmpty($RelativePath)) {
                $Result.Structure += "- $RelativePath" + [Environment]::NewLine
            }
        }
        
        # Find the most important files (based on size, modification date, and name patterns)
        $ImportantFiles = $CodeFiles | 
            Where-Object { 
                $_.Name -match '(config|main|app|index|program|startup|database|schema|model|controller|service|repository|api)' -or 
                $_.Length -gt 10KB -or 
                $_.LastWriteTime -gt (Get-Date).AddDays(-7)
            } |
            Sort-Object -Property Length -Descending |
            Select-Object -First 15
        
        # Extract code snippets from important files
        $Result.Snippets = "Code Snippets from Key Files:" + [Environment]::NewLine
        foreach ($File in $ImportantFiles) {
            $RelativePath = $File.FullName.Replace($PWD.Path, "").TrimStart("\\").TrimStart("/")
            $Result.Snippets += [Environment]::NewLine + "## File: $RelativePath" + [Environment]::NewLine
            
            # Read file content
            $Content = Get-Content -Path $File.FullName -Raw -ErrorAction SilentlyContinue
            
            if ($Content) {
                # Extract file summary (first 50 lines max, but limited to 2000 characters)
                $ContentSummary = ($Content -split [Environment]::NewLine | Select-Object -First 50) -join [Environment]::NewLine
                if ($ContentSummary.Length -gt 2000) {
                    $ContentSummary = $ContentSummary.Substring(0, 2000) + "... (truncated)"
                }
                
                $Extension = [System.IO.Path]::GetExtension($File.Name).TrimStart('.')
                $CodeBlockStart = '```' + $Extension
                $CodeBlockEnd = '```'
                $CodeBlock = $CodeBlockStart + [Environment]::NewLine + $ContentSummary + [Environment]::NewLine + $CodeBlockEnd
                $Result.Snippets += $CodeBlock + [Environment]::NewLine
            }
            else {
                $Result.Snippets += "*(Unable to read file content)*" + [Environment]::NewLine
            }
        }
        
        # Add file counts by type
        $FileTypeCount = @{}
        foreach ($File in $CodeFiles) {
            $Extension = [System.IO.Path]::GetExtension($File.Name).ToLower()
            if (-not [string]::IsNullOrEmpty($Extension)) {
                if (-not $FileTypeCount.ContainsKey($Extension)) {
                    $FileTypeCount[$Extension] = 0
                }
                $FileTypeCount[$Extension]++
            }
        }
        
        $Result.Structure += [Environment]::NewLine + "File Types Summary:" + [Environment]::NewLine
        foreach ($Extension in $FileTypeCount.Keys | Sort-Object) {
            $Result.Structure += "- $Extension $($FileTypeCount[$Extension]) files" + [Environment]::NewLine
        }
    }
    catch {
        Write-Error "Error analyzing codebase: $($_.Exception.Message)"
        $Result.Structure += "Error occurred during codebase analysis." + [Environment]::NewLine
    }
    
    return $Result
}

# Function to generate AI project documentation
function New-AIGeneratedDocumentation {
    param (
        [Parameter(Mandatory=$false)]
        [string]$OutputPath = "project docs/ai-generated-documentation.md",
        
        [Parameter(Mandatory=$false)]
        [switch]$UseCodebase
    )
    
    if ($UseCodebase) {
        Write-Host "Analyzing codebase and generating AI documentation..." -ForegroundColor Cyan
        
        # Call the codebase analysis function
        $CodebaseAnalysis = Get-CodebaseAnalysis
        
        # Create prompt for AI including codebase analysis
        $PromptParts = @(
            "I need you to analyze this project's codebase and generate comprehensive technical documentation.",
            "",
            "Here's the codebase structure and key files:",
            $CodebaseAnalysis.Structure,
            "",
            "Here are snippets from important files:",
            $CodebaseAnalysis.Snippets,
            "",
            "Based on this information:",
            "1. Create a project overview and architecture description",
            "2. Identify the main components and their relationships",
            "3. Document the key functions and their purposes",
            "4. Explain how the components interact with each other",
            "5. Suggest any architectural improvements or best practices",
            "6. Format everything in Markdown with appropriate sections and code examples",
            "",
            "The documentation should be technical, clear, and focused on helping developers understand the project structure."
        )
        $AIPrompt = $PromptParts -join [Environment]::NewLine
    }
    else {
        Write-Host "Generating AI documentation based on project tasks..." -ForegroundColor Cyan
        
        # Get all tasks for analysis - this requires accessing the main script functions
        # We'll use a dynamic approach to get tasks
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
        $MainScriptPath = Join-Path -Path $ScriptPath -ChildPath "taskhero-main.ps1"
        
        if (Test-Path $MainScriptPath) {
            # Dot source the main script to access its functions
            . $MainScriptPath
            
            # Now we can call Get-AllTasks
            $TaskData = Get-AllTasks
            $AllTasks = $TaskData.Tasks
        }
        else {
            Write-Error "Main script not found at $MainScriptPath. Cannot get task data."
            return $false
        }
        
        # Prepare task data for AI
        $TaskSummary = ""
        foreach ($Task in $AllTasks) {
            $TaskSummary += "Task ID: $($Task.ID)" + [Environment]::NewLine
            $TaskSummary += "Title: $($Task.Title)" + [Environment]::NewLine
            $TaskSummary += "Status: $($Task.Status)" + [Environment]::NewLine
            $TaskSummary += "Priority: $($Task.Priority)" + [Environment]::NewLine
            $TaskSummary += "Progress: $($Task.Progress)%" + [Environment]::NewLine
            $TaskSummary += "Type: $($Task.TaskType)" + [Environment]::NewLine
            $TaskSummary += "Dependencies: $($Task.DependsOn)" + [Environment]::NewLine + [Environment]::NewLine
        }
        
        # Create prompt for AI
        $PromptParts = @(
            "I need you to analyze this project task data and generate a comprehensive technical documentation.",
            "",
            "Here's the task data:",
            $TaskSummary,
            "",
            "Based on this information:",
            "1. Create a project overview",
            "2. Identify the main components and their relationships",
            "3. Suggest any architectural patterns that might be appropriate",
            "4. Create a development roadmap based on task dependencies",
            "5. Identify potential risks and mitigation strategies",
            "6. Format everything in Markdown",
            "",
            "The documentation should be technical, clear, and focused on helping developers understand the project structure."
        )
        $AIPrompt = $PromptParts -join [Environment]::NewLine
    }
    
    try {
        $Documentation = Invoke-OpenRouterAPI -UserPrompt $AIPrompt
        
        if (-not [string]::IsNullOrEmpty($Documentation)) {
            # Ensure directory exists
            $OutputDir = Split-Path -Parent $OutputPath
            if (-not (Test-Path -Path $OutputDir)) {
                New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
            }
            
            # Add header with generation info
            $HeaderParts = @(
                "# AI-Generated Project Documentation",
                "*Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm")*",
                ""
            )
            $Header = $HeaderParts -join [Environment]::NewLine
            
            # Save to file
            $Header + $Documentation | Set-Content -Path $OutputPath
            
            Write-Host "AI-generated documentation saved to $OutputPath" -ForegroundColor Green
            Write-Host "`nPress Enter to continue..." -ForegroundColor Cyan
            Read-Host | Out-Null
            return $true
        }
        else {
            Write-Error "Failed to generate documentation: No content received from AI."
            return $false
        }
    }
    catch {
        Write-Error "Failed to generate documentation: $($_.Exception.Message)"
        return $false
    }
}

# Function to get AI suggestions for task improvement
function Get-AITaskSuggestions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskID
    )
    
    # This function requires access to the task files from the main script
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $MainScriptPath = Join-Path -Path $ScriptPath -ChildPath "taskhero-main.ps1"
    
    if (Test-Path $MainScriptPath) {
        # Dot source the main script to access its functions
        . $MainScriptPath
        
        # Initialize required folders from the main script
        Initialize-RequiredFolders
    }
    else {
        Write-Error "Main script not found at $MainScriptPath. Cannot access task files."
        return $false
    }
    
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
        
        # Create prompt for AI
        $PromptParts = @(
            "I need suggestions to improve this task. Here's the current task content:",
            "",
            $TaskContent,
            "",
            "Please provide specific suggestions for:",
            "1. How to clarify or improve the task description",
            "2. Additional acceptance criteria that might be missing",
            "3. Suggestions for implementation steps or approaches",
            "4. Any potential dependencies or risks that might not be captured",
            "5. How to break this down if it seems too large",
            "",
            "Format your response with clear section headings in Markdown."
        )
        $AIPrompt = $PromptParts -join [Environment]::NewLine
        
        $Suggestions = Invoke-OpenRouterAPI -UserPrompt $AIPrompt
        
        if (-not [string]::IsNullOrEmpty($Suggestions)) {
            Clear-Host
            Write-Host "=== AI Suggestions for Task $TaskID ===" -ForegroundColor Cyan
            Write-Host $Suggestions
            
            $SaveChoice = Read-Host "Would you like to save these suggestions to a file? (Y/N)"
            if ($SaveChoice -eq "Y" -or $SaveChoice -eq "y") {
                $SuggestionsPath = "project planning/suggestions-$TaskID-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
                
                # Add header with generation info
                $HeaderParts = @(
                    "# AI Suggestions for Task $TaskID",
                    "*Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm")*",
                    ""
                )
                $Header = $HeaderParts -join [Environment]::NewLine
                
                # Save to file
                $Header + $Suggestions | Set-Content -Path $SuggestionsPath
                
                Write-Host "Suggestions saved to $SuggestionsPath" -ForegroundColor Green
                Write-Host "`nPress Enter to continue..." -ForegroundColor Cyan
                Read-Host | Out-Null
            }
            
            return $true
        }
        else {
            Write-Error "Failed to generate suggestions: No content received from AI."
            return $false
        }
    }
    catch {
        Write-Error "Failed to generate suggestions: $($_.Exception.Message)"
        return $false
    }
}

# All functions are accessible when the script is dot-sourced
# No need for Export-ModuleMember since this is not a formal module
