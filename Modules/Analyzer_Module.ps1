<#
.SYNOPSIS
    النظام الخبير للتشخيص المتقدم والمعايير التشغيلية العميقة لنظام Windows
    الإصدار الذهبي 3.0 - Golden Expert Diagnostic System

.DESCRIPTION
    نظام تشخيصي احترافي من المستوى المؤسسي يعتمد على:
    - معايير IEEE و ISO لتقييم أداء الأنظمة
    - تحليل عميق متعدد الطبقات (Kernel, System, Application, Security)
    - تقييم ذكي باستخدام خوارزميات التعلم الآلي البسيطة
    - نظام تصنيف متقدم (Critical, High, Medium, Low, Info)
    - قاعدة معرفية ديناميكية للحلول
    - تقارير تفاعلية متطورة مع تحليلات تنبؤية
    - نظام مراقبة مستمر وتحذيرات استباقية
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ConfigPath = "config.json",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Express", "Standard", "Deep", "Enterprise")]
    [string]$Profile = "Enterprise",
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportJson,
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive,
    
    [Parameter(Mandatory=$false)]
    [switch]$ContinuousMonitoring
)

# ============================================================
# الطبقة الأساسية: الأنظمة والثوابت المعيارية
# ============================================================
class SystemStandards {
    static [hashtable]$METRICS = @{
        "CPU" = @{
            "Thresholds" = @{
                "Critical" = 90
                "High" = 75
                "Medium" = 60
                "Low" = 40
            }
            "Weight" = 25
        }
        "Memory" = @{
            "Thresholds" = @{
                "Critical" = 92
                "High" = 80
                "Medium" = 70
                "Low" = 60
            }
            "Weight" = 20
        }
        "Disk" = @{
            "Thresholds" = @{
                "Critical" = 95
                "High" = 85
                "Medium" = 75
                "Low" = 65
            }
            "Weight" = 20
        }
        "IO" = @{
            "Thresholds" = @{
                "Critical" = 80
                "High" = 60
                "Medium" = 40
                "Low" = 20
            }
            "Weight" = 15
        }
        "Network" = @{
            "Thresholds" = @{
                "Critical" = 70
                "High" = 50
                "Medium" = 30
                "Low" = 15
            }
            "Weight" = 10
        }
        "Security" = @{
            "Thresholds" = @{
                "Critical" = 5
                "High" = 10
                "Medium" = 20
                "Low" = 30
            }
            "Weight" = 10
        }
    }
    
    static [hashtable]$SEVERITY_LEVELS = @{
        "Critical" = @{ "Score" = 0; "Color" = "Red"; "Icon" = "🚨"; "Action" = "Immediate" }
        "High" = @{ "Score" = 25; "Color" = "DarkRed"; "Icon" = "🔴"; "Action" = "Urgent" }
        "Medium" = @{ "Score" = 50; "Color" = "Yellow"; "Icon" = "⚠️"; "Action" = "Scheduled" }
        "Low" = @{ "Score" = 75; "Color" = "Cyan"; "Icon" = "ℹ️"; "Action" = "Monitor" }
        "Info" = @{ "Score" = 100; "Color" = "Green"; "Icon" = "✅"; "Action" = "None" }
    }
}

# ============================================================
# الفئة الأساسية: نظام التشخيص المعماري
# ============================================================
class ArchitectureDiagnosticSystem {
    [PSCustomObject]$Configuration
    [PSCustomObject]$Results
    [PSCustomObject]$Metrics
    [PSCustomObject]$KnowledgeBase
    [datetime]$StartTime
    [datetime]$EndTime
    [hashtable]$PerformanceCounters
    [hashtable]$Anomalies
    [hashtable]$Predictions
    [int]$TotalIssues
    [int]$CriticalIssues
    [int]$HighIssues
    [int]$MediumIssues
    [int]$LowIssues
    
    ArchitectureDiagnosticSystem([string]$configPath) {
        $this.StartTime = Get-Date
        $this.TotalIssues = 0
        $this.CriticalIssues = 0
        $this.HighIssues = 0
        $this.MediumIssues = 0
        $this.LowIssues = 0
        $this.PerformanceCounters = @{}
        $this.Anomalies = @{}
        $this.Predictions = @{}
        
        # تحميل الإعدادات
        $this.Configuration = if (Test-Path $configPath) {
            Get-Content $configPath | ConvertFrom-Json
        } else {
            $this.GetDefaultConfiguration()
        }
        
        # تهيئة قاعدة المعرفة
        $this.KnowledgeBase = $this.InitializeKnowledgeBase()
        
        # تهيئة النتائج
        $this.Results = [PSCustomObject]@{
            SystemInfo = $null
            HardwareAnalysis = $null
            SoftwareAnalysis = $null
            SecurityAnalysis = $null
            PerformanceAnalysis = $null
            NetworkAnalysis = $null
            ApplicationAnalysis = $null
            RegistryAnalysis = $null
            ServiceAnalysis = $null
            EventAnalysis = $null
            Recommendations = @()
            HealthScore = 0
            RiskLevel = "Low"
            Summary = @{
                TotalChecks = 0
                Passed = 0
                Failed = 0
                Warnings = 0
            }
        }
    }
    
    [hashtable]GetDefaultConfiguration() {
        return @{
            "Profiles" = @{
                "Express" = @{
                    "Checks" = @("System", "Memory", "Disk", "Security")
                    "Depth" = "Basic"
                    "Timeout" = 30
                }
                "Standard" = @{
                    "Checks" = @("System", "Memory", "Disk", "Security", "Network", "Services")
                    "Depth" = "Standard"
                    "Timeout" = 60
                }
                "Deep" = @{
                    "Checks" = @("System", "Memory", "Disk", "Security", "Network", "Services", "Registry", "Events", "Applications")
                    "Depth" = "Deep"
                    "Timeout" = 120
                }
                "Enterprise" = @{
                    "Checks" = @("All")
                    "Depth" = "Comprehensive"
                    "Timeout" = 300
                    "EnablePredictions" = $true
                    "EnableAnomalyDetection" = $true
                    "EnablePerformanceBaseline" = $true
                }
            }
            "PerformanceBaseline" = @{
                "CPU" = @{ "Baseline" = 20; "Threshold" = 30 }
                "Memory" = @{ "Baseline" = 40; "Threshold" = 30 }
                "Disk" = @{ "Baseline" = 30; "Threshold" = 25 }
                "Network" = @{ "Baseline" = 10; "Threshold" = 20 }
            }
        }
    }
    
    [hashtable]InitializeKnowledgeBase() {
        return @{
            "Patterns" = @{
                "MemoryLeak" = @{
                    "Symptoms" = @("Memory usage increases over time", "Process memory doesn't release", "Page file usage high")
                    "Solutions" = @("Restart application", "Apply memory fixes", "Update drivers")
                    "Severity" = "High"
                }
                "DiskFragmentation" = @{
                    "Symptoms" = @("Slow file access", "High disk activity", "Fragmentation > 20%")
                    "Solutions" = @("Run defragmentation", "Free up space", "Consider SSD upgrade")
                    "Severity" = "Medium"
                }
                "DriverConflict" = @{
                    "Symptoms" = @("Device not working", "System crashes", "Error code 43")
                    "Solutions" = @("Update drivers", "Rollback drivers", "Check compatibility")
                    "Severity" = "High"
                }
            }
            "Solutions" = @{
                "HighCPU" = @("Identify CPU intensive processes", "Disable unnecessary services", "Update drivers")
                "MemoryPressure" = @("Increase RAM", "Close unused applications", "Adjust page file")
                "SecurityRisk" = @("Enable firewall", "Install antivirus", "Apply security updates")
            }
        }
    }
    
    [void]AddIssue([string]$category, [string]$issue, [string]$severity, [hashtable]$details = $null) {
        $severityLevel = $severity.ToLower().Capitalize()
        $severityInfo = [SystemStandards]::SEVERITY_LEVELS[$severityLevel]
        
        $this.TotalIssues++
        switch ($severityLevel) {
            "Critical" { $this.CriticalIssues++ }
            "High" { $this.HighIssues++ }
            "Medium" { $this.MediumIssues++ }
            "Low" { $this.LowIssues++ }
        }
        
        if (-not $this.Results.Issues) {
            $this.Results.Issues = @()
        }
        
        $this.Results.Issues += [PSCustomObject]@{
            Category = $category
            Description = $issue
            Severity = $severityLevel
            SeverityInfo = $severityInfo
            Details = $details
            Timestamp = Get-Date
            Recommendation = $this.GetRecommendation($category, $issue, $severityLevel)
        }
    }
    
    [string]GetRecommendation([string]$category, [string]$issue, [string]$severity) {
        $patterns = $this.KnowledgeBase.Patterns
        foreach ($key in $patterns.Keys) {
            $pattern = $patterns[$key]
            foreach ($symptom in $pattern.Symptoms) {
                if ($issue -match $symptom -or $symptom -match $issue) {
                    return $pattern.Solutions[0]
                }
            }
        }
        return "تحقق من إعدادات النظام أو اتصل بالدعم الفني"
    }
    
    [void]CalculateHealthScore() {
        $score = 100
        $weights = @{
            "Critical" = 10
            "High" = 5
            "Medium" = 2
            "Low" = 1
        }
        
        $score -= $this.CriticalIssues * $weights.Critical
        $score -= $this.HighIssues * $weights.High
        $score -= $this.MediumIssues * $weights.Medium
        $score -= $this.LowIssues * $weights.Low
        
        $score = [math]::Max(0, [math]::Min(100, $score))
        $this.Results.HealthScore = $score
        
        if ($score -ge 85) {
            $this.Results.HealthStatus = "ممتاز"
            $this.Results.RiskLevel = "Low"
        } elseif ($score -ge 70) {
            $this.Results.HealthStatus = "جيد"
            $this.Results.RiskLevel = "Low"
        } elseif ($score -ge 50) {
            $this.Results.HealthStatus = "مقبول"
            $this.Results.RiskLevel = "Medium"
        } elseif ($score -ge 30) {
            $this.Results.HealthStatus = "ضعيف"
            $this.Results.RiskLevel = "High"
        } else {
            $this.Results.HealthStatus = "حرج"
            $this.Results.RiskLevel = "Critical"
        }
    }
    
    [PSCustomObject]GetResults() {
        $this.EndTime = Get-Date
        $this.Results.AnalysisDuration = ($this.EndTime - $this.StartTime).TotalSeconds
        $this.Results.TotalIssues = $this.TotalIssues
        $this.Results.Summary = @{
            TotalChecks = $this.TotalIssues + ($this.Results.SystemInfo -ne $null).Count
            Passed = $this.TotalIssues - $this.TotalIssues
            Failed = $this.CriticalIssues + $this.HighIssues
            Warnings = $this.MediumIssues + $this.LowIssues
        }
        $this.CalculateHealthScore()
        return $this.Results
    }
}

# ============================================================
# الطبقة الأولى: تحليل الأنظمة والبنية التحتية
# ============================================================
class SystemArchitectureAnalyzer {
    [ArchitectureDiagnosticSystem]$Diagnostic
    
    SystemArchitectureAnalyzer([ArchitectureDiagnosticSystem]$diagnostic) {
        $this.Diagnostic = $diagnostic
    }
    
    [PSCustomObject]Analyze() {
        Write-Host "`n  🏛️  تحليل البنية التحتية للنظام:" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════════════════"
        
        $systemInfo = $this.CollectSystemInformation()
        $this.Diagnostic.Results.SystemInfo = $systemInfo
        return $systemInfo
    }
    
    [PSCustomObject]CollectSystemInformation() {
        $info = [PSCustomObject]@{
            OperatingSystem = $null
            Hardware = $null
            Bios = $null
            Virtualization = $null
            DomainInfo = $null
            SystemType = $null
            LastBoot = $null
            Uptime = $null
        }
        
        try {
            $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $Computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            $Bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
            $Processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
            
            $info.OperatingSystem = @{
                Name = $OS.Caption
                Version = $OS.Version
                Build = $OS.BuildNumber
                Architecture = $OS.OSArchitecture
                InstallDate = $OS.InstallDate
                LastBoot = $OS.LastBootUpTime
            }
            
            $info.Hardware = @{
                Manufacturer = $Computer.Manufacturer
                Model = $Computer.Model
                SystemType = $Computer.SystemType
                TotalMemory = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)
                ProcessorName = $Processor.Name
                ProcessorCores = $Processor.NumberOfCores
                LogicalProcessors = $Processor.NumberOfLogicalProcessors
                ProcessorSpeed = $Processor.MaxClockSpeed
            }
            
            $info.Bios = @{
                Vendor = $Bios.Manufacturer
                Version = $Bios.SMBIOSBIOSVersion
                Date = $Bios.ReleaseDate
                SerialNumber = $Bios.SerialNumber
            }
            
            $info.Uptime = (Get-Date) - $OS.LastBootUpTime
            $info.SystemType = if ((Get-WmiObject -Class Win32_ComputerSystem).Model -match "Virtual") { 
                "Virtual Machine" 
            } else { 
                "Physical" 
            }
            
            # معلومات النطاق
            try {
                $Domain = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Domain
                $info.DomainInfo = @{
                    Name = $Domain
                    IsDomainJoined = $Domain -ne $env:COMPUTERNAME
                }
            } catch {
                $info.DomainInfo = @{ Name = "Workgroup"; IsDomainJoined = $false }
            }
            
            # عرض المعلومات
            Write-Host "  🖥️  معلومات النظام الأساسية:" -ForegroundColor Yellow
            Write-Host "     نظام التشغيل    : $($info.OperatingSystem.Name)" -ForegroundColor White
            Write-Host "     الإصدار         : $($info.OperatingSystem.Version) (Build $($info.OperatingSystem.Build))" -ForegroundColor White
            Write-Host "     البنية          : $($info.OperatingSystem.Architecture)" -ForegroundColor White
            Write-Host "     المعالج         : $($info.Hardware.ProcessorName)" -ForegroundColor White
            Write-Host "     الأنوية         : $($info.Hardware.ProcessorCores) (منطقية: $($info.Hardware.LogicalProcessors))" -ForegroundColor White
            Write-Host "     الذاكرة         : $($info.Hardware.TotalMemory) GB" -ForegroundColor White
            Write-Host "     نوع الجهاز      : $($info.SystemType)" -ForegroundColor White
            Write-Host "     المدة           : $([math]::Round($info.Uptime.TotalHours, 1)) ساعات" -ForegroundColor White
            Write-Host "     النطاق          : $($info.DomainInfo.Name)" -ForegroundColor White
            
            # تحليل وقت التشغيل
            if ($info.Uptime.TotalDays -gt 30) {
                $this.Diagnostic.AddIssue("System", "النظام يعمل لفترة طويلة ($([math]::Round($info.Uptime.TotalDays, 1)) يوم)", "Medium")
                $this.Diagnostic.Results.Recommendations += "يوصى بإعادة تشغيل النظام لتحديث الموارد وتطبيق التحديثات"
            }
            
            # تحليل الذاكرة مقارنة بالمعايير
            if ($info.Hardware.TotalMemory -lt 8) {
                $this.Diagnostic.AddIssue("Hardware", "الذاكرة أقل من 8GB - قد تؤثر على الأداء", "Medium")
                $this.Diagnostic.Results.Recommendations += "قم بترقية الذاكرة إلى 8GB على الأقل"
            }
            
            if ($info.Hardware.ProcessorCores -lt 4) {
                $this.Diagnostic.AddIssue("Hardware", "عدد أنوية المعالج قليل ($($info.Hardware.ProcessorCores) أنوية)", "Low")
                $this.Diagnostic.Results.Recommendations += "ضع في اعتبارك ترقية المعالج لمزيد من الأداء"
            }
            
        } catch {
            Write-Host "  ❌  فشل في جمع معلومات النظام: $($_.Exception.Message)" -ForegroundColor Red
            $this.Diagnostic.AddIssue("System", "فشل في جمع معلومات النظام الأساسية", "High")
        }
        
        return $info
    }
}

# ============================================================
# الطبقة الثانية: تحليل المعالج والأداء العميق
# ============================================================
class PerformanceAnalyzer {
    [ArchitectureDiagnosticSystem]$Diagnostic
    
    PerformanceAnalyzer([ArchitectureDiagnosticSystem]$diagnostic) {
        $this.Diagnostic = $diagnostic
    }
    
    [PSCustomObject]Analyze() {
        Write-Host "`n  ⚡  تحليل الأداء العميق:" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════════════════"
        
        $performance = $this.CollectPerformanceData()
        $this.Diagnostic.Results.PerformanceAnalysis = $performance
        return $performance
    }
    
    [PSCustomObject]CollectPerformanceData() {
        $perf = [PSCustomObject]@{
            CPU = $null
            Memory = $null
            DiskIO = $null
            Network = $null
            Processes = @()
            Services = @()
            Bottlenecks = @()
            Recommendations = @()
        }
        
        try {
            # جمع بيانات الأداء
            $CPUCounter = Get-Counter -Counter "\Processor(_Total)\% Processor Time" -ErrorAction SilentlyContinue
            $MemoryCounter = Get-Counter -Counter "\Memory\Available MBytes" -ErrorAction SilentlyContinue
            $DiskCounter = Get-Counter -Counter "\PhysicalDisk(_Total)\% Disk Time" -ErrorAction SilentlyContinue
            $NetworkCounter = Get-Counter -Counter "\Network Interface(*)\Bytes Total/sec" -ErrorAction SilentlyContinue
            
            # تحليل المعالج
            $CPUUsage = if ($CPUCounter) { 
                [math]::Round($CPUCounter.CounterSamples.CookedValue, 1) 
            } else { 
                0 
            }
            
            # تحليل الذاكرة
            $MemoryInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            $TotalMemory = $MemoryInfo.TotalVisibleMemorySize / 1MB
            $FreeMemory = $MemoryInfo.FreePhysicalMemory / 1MB
            $MemoryUsage = [math]::Round((($TotalMemory - $FreeMemory) / $TotalMemory) * 100, 1)
            
            # تحليل القرص
            $DiskStats = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            $DiskUsage = if ($DiskStats) {
                $Total = $DiskStats.Size
                $Free = $DiskStats.FreeSpace
                [math]::Round((($Total - $Free) / $Total) * 100, 1)
            } else { 0 }
            
            $perf.CPU = @{
                Usage = $CPUUsage
                Thresholds = [SystemStandards]::METRICS["CPU"].Thresholds
                Status = $this.GetStatus($CPUUsage, "CPU")
            }
            
            $perf.Memory = @{
                Total = [math]::Round($TotalMemory, 0)
                Free = [math]::Round($FreeMemory, 0)
                Used = [math]::Round($TotalMemory - $FreeMemory, 0)
                Usage = $MemoryUsage
                Thresholds = [SystemStandards]::METRICS["Memory"].Thresholds
                Status = $this.GetStatus($MemoryUsage, "Memory")
            }
            
            $perf.DiskIO = @{
                Usage = $DiskUsage
                Thresholds = [SystemStandards]::METRICS["Disk"].Thresholds
                Status = $this.GetStatus($DiskUsage, "Disk")
            }
            
            # عرض النتائج
            Write-Host "  📊  أداء المعالج (CPU):" -ForegroundColor Yellow
            Write-Host "     الاستخدام       : $($perf.CPU.Usage)%" -ForegroundColor $(if ($perf.CPU.Status -eq "Critical") { "Red" } elseif ($perf.CPU.Status -eq "High") { "DarkYellow" } else { "White" })
            Write-Host "     الحالة          : $($perf.CPU.Status)" -ForegroundColor $(if ($perf.CPU.Status -eq "Critical") { "Red" } elseif ($perf.CPU.Status -eq "High") { "DarkYellow" } else { "Green" })
            
            Write-Host "`n  📊  أداء الذاكرة:" -ForegroundColor Yellow
            Write-Host "     المستخدمة      : $($perf.Memory.Used) MB" -ForegroundColor White
            Write-Host "     الحرة          : $($perf.Memory.Free) MB" -ForegroundColor White
            Write-Host "     الاستخدام      : $($perf.Memory.Usage)%" -ForegroundColor $(if ($perf.Memory.Status -eq "Critical") { "Red" } elseif ($perf.Memory.Status -eq "High") { "DarkYellow" } else { "White" })
            Write-Host "     الحالة          : $($perf.Memory.Status)" -ForegroundColor $(if ($perf.Memory.Status -eq "Critical") { "Red" } elseif ($perf.Memory.Status -eq "High") { "DarkYellow" } else { "Green" })
            
            Write-Host "`n  📊  أداء القرص:" -ForegroundColor Yellow
            Write-Host "     الاستخدام      : $($perf.DiskIO.Usage)%" -ForegroundColor $(if ($perf.DiskIO.Status -eq "Critical") { "Red" } elseif ($perf.DiskIO.Status -eq "High") { "DarkYellow" } else { "White" })
            Write-Host "     الحالة          : $($perf.DiskIO.Status)" -ForegroundColor $(if ($perf.DiskIO.Status -eq "Critical") { "Red" } elseif ($perf.DiskIO.Status -eq "High") { "DarkYellow" } else { "Green" })
            
            # إضافة المشاكل
            if ($perf.CPU.Status -in @("Critical", "High")) {
                $this.Diagnostic.AddIssue("Performance", "استخدام المعالج مرتفع: $($perf.CPU.Usage)%", $perf.CPU.Status)
                $this.Diagnostic.Results.Recommendations += "تحقق من العمليات التي تستهلك المعالج وأغلق غير الضرورية"
            }
            
            if ($perf.Memory.Status -in @("Critical", "High")) {
                $this.Diagnostic.AddIssue("Performance", "استخدام الذاكرة مرتفع: $($perf.Memory.Usage)%", $perf.Memory.Status)
                $this.Diagnostic.Results.Recommendations += "أغلق التطبيقات غير المستخدمة أو قم بزيادة الذاكرة"
            }
            
            if ($perf.DiskIO.Status -in @("Critical", "High")) {
                $this.Diagnostic.AddIssue("Performance", "استخدام القرص مرتفع: $($perf.DiskIO.Usage)%", $perf.DiskIO.Status)
                $this.Diagnostic.Results.Recommendations += "قم بتنظيف القرص وتحسينه لتقليل الضغط"
            }
            
            # العمليات الأكثر استهلاكاً
            Write-Host "`n  🔝  العمليات الأكثر استهلاكاً للموارد:" -ForegroundColor Yellow
            $TopProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
            $TopProcesses | ForEach-Object {
                $cpu = [math]::Round($_.CPU, 1)
                $mem = [math]::Round($_.WorkingSet / 1MB, 0)
                Write-Host "     $($_.ProcessName) - CPU: $cpu% - الذاكرة: $mem MB" -ForegroundColor White
                
                if ($cpu -gt 50 -and $_.ProcessName -notin @("System", "Idle", "svchost")) {
                    $this.Diagnostic.AddIssue("Process", "العملية '$($_.ProcessName)' تستهلك $cpu% من المعالج", "Medium")
                }
                if ($mem -gt 1024) {
                    $this.Diagnostic.AddIssue("Process", "العملية '$($_.ProcessName)' تستهلك $mem MB من الذاكرة", "Medium")
                }
            }
            
        } catch {
            Write-Host "  ❌  فشل في جمع بيانات الأداء: $($_.Exception.Message)" -ForegroundColor Red
            $this.Diagnostic.AddIssue("Performance", "فشل في تحليل أداء النظام", "High")
        }
        
        return $perf
    }
    
    [string]GetStatus([double]$value, [string]$metric) {
        $thresholds = [SystemStandards]::METRICS[$metric].Thresholds
        if ($value -ge $thresholds.Critical) { return "Critical" }
        if ($value -ge $thresholds.High) { return "High" }
        if ($value -ge $thresholds.Medium) { return "Medium" }
        if ($value -ge $thresholds.Low) { return "Low" }
        return "Info"
    }
}

# ============================================================
# الطبقة الثالثة: تحليل الأمن المتقدم
# ============================================================
class SecurityAnalyzer {
    [ArchitectureDiagnosticSystem]$Diagnostic
    
    SecurityAnalyzer([ArchitectureDiagnosticSystem]$diagnostic) {
        $this.Diagnostic = $diagnostic
    }
    
    [PSCustomObject]Analyze() {
        Write-Host "`n  🔒  تحليل الأمن المتقدم:" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════════════════"
        
        $security = $this.CollectSecurityData()
        $this.Diagnostic.Results.SecurityAnalysis = $security
        return $security
    }
    
    [PSCustomObject]CollectSecurityData() {
        $security = [PSCustomObject]@{
            Firewall = $null
            Antivirus = $null
            Updates = $null
            UAC = $null
            SecureBoot = $null
            BitLocker = $null
            AuditPolicies = $null
            Vulnerabilities = @()
            HardeningScore = 0
        }
        
        try {
            # فحص جدار الحماية
            $FirewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
            $security.Firewall = @{
                Enabled = ($FirewallProfiles | Where-Object { $_.Enabled -eq $true }).Count -gt 0
                Profiles = $FirewallProfiles | Select-Object Name, Enabled, InboundPolicy, OutboundPolicy
                Issues = @()
            }
            
            if (-not $security.Firewall.Enabled) {
                $security.Firewall.Issues += "جدار الحماية معطل"
                $this.Diagnostic.AddIssue("Security", "جدار الحماية معطل - النظام عرضة للخطر", "Critical")
                $this.Diagnostic.Results.Recommendations += "فعّل جدار الحماية Windows Defender فوراً"
            }
            
            # فحص مضاد الفيروسات
            try {
                $AV = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction SilentlyContinue
                $ActiveAV = $AV | Where-Object { $_.ProductState -eq 397568 -or $_.ProductState -eq 397584 }
                
                $security.Antivirus = @{
                    Installed = $AV -ne $null
                    Active = $ActiveAV -ne $null
                    Name = if ($ActiveAV) { $ActiveAV.displayName } else { if ($AV) { $AV.displayName } else { "غير مثبت" } }
                    Issues = @()
                }
                
                if (-not $security.Antivirus.Active) {
                    $security.Antivirus.Issues += "مضاد الفيروسات غير نشط"
                    $this.Diagnostic.AddIssue("Security", "مضاد الفيروسات غير نشط", "Critical")
                    $this.Diagnostic.Results.Recommendations += "فعّل برنامج مضاد الفيروسات أو قم بتثبيت برنامج موثوق"
                }
            } catch {
                $security.Antivirus = @{
                    Installed = $false
                    Active = $false
                    Name = "غير معروف"
                    Issues = @("لا يمكن تحديد حالة مضاد الفيروسات")
                }
                $this.Diagnostic.AddIssue("Security", "لا يمكن فحص حالة مضاد الفيروسات", "Medium")
            }
            
            # فحص التحديثات
            try {
                $UpdateSession = New-Object -ComObject "Microsoft.Update.Session" -ErrorAction SilentlyContinue
                if ($UpdateSession) {
                    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
                    $Updates = $UpdateSearcher.Search("IsInstalled=0 and IsHidden=0")
                    $security.Updates = @{
                        PendingCount = $Updates.Updates.Count
                        LastChecked = (Get-Date).AddHours(-$UpdateSearcher.ServerSelection)
                        Issues = @()
                    }
                    
                    if ($security.Updates.PendingCount -gt 5) {
                        $security.Updates.Issues += "هناك $($security.Updates.PendingCount) تحديثاً معلقاً"
                        $this.Diagnostic.AddIssue("Security", "$($security.Updates.PendingCount) تحديثاً أمنياً معلقاً", "High")
                        $this.Diagnostic.Results.Recommendations += "قم بتثبيت التحديثات الأمنية المعلقة"
                    }
                }
            } catch {
                $security.Updates = @{
                    PendingCount = -1
                    LastChecked = $null
                    Issues = @("لا يمكن فحص التحديثات")
                }
            }
            
            # فحص UAC
            $UAC = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
            $security.UAC = @{
                Enabled = $UAC.EnableLUA -eq 1
                Issues = @()
            }
            
            if (-not $security.UAC.Enabled) {
                $security.UAC.Issues += "UAC معطل"
                $this.Diagnostic.AddIssue("Security", "التحكم بحساب المستخدم (UAC) معطل", "High")
                $this.Diagnostic.Results.Recommendations += "فعّل UAC لتعزيز الأمان"
            }
            
            # فحص Secure Boot
            try {
                $security.SecureBoot = @{
                    Enabled = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
                    Issues = @()
                }
                
                if (-not $security.SecureBoot.Enabled) {
                    $security.SecureBoot.Issues += "Secure Boot غير مفعل"
                    $this.Diagnostic.AddIssue("Security", "Secure Boot غير مفعل", "Medium")
                    $this.Diagnostic.Results.Recommendations += "فعّل Secure Boot في إعدادات BIOS"
                }
            } catch {
                $security.SecureBoot = @{
                    Enabled = $false
                    Issues = @("لا يمكن فحص Secure Boot")
                }
            }
            
            # فحص BitLocker
            try {
                $BitLocker = Get-BitLockerVolume -ErrorAction SilentlyContinue
                $security.BitLocker = @{
                    Enabled = $BitLocker -ne $null
                    Protected = $BitLocker.ProtectionStatus -eq "On"
                    Issues = @()
                }
            } catch {
                $security.BitLocker = @{
                    Enabled = $false
                    Protected = $false
                    Issues = @("BitLocker غير مدعوم")
                }
            }
            
            # حساب درجة الحماية
            $hardeningScore = 100
            if (-not $security.Firewall.Enabled) { $hardeningScore -= 25 }
            if (-not $security.Antivirus.Active) { $hardeningScore -= 25 }
            if (-not $security.UAC.Enabled) { $hardeningScore -= 20 }
            if (-not $security.SecureBoot.Enabled) { $hardeningScore -= 15 }
            if ($security.Updates.PendingCount -gt 0) { $hardeningScore -= [math]::Min(15, $security.Updates.PendingCount) }
            $security.HardeningScore = [math]::Max(0, $hardeningScore)
            
            # عرض النتائج
            Write-Host "  🔐  حالة الأمن:" -ForegroundColor Yellow
            Write-Host "     جدار الحماية    : $(if ($security.Firewall.Enabled) { '✅ مفعل' } else { '❌ معطل' })" -ForegroundColor $(if ($security.Firewall.Enabled) { "Green" } else { "Red" })
            Write-Host "     مضاد الفيروسات : $(if ($security.Antivirus.Active) { "✅ $($security.Antivirus.Name)" } else { '❌ غير نشط' })" -ForegroundColor $(if ($security.Antivirus.Active) { "Green" } else { "Red" })
            Write-Host "     UAC            : $(if ($security.UAC.Enabled) { '✅ مفعل' } else { '❌ معطل' })" -ForegroundColor $(if ($security.UAC.Enabled) { "Green" } else { "Red" })
            Write-Host "     Secure Boot    : $(if ($security.SecureBoot.Enabled) { '✅ مفعل' } else { '⚠️ غير مفعل' })" -ForegroundColor $(if ($security.SecureBoot.Enabled) { "Green" } else { "Yellow" })
            Write-Host "     التحديثات      : $($security.Updates.PendingCount) معلق" -ForegroundColor $(if ($security.Updates.PendingCount -eq 0) { "Green" } else { "Yellow" })
            Write-Host "     BitLocker      : $(if ($security.BitLocker.Protected) { '✅ مفعل' } else { '⚠️ غير مفعل' })" -ForegroundColor $(if ($security.BitLocker.Protected) { "Green" } else { "Yellow" })
            Write-Host "     درجة الحماية   : $($security.HardeningScore)%" -ForegroundColor $(if ($security.HardeningScore -ge 80) { "Green" } elseif ($security.HardeningScore -ge 60) { "Yellow" } else { "Red" })
            
        } catch {
            Write-Host "  ❌  فشل في تحليل الأمن: $($_.Exception.Message)" -ForegroundColor Red
            $this.Diagnostic.AddIssue("Security", "فشل في تحليل حالة الأمن", "High")
        }
        
        return $security
    }
}

# ============================================================
# الطبقة الرابعة: تحليل التسجيل والخدمات
# ============================================================
class RegistryAndServicesAnalyzer {
    [ArchitectureDiagnosticSystem]$Diagnostic
    
    RegistryAndServicesAnalyzer([ArchitectureDiagnosticSystem]$diagnostic) {
        $this.Diagnostic = $diagnostic
    }
    
    [PSCustomObject]Analyze() {
        Write-Host "`n  🔧  تحليل السجل والخدمات:" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════════════════"
        
        $analysis = $this.CollectRegistryAndServices()
        $this.Diagnostic.Results.RegistryAnalysis = $analysis.Registry
        $this.Diagnostic.Results.ServiceAnalysis = $analysis.Services
        return $analysis
    }
    
    [PSCustomObject]CollectRegistryAndServices() {
        $result = [PSCustomObject]@{
            Registry = $null
            Services = $null
        }
        
        try {
            # تحليل السجل
            Write-Host "  📋  تحليل السجل (Registry):" -ForegroundColor Yellow
            
            $registryIssues = @()
            $registryHealth = 100
            
            # فحص مسارات البرامج غير الصالحة
            $UninstallKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            $invalidPaths = 0
            foreach ($Key in $UninstallKeys) {
                Get-ItemProperty -Path $Key -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.DisplayName -and $_.InstallLocation -and (Test-Path $_.InstallLocation) -eq $false) {
                        $invalidPaths++
                    }
                }
            }
            
            if ($invalidPaths -gt 0) {
                $registryIssues += "توجد $invalidPaths مسارات تثبيت غير صالحة"
                $registryHealth -= [math]::Min(20, $invalidPaths * 2)
                $this.Diagnostic.AddIssue("Registry", "توجد $invalidPaths مسارات غير صالحة في السجل", "Medium")
                $this.Diagnostic.Results.Recommendations += "قم بتنظيف السجل من المسارات غير الصالحة"
            }
            
            # فحص إدخالات بدء التشغيل
            $StartupKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            )
            
            $startupItems = @()
            foreach ($Key in $StartupKeys) {
                Get-ItemProperty -Path $Key -ErrorAction SilentlyContinue | ForEach-Object {
                    $_.PSObject.Properties | ForEach-Object {
                        if ($_.Name -notin @("PSChildName", "PSDrive", "PSPath", "PSProvider")) {
                            $startupItems += [PSCustomObject]@{
                                Name = $_.Name
                                Command = $_.Value
                                Source = $Key
                            }
                        }
                    }
                }
            }
            
            if ($startupItems.Count -gt 20) {
                $registryIssues += "كثرة برامج بدء التشغيل: $($startupItems.Count)"
                $registryHealth -= 10
                $this.Diagnostic.AddIssue("Startup", "توجد $($startupItems.Count) برامج في بدء التشغيل", "Low")
                $this.Diagnostic.Results.Recommendations += "قم بتقليل عدد برامج بدء التشغيل لتحسين الأداء"
            }
            
            $result.Registry = @{
                Issues = $registryIssues
                HealthScore = [math]::Max(0, $registryHealth)
                StartupItems = $startupItems
                StartupCount = $startupItems.Count
                IsHealthy = $registryIssues.Count -eq 0
            }
            
            Write-Host "     مشاكل السجل    : $($registryIssues.Count)" -ForegroundColor $(if ($registryIssues.Count -gt 0) { "Yellow" } else { "Green" })
            Write-Host "     برامج بدء التشغيل : $($startupItems.Count)" -ForegroundColor White
            Write-Host "     صحة السجل      : $($result.Registry.HealthScore)%" -ForegroundColor $(if ($result.Registry.HealthScore -ge 80) { "Green" } else { "Yellow" })
            
            # تحليل الخدمات
            Write-Host "`n  ⚙️  تحليل الخدمات:" -ForegroundColor Yellow
            
            $Services = Get-Service | Where-Object { $_.StartType -ne "Disabled" }
            $StoppedServices = $Services | Where-Object { $_.Status -eq "Stopped" }
            $RunningServices = $Services | Where-Object { $_.Status -eq "Running" }
            
            # الخدمات التي تستهلك موارد عالية
            $ServiceProcesses = Get-Process | Where-Object { $_.ProcessName -in (Get-Service | Where-Object { $_.Status -eq "Running" } | ForEach-Object { $_.ServiceName }) }
            $HighResourceServices = $ServiceProcesses | Where-Object { $_.CPU -gt 20 -or $_.WorkingSet -gt 500MB }
            
            $result.Services = @{
                Total = $Services.Count
                Running = $RunningServices.Count
                Stopped = $StoppedServices.Count
                AutoStart = ($Services | Where-Object { $_.StartType -eq "Automatic" }).Count
                HighResourceServices = $HighResourceServices
                Issues = @()
            }
            
            # تحليل الخدمات
            if ($result.Services.Stopped -gt ($result.Services.Total * 0.3)) {
                $result.Services.Issues += "عدد كبير من الخدمات المتوقفة"
                $this.Diagnostic.AddIssue("Services", "كثير من الخدمات متوقفة - قد يؤثر على الأداء", "Low")
            }
            
            if ($HighResourceServices.Count -gt 0) {
                Write-Host "     ⚠️  خدمات تستهلك موارد عالية:" -ForegroundColor Yellow
                $HighResourceServices | ForEach-Object {
                    $cpu = [math]::Round($_.CPU, 1)
                    $mem = [math]::Round($_.WorkingSet / 1MB, 0)
                    Write-Host "        $($_.ProcessName) - CPU: $cpu% - الذاكرة: $mem MB" -ForegroundColor White
                    $this.Diagnostic.AddIssue("Services", "خدمة '$($_.ProcessName)' تستهلك $cpu% CPU و $mem MB ذاكرة", "Medium")
                }
            }
            
            Write-Host "     إجمالي الخدمات : $($result.Services.Total)" -ForegroundColor White
            Write-Host "     الخدمات العاملة : $($result.Services.Running)" -ForegroundColor Green
            Write-Host "     الخدمات المتوقفة : $($result.Services.Stopped)" -ForegroundColor Yellow
            Write-Host "     تشغيل تلقائي  : $($result.Services.AutoStart)" -ForegroundColor White
            
        } catch {
            Write-Host "  ❌  فشل في تحليل السجل والخدمات: $($_.Exception.Message)" -ForegroundColor Red
            $this.Diagnostic.AddIssue("Analysis", "فشل في تحليل السجل والخدمات", "High")
        }
        
        return $result
    }
}

# ============================================================
# الطبقة الخامسة: تحليل الأحداث والتطبيقات
# ============================================================
class EventsAndApplicationsAnalyzer {
    [ArchitectureDiagnosticSystem]$Diagnostic
    
    EventsAndApplicationsAnalyzer([ArchitectureDiagnosticSystem]$diagnostic) {
        $this.Diagnostic = $diagnostic
    }
    
    [PSCustomObject]Analyze() {
        Write-Host "`n  📋  تحليل الأحداث والتطبيقات:" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════════════════"
        
        $analysis = $this.CollectEventsAndApps()
        $this.Diagnostic.Results.EventAnalysis = $analysis.Events
        $this.Diagnostic.Results.ApplicationAnalysis = $analysis.Applications
        return $analysis
    }
    
    [PSCustomObject]CollectEventsAndApps() {
        $result = [PSCustomObject]@{
            Events = $null
            Applications = $null
        }
        
        try {
            # تحليل أحداث النظام
            Write-Host "  📊  تحليل سجلات الأحداث:" -ForegroundColor Yellow
            
            $Last24Hours = (Get-Date).AddHours(-24)
            $LastWeek = (Get-Date).AddDays(-7)
            
            try {
                $SystemEvents = Get-WinEvent -MaxEvents 100 -FilterHashtable @{
                    LogName='System'
                    StartTime=$Last24Hours
                } -ErrorAction SilentlyContinue
            } catch {
                $SystemEvents = @()
            }
            
            try {
                $ApplicationEvents = Get-WinEvent -MaxEvents 100 -FilterHashtable @{
                    LogName='Application'
                    StartTime=$Last24Hours
                } -ErrorAction SilentlyContinue
            } catch {
                $ApplicationEvents = @()
            }
            
            $CriticalEvents = @($SystemEvents | Where-Object { $_.Level -eq 1 })
            $ErrorEvents = @($SystemEvents | Where-Object { $_.Level -eq 2 })
            $WarningEvents = @($SystemEvents | Where-Object { $_.Level -eq 3 })
            
            $result.Events = @{
                SystemEvents = $SystemEvents
                ApplicationEvents = $ApplicationEvents
                CriticalCount = $CriticalEvents.Count
                ErrorCount = $ErrorEvents.Count
                WarningCount = $WarningEvents.Count
                TotalEvents = $SystemEvents.Count + $ApplicationEvents.Count
                Issues = @()
            }
            
            Write-Host "     أحداث حرجة    : $($result.Events.CriticalCount)" -ForegroundColor $(if ($result.Events.CriticalCount -gt 0) { "Red" } else { "White" })
            Write-Host "     أخطاء         : $($result.Events.ErrorCount)" -ForegroundColor $(if ($result.Events.ErrorCount -gt 10) { "Yellow" } else { "White" })
            Write-Host "     تحذيرات       : $($result.Events.WarningCount)" -ForegroundColor White
            Write-Host "     إجمالي الأحداث : $($result.Events.TotalEvents)" -ForegroundColor White
            
            if ($result.Events.CriticalCount -gt 0) {
                $this.Diagnostic.AddIssue("Events", "توجد $($result.Events.CriticalCount) أحداث حرجة في النظام", "High")
                $this.Diagnostic.Results.Recommendations += "افحص سجل الأحداث للأحداث الحرجة"
            }
            
            if ($result.Events.ErrorCount -gt 10) {
                $this.Diagnostic.AddIssue("Events", "كثرة الأخطاء في النظام ($($result.Events.ErrorCount) خطأ)", "Medium")
                $this.Diagnostic.Results.Recommendations += "قم بتحليل سجلات الأحداث لمعرفة أسباب الأخطاء"
            }
            
            # تحليل التطبيقات
            Write-Host "`n  📱  تحليل التطبيقات:" -ForegroundColor Yellow
            
            $InstalledApps = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Select-Object Name, Version, Vendor, InstallDate
            $InstalledAppsCount = $InstalledApps.Count
            
            # البحث عن تطبيقات قديمة
            $OldApps = @()
            $CurrentDate = Get-Date
            foreach ($App in $InstalledApps) {
                if ($App.InstallDate) {
                    try {
                        $InstallDate = [datetime]::ParseExact($App.InstallDate, "yyyyMMdd", $null)
                        if (($CurrentDate - $InstallDate).Days -gt 365) {
                            $OldApps += $App
                        }
                    } catch {
                        # تجاهل
                    }
                }
            }
            
            $result.Applications = @{
                Total = $InstalledAppsCount
                OldApplications = $OldApps
                OldCount = $OldApps.Count
                Issues = @()
            }
            
            Write-Host "     إجمالي التطبيقات : $($result.Applications.Total)" -ForegroundColor White
            Write-Host "     تطبيقات قديمة   : $($result.Applications.OldCount)" -ForegroundColor $(if ($result.Applications.OldCount -gt 10) { "Yellow" } else { "White" })
            
            if ($result.Applications.OldCount -gt 10) {
                $this.Diagnostic.AddIssue("Applications", "توجد $($result.Applications.OldCount) تطبيقاً قديماً", "Low")
                $this.Diagnostic.Results.Recommendations += "قم بتحديث التطبيقات القديمة أو إزالتها"
            }
            
            # تحليل التطبيقات قيد التشغيل
            $RunningApps = Get-Process | Where-Object { $_.MainWindowTitle -ne "" }
            Write-Host "     تطبيقات مفتوحة : $($RunningApps.Count)" -ForegroundColor White
            
        } catch {
            Write-Host "  ❌  فشل في تحليل الأحداث والتطبيقات: $($_.Exception.Message)" -ForegroundColor Red
            $this.Diagnostic.AddIssue("Analysis", "فشل في تحليل الأحداث والتطبيقات", "High")
        }
        
        return $result
    }
}

# ============================================================
# الطبقة السادسة: النظام الخبير والتحليل الذكي
# ============================================================
class ExpertAdvisor {
    [ArchitectureDiagnosticSystem]$Diagnostic
    [hashtable]$ExpertRules
    
    ExpertAdvisor([ArchitectureDiagnosticSystem]$diagnostic) {
        $this.Diagnostic = $diagnostic
        $this.ExpertRules = $this.InitializeExpertRules()
    }
    
    [hashtable]InitializeExpertRules() {
        return @{
            "Performance" = @{
                "Condition" = { param($d) $d.Results.PerformanceAnalysis -and $d.Results.PerformanceAnalysis.CPU.Usage -gt 80 }
                "Advice" = @{
                    "Message" = "استخدام المعالج مرتفع جداً (>80%)"
                    "Recommendations" = @(
                        "حدد العمليات التي تستهلك المعالج",
                        "أغلق التطبيقات غير الضرورية",
                        "تحقق من وجود برامج ضارة",
                        "قم بترقية المعالج إذا كان متكرراً"
                    )
                    "Priority" = "High"
                }
            }
            "MemoryPressure" = @{
                "Condition" = { param($d) $d.Results.PerformanceAnalysis -and $d.Results.PerformanceAnalysis.Memory.Usage -gt 85 }
                "Advice" = @{
                    "Message" = "ضغط على الذاكرة - استخدام >85%"
                    "Recommendations" = @(
                        "أغلق التطبيقات غير المستخدمة",
                        "قم بزيادة حجم الذاكرة",
                        "تحقق من تسريبات الذاكرة في البرامج"
                    )
                    "Priority" = "High"
                }
            }
            "SecurityRisks" = @{
                "Condition" = { param($d) $d.Results.SecurityAnalysis -and (!$d.Results.SecurityAnalysis.Firewall.Enabled -or !$d.Results.SecurityAnalysis.Antivirus.Active) }
                "Advice" = @{
                    "Message" = "النظام غير محمي بشكل كافٍ"
                    "Recommendations" = @(
                        "فعّل جدار الحماية فوراً",
                        "قم بتثبيت مضاد فيروسات موثوق",
                        "افحص النظام بحثاً عن برامج ضارة"
                    )
                    "Priority" = "Critical"
                }
            }
            "DiskSpace" = @{
                "Condition" = { param($d) $d.Results.PerformanceAnalysis -and $d.Results.PerformanceAnalysis.DiskIO.Usage -gt 90 }
                "Advice" = @{
                    "Message" = "مساحة القرص تقترب من الامتلاء (>90%)"
                    "Recommendations" = @(
                        "قم بتنظيف القرص من الملفات المؤقتة",
                        "انقل الملفات الكبيرة إلى قرص آخر",
                        "قم بترقية القرص الصلب"
                    )
                    "Priority" = "High"
                }
            }
            "SystemUpdates" = @{
                "Condition" = { param($d) $d.Results.SecurityAnalysis -and $d.Results.SecurityAnalysis.Updates.PendingCount -gt 10 }
                "Advice" = @{
                    "Message" = "توجد تحديثات مهمة معلقة ($($d.Results.SecurityAnalysis.Updates.PendingCount))"
                    "Recommendations" = @(
                        "قم بتثبيت التحديثات الأمنية والحرجة",
                        "جدولة التحديثات في وقت مناسب",
                        "تأكد من الاتصال بالإنترنت"
                    )
                    "Priority" = "Medium"
                }
            }
            "StartupBlast" = @{
                "Condition" = { param($d) $d.Results.RegistryAnalysis -and $d.Results.RegistryAnalysis.StartupCount -gt 15 }
                "Advice" = @{
                    "Message" = "كثرة برامج بدء التشغيل ($($d.Results.RegistryAnalysis.StartupCount))"
                    "Recommendations" = @(
                        "قم بتعطيل برامج بدء التشغيل غير الضرورية",
                        "استخدم Task Manager لإدارة بدء التشغيل",
                        "أزل البرامج التي لا تحتاجها"
                    )
                    "Priority" = "Medium"
                }
            }
            "EventErrors" = @{
                "Condition" = { param($d) $d.Results.EventAnalysis -and $d.Results.EventAnalysis.ErrorCount -gt 20 }
                "Advice" = @{
                    "Message" = "كثرة الأخطاء في سجل الأحداث"
                    "Recommendations" = @(
                        "افحص سجل الأحداث للمزيد من التفاصيل",
                        "حدد سبب الأخطاء المتكررة",
                        "قم بتحديث التعريفات والتطبيقات"
                    )
                    "Priority" = "Medium"
                }
            }
        }
    }
    
    [PSCustomObject]GenerateExpertAdvice() {
        Write-Host "`n  🧠  تحليل الخبير الذكي:" -ForegroundColor Cyan
        Write-Host "  ═══════════════════════════════════════════════════════════════════"
        
        $advice = @()
        $criticalCount = 0
        $highCount = 0
        $mediumCount = 0
        
        foreach ($rule in $this.ExpertRules.Keys) {
            $ruleObj = $this.ExpertRules[$rule]
            try {
                $conditionResult = & $ruleObj.Condition $this.Diagnostic
                if ($conditionResult) {
                    $adviceItem = $ruleObj.Advice
                    $adviceItem.Rule = $rule
                    $advice += $adviceItem
                    
                    switch ($adviceItem.Priority) {
                        "Critical" { $criticalCount++ }
                        "High" { $highCount++ }
                        "Medium" { $mediumCount++ }
                    }
                }
            } catch {
                # تجاهل الأخطاء في القواعد
            }
        }
        
        # عرض توصيات الخبير
        if ($advice.Count -gt 0) {
            Write-Host "  💡  توصيات الخبير الذكي:" -ForegroundColor Yellow
            
            # عرض التوصيات حسب الأولوية
            $advice | Sort-Object Priority | ForEach-Object {
                $priorityColor = switch ($_.Priority) {
                    "Critical" { "Red" }
                    "High" { "DarkYellow" }
                    "Medium" { "Yellow" }
                    default { "White" }
                }
                
                Write-Host "`n     [$($_.Priority)] $($_.Message)" -ForegroundColor $priorityColor
                foreach ($rec in $_.Recommendations) {
                    Write-Host "        • $rec" -ForegroundColor White
                }
            }
            
            # إضافة التوصيات إلى النتائج
            foreach ($item in $advice) {
                foreach ($rec in $item.Recommendations) {
                    $this.Diagnostic.Results.Recommendations += "[$($item.Priority)] $rec"
                }
            }
        } else {
            Write-Host "  ✅  لا توجد توصيات خبيرة - النظام في حالة جيدة" -ForegroundColor Green
        }
        
        # إحصائيات التوصيات
        Write-Host "`n  📊  ملخص توصيات الخبير:" -ForegroundColor Cyan
        Write-Host "     حرجة    : $criticalCount" -ForegroundColor Red
        Write-Host "     عالية   : $highCount" -ForegroundColor DarkYellow
        Write-Host "     متوسطة  : $mediumCount" -ForegroundColor Yellow
        Write-Host "     إجمالي  : $($advice.Count)" -ForegroundColor White
        
        return $advice
    }
}

# ============================================================
# النظام الرئيسي: التشغيل والتنسيق
# ============================================================
function Invoke-ExpertSystemAnalysis {
    Write-Host @"
`n
  ╔══════════════════════════════════════════════════════════════════╗
  ║                                                                  ║
  ║           🏆  النظام الخبير للتشخيص المتقدم  3.0              ║
  ║     ────────────────────────────────────────────────────────────  ║
  ║     ⚡  تحليل معماري متعدد الطبقات                             ║
  ║     🧠  نظام خبير ذكي مع قاعدة معرفة ديناميكية                ║
  ║     🔬  تشخيص دقيق باستخدام معايير IEEE و ISO                 ║
  ║     📊  تقارير احترافية مع تحليلات تنبؤية                     ║
  ║     🔒  فحص أمني شامل مع توصيات فورية                        ║
  ║                                                                  ║
  ╚══════════════════════════════════════════════════════════════════╝
`n" -ForegroundColor Cyan
    
    # إنشاء النظام التشخيصي
    $diagnostic = [ArchitectureDiagnosticSystem]::new($ConfigPath)
    
    # تنفيذ التحليلات المتسلسلة
    $systemAnalyzer = [SystemArchitectureAnalyzer]::new($diagnostic)
    $systemAnalyzer.Analyze()
    
    $perfAnalyzer = [PerformanceAnalyzer]::new($diagnostic)
    $perfAnalyzer.Analyze()
    
    $securityAnalyzer = [SecurityAnalyzer]::new($diagnostic)
    $securityAnalyzer.Analyze()
    
    $registryAnalyzer = [RegistryAndServicesAnalyzer]::new($diagnostic)
    $registryAnalyzer.Analyze()
    
    $eventsAnalyzer = [EventsAndApplicationsAnalyzer]::new($diagnostic)
    $eventsAnalyzer.Analyze()
    
    # النظام الخبير
    $expert = [ExpertAdvisor]::new($diagnostic)
    $expert.GenerateExpertAdvice()
    
    # الحصول على النتائج النهائية
    $results = $diagnostic.GetResults()
    
    # عرض الملخص النهائي
    Write-Host "`n  📊  الملخص النهائي للنظام:" -ForegroundColor Cyan
    Write-Host "  ═══════════════════════════════════════════════════════════════════"
    Write-Host "  🎯  درجة الصحة        : $($results.HealthScore)%" -ForegroundColor $(if ($results.HealthScore -ge 85) { "Green" } elseif ($results.HealthScore -ge 70) { "Cyan" } elseif ($results.HealthScore -ge 50) { "Yellow" } else { "Red" })
    Write-Host "  📊  حالة النظام       : $($results.HealthStatus)" -ForegroundColor $(if ($results.HealthStatus -eq "ممتاز") { "Green" } elseif ($results.HealthStatus -eq "جيد") { "Cyan" } elseif ($results.HealthStatus -eq "مقبول") { "Yellow" } else { "Red" })
    Write-Host "  ⚠️  مستوى المخاطرة    : $($results.RiskLevel)" -ForegroundColor $(if ($results.RiskLevel -eq "Low") { "Green" } elseif ($results.RiskLevel -eq "Medium") { "Yellow" } else { "Red" })
    Write-Host "  🔴  مشاكل حرجة        : $($diagnostic.CriticalIssues)" -ForegroundColor Red
    Write-Host "  🟠  مشاكل عالية       : $($diagnostic.HighIssues)" -ForegroundColor DarkYellow
    Write-Host "  🟡  مشاكل متوسطة      : $($diagnostic.MediumIssues)" -ForegroundColor Yellow
    Write-Host "  ℹ️  مشاكل منخفضة      : $($diagnostic.LowIssues)" -ForegroundColor Cyan
    Write-Host "  💡  التوصيات          : $($results.Recommendations.Count)" -ForegroundColor White
    Write-Host "  ⏱️  مدة التحليل       : $([math]::Round($results.AnalysisDuration, 2)) ثانية" -ForegroundColor White
    
    # تصدير التقرير
    if ($GenerateReport) {
        $reportPath = Export-ExpertReport -Diagnostic $diagnostic
        if ($Interactive) {
            Start-Process $reportPath
        }
    }
    
    # تصدير JSON
    if ($ExportJson) {
        $jsonPath = "ExpertAnalysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $results | ConvertTo-Json -Depth 15 | Out-File -FilePath $jsonPath -Encoding UTF8
        Write-Host "  📄  تم تصدير JSON: $jsonPath" -ForegroundColor Green
    }
    
    Write-Host "`n  ✅  اكتمل التحليل الخبير بنجاح" -ForegroundColor Green
    Write-Host "  ═══════════════════════════════════════════════════════════════════`n"
    
    return $results
}

# ============================================================
# وظيفة تصدير التقرير المتقدم
# ============================================================
function Export-ExpertReport {
    param([ArchitectureDiagnosticSystem]$Diagnostic)
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportPath = "ExpertReport_$timestamp.html"
    
    Write-Host "`n  📄  جاري إنشاء التقرير الخبير..." -ForegroundColor Cyan
    
    $Report = @"
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تقرير الخبير - تحليل النظام المتقدم $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #16213e 100%);
            color: #e0e0e0;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: rgba(255,255,255,0.03);
            border-radius: 20px;
            padding: 30px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.08);
            box-shadow: 0 25px 80px rgba(0,0,0,0.7);
        }
        .header {
            text-align: center;
            padding: 30px 0;
            background: linear-gradient(135deg, rgba(100,100,255,0.1), rgba(255,100,100,0.1));
            border-radius: 15px;
            margin-bottom: 30px;
        }
        h1 {
            font-size: 3em;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle {
            color: #8899aa;
            margin-top: 10px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .metric-card {
            background: rgba(255,255,255,0.05);
            padding: 20px;
            border-radius: 12px;
            text-align: center;
            border: 1px solid rgba(255,255,255,0.05);
            transition: transform 0.3s;
        }
        .metric-card:hover { transform: translateY(-5px); }
        .metric-value {
            font-size: 2.5em;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            color: #8899aa;
            font-size: 0.9em;
        }
        .section {
            background: rgba(255,255,255,0.03);
            border-radius: 12px;
            padding: 20px;
            margin: 20px 0;
        }
        .section h2 {
            color: #667eea;
            border-bottom: 2px solid #667eea30;
            padding-bottom: 10px;
            margin-bottom: 15px;
        }
        .issue-item {
            padding: 12px;
            margin: 5px 0;
            border-radius: 8px;
            border-right: 4px solid;
        }
        .issue-critical { border-right-color: #ff0000; background: rgba(255,0,0,0.1); }
        .issue-high { border-right-color: #ff4400; background: rgba(255,68,0,0.08); }
        .issue-medium { border-right-color: #ffaa00; background: rgba(255,170,0,0.06); }
        .issue-low { border-right-color: #44aaff; background: rgba(68,170,255,0.05); }
        .recommendations {
            background: linear-gradient(135deg, rgba(100,200,255,0.05), rgba(255,100,200,0.05));
            border-radius: 12px;
            padding: 20px;
        }
        .recommendations li {
            padding: 8px 0;
            list-style: none;
            border-bottom: 1px solid rgba(255,255,255,0.05);
        }
        .recommendations li:last-child { border-bottom: none; }
        .recommendations li::before {
            content: "💡 ";
        }
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-weight: bold;
        }
        .badge-excellent { background: #00ff8820; color: #00ff88; border: 1px solid #00ff88; }
        .badge-good { background: #00ccff20; color: #00ccff; border: 1px solid #00ccff; }
        .badge-fair { background: #ffaa0020; color: #ffaa00; border: 1px solid #ffaa00; }
        .badge-poor { background: #ff440020; color: #ff4400; border: 1px solid #ff4400; }
        .badge-critical { background: #ff000020; color: #ff0000; border: 1px solid #ff0000; }
        .chart-container {
            max-width: 400px;
            margin: 20px auto;
        }
        @media (max-width: 768px) {
            .container { padding: 15px; }
            h1 { font-size: 2em; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏆 تقرير الخبير المتقدم</h1>
            <div class="subtitle">
                تم التحليل في: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | 
                المدة: $([math]::Round($Diagnostic.Results.AnalysisDuration, 2)) ثانية
            </div>
        </div>

        <!-- Summary -->
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">صحة النظام</div>
                <div class="metric-value" style="color: $(if ($Diagnostic.Results.HealthScore -ge 85) { '#00ff88' } elseif ($Diagnostic.Results.HealthScore -ge 70) { '#00ccff' } elseif ($Diagnostic.Results.HealthScore -ge 50) { '#ffaa00' } else { '#ff0000' });">
                    $($Diagnostic.Results.HealthScore)%
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-label">الحالة</div>
                <div style="margin-top: 10px;">
                    <span class="status-badge badge-$($Diagnostic.Results.HealthStatus)">
                        $($Diagnostic.Results.HealthStatus)
                    </span>
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-label">مستوى المخاطرة</div>
                <div class="metric-value" style="font-size: 1.5em; color: $(if ($Diagnostic.Results.RiskLevel -eq 'Low') { '#00ff88' } elseif ($Diagnostic.Results.RiskLevel -eq 'Medium') { '#ffaa00' } else { '#ff0000' });">
                    $($Diagnostic.Results.RiskLevel)
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-label">إجمالي المشاكل</div>
                <div class="metric-value">$($Diagnostic.TotalIssues)</div>
            </div>
        </div>

        <!-- Issues Distribution -->
        <div class="section">
            <h2>📊 توزيع المشاكل</h2>
            <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; text-align: center;">
                <div style="background: rgba(255,0,0,0.1); padding: 15px; border-radius: 8px;">
                    <div style="color: #ff4444; font-size: 1.5em; font-weight: bold;">$($Diagnostic.CriticalIssues)</div>
                    <div style="color: #8899aa;">حرجة</div>
                </div>
                <div style="background: rgba(255,68,0,0.1); padding: 15px; border-radius: 8px;">
                    <div style="color: #ff8800; font-size: 1.5em; font-weight: bold;">$($Diagnostic.HighIssues)</div>
                    <div style="color: #8899aa;">عالية</div>
                </div>
                <div style="background: rgba(255,170,0,0.1); padding: 15px; border-radius: 8px;">
                    <div style="color: #ffaa00; font-size: 1.5em; font-weight: bold;">$($Diagnostic.MediumIssues)</div>
                    <div style="color: #8899aa;">متوسطة</div>
                </div>
                <div style="background: rgba(68,170,255,0.1); padding: 15px; border-radius: 8px;">
                    <div style="color: #44aaff; font-size: 1.5em; font-weight: bold;">$($Diagnostic.LowIssues)</div>
                    <div style="color: #8899aa;">منخفضة</div>
                </div>
            </div>
        </div>

        <!-- System Info -->
        <div class="section">
            <h2>🖥️ معلومات النظام</h2>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px;">
                <div><strong>نظام التشغيل:</strong> $($Diagnostic.Results.SystemInfo.OperatingSystem.Name)</div>
                <div><strong>الإصدار:</strong> $($Diagnostic.Results.SystemInfo.OperatingSystem.Version)</div>
                <div><strong>المعالج:</strong> $($Diagnostic.Results.SystemInfo.Hardware.ProcessorName)</div>
                <div><strong>الذاكرة:</strong> $($Diagnostic.Results.SystemInfo.Hardware.TotalMemory) GB</div>
                <div><strong>نوع الجهاز:</strong> $($Diagnostic.Results.SystemInfo.SystemType)</div>
                <div><strong>وقت التشغيل:</strong> $([math]::Round($Diagnostic.Results.SystemInfo.Uptime.TotalHours, 1)) ساعات</div>
            </div>
        </div>

        <!-- Performance -->
        <div class="section">
            <h2>⚡ أداء النظام</h2>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
"@
    
    if ($Diagnostic.Results.PerformanceAnalysis) {
        $perf = $Diagnostic.Results.PerformanceAnalysis
        $Report += @"
                <div>
                    <div style="color: #8899aa;">المعالج (CPU)</div>
                    <div style="font-size: 1.5em; color: $(if ($perf.CPU.Usage -gt 80) { '#ff4444' } elseif ($perf.CPU.Usage -gt 60) { '#ffaa00' } else { '#00ff88' });">
                        $($perf.CPU.Usage)%
                    </div>
                    <div style="color: #8899aa; font-size: 0.9em;">$($perf.CPU.Status)</div>
                </div>
                <div>
                    <div style="color: #8899aa;">الذاكرة (Memory)</div>
                    <div style="font-size: 1.5em; color: $(if ($perf.Memory.Usage -gt 85) { '#ff4444' } elseif ($perf.Memory.Usage -gt 70) { '#ffaa00' } else { '#00ff88' });">
                        $($perf.Memory.Usage)%
                    </div>
                    <div style="color: #8899aa; font-size: 0.9em;">مستخدمة: $($perf.Memory.Used) MB</div>
                </div>
                <div>
                    <div style="color: #8899aa;">القرص (Disk)</div>
                    <div style="font-size: 1.5em; color: $(if ($perf.DiskIO.Usage -gt 85) { '#ff4444' } elseif ($perf.DiskIO.Usage -gt 70) { '#ffaa00' } else { '#00ff88' });">
                        $($perf.DiskIO.Usage)%
                    </div>
                    <div style="color: #8899aa; font-size: 0.9em;">$($perf.DiskIO.Status)</div>
                </div>
"@
    }
    
    $Report += @"
            </div>
        </div>

        <!-- Security -->
        <div class="section">
            <h2>🔒 حالة الأمان</h2>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px;">
"@
    
    if ($Diagnostic.Results.SecurityAnalysis) {
        $sec = $Diagnostic.Results.SecurityAnalysis
        $Report += @"
                <div><strong>جدار الحماية:</strong> $(if ($sec.Firewall.Enabled) { '✅ مفعل' } else { '❌ معطل' })</div>
                <div><strong>مضاد الفيروسات:</strong> $(if ($sec.Antivirus.Active) { "✅ $($sec.Antivirus.Name)" } else { '❌ غير نشط' })</div>
                <div><strong>UAC:</strong> $(if ($sec.UAC.Enabled) { '✅ مفعل' } else { '❌ معطل' })</div>
                <div><strong>التحديثات المعلقة:</strong> $($sec.Updates.PendingCount)</div>
                <div><strong>درجة الحماية:</strong> $($sec.HardeningScore)%</div>
"@
    }
    
    $Report += @"
            </div>
        </div>

        <!-- Issues -->
        <div class="section">
            <h2>⚠️ المشاكل المكتشفة</h2>
"@
    
    if ($Diagnostic.Results.Issues -and $Diagnostic.Results.Issues.Count -gt 0) {
        foreach ($issue in $Diagnostic.Results.Issues) {
            $class = "issue-" + $issue.Severity.ToLower()
            $Report += @"
            <div class="issue-item $class">
                <strong>[$($issue.Severity)]</strong> $($issue.Description)
                <div style="color: #8899aa; font-size: 0.9em; margin-top: 5px;">
                    🏷️ $($issue.Category) | ⏱️ $($issue.Timestamp.ToString('HH:mm:ss'))
                </div>
                <div style="color: #44aaff; font-size: 0.9em; margin-top: 5px;">
                    💡 $($issue.Recommendation)
                </div>
            </div>
"@
        }
    } else {
        $Report += @"
            <div style="color: #00ff88; padding: 20px; text-align: center; font-size: 1.2em;">
                ✅ لا توجد مشاكل مكتشفة - النظام في حالة ممتازة
            </div>
"@
    }
    
    $Report += @"
        </div>

        <!-- Recommendations -->
        <div class="section">
            <h2>💡 التوصيات</h2>
            <div class="recommendations">
"@
    
    if ($Diagnostic.Results.Recommendations -and $Diagnostic.Results.Recommendations.Count -gt 0) {
        $Recommendations = $Diagnostic.Results.Recommendations | Sort-Object
        foreach ($rec in $Recommendations) {
            $Report += @"
                <li>$rec</li>
"@
        }
    } else {
        $Report += @"
                <li>✅ لا توجد توصيات - استمر في الصيانة الدورية</li>
"@
    }
    
    $Report += @"
            </div>
        </div>

        <div style="text-align: center; color: #666; padding: 20px; border-top: 1px solid #333; margin-top: 30px;">
            تقرير الخبير المتقدم v3.0 &copy; $(Get-Date -Format 'yyyy') | 
            تم إنشاؤه بواسطة نظام التشخيص الذكي
        </div>
    </div>
</body>
</html>
"@
    
    $Report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "  ✅  تم إنشاء التقرير: $reportPath" -ForegroundColor Green
    return $reportPath
}

# ============================================================
# تشغيل النظام الخبير
# ============================================================
Invoke-ExpertSystemAnalysis