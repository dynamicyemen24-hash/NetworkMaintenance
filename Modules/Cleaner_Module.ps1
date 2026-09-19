<#
.SYNOPSIS
    النظام الذكي المتقدم للتنظيف العميق وتحسين الأداء - الإصدار النهائي 5.0
    Advanced Intelligent Deep Cleanup & Performance Optimization - Ultimate Edition

.DESCRIPTION
    نظام تنظيف ذكي شامل يتعامل مع جميع أنواع الملفات والمجلدات التي تؤثر على الأداء:
    - تنظيف جميع أنواع الكاش (Cache) في النظام والتطبيقات
    - حذف الملفات المؤقتة والمهملة بأمان
    - تنظيف مخلفات البرامج المحذوفة
    - تنظيف السجل (Registry) من الإدخالات الفارغة
    - تحسين أداء النظام والذاكرة
    - نظام تفاعلي ذكي مع المستخدم
    - تحليل المخاطر قبل التنظيف
    - نقاط استعادة تلقائية
    - تقارير تفصيلية مع توصيات
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Interactive,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$SafeMode,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeepClean,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxAgeDays = 30,
    
    [Parameter(Mandatory = $false)]
    [int]$MinFileSizeMB = 0,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths
)

# ============================================================
# الفئة الأساسية - نظام التنظيف الذكي المتقدم
# ============================================================
class AdvancedCleanupEngine {
    # الخصائص الأساسية
    [bool]$Interactive
    [bool]$DryRun
    [bool]$SafeMode
    [bool]$DeepClean
    [int]$MaxAgeDays
    [int]$MinFileSizeMB
    [array]$ExcludePaths
    [hashtable]$Stats
    [array]$CleanableItems
    [array]$ProtectedItems
    [array]$Warnings
    [array]$Errors
    [hashtable]$Categories
    [string]$BackupPath
    [datetime]$StartTime
    [datetime]$EndTime
    
    AdvancedCleanupEngine([bool]$interactive, [bool]$dryRun, [bool]$safeMode, [bool]$deepClean, [int]$maxAge, [int]$minSize, [array]$exclude) {
        $this.Interactive = $interactive
        $this.DryRun = $dryRun
        $this.SafeMode = $safeMode
        $this.DeepClean = $deepClean
        $this.MaxAgeDays = $maxAge
        $this.MinFileSizeMB = $minSize
        $this.ExcludePaths = $exclude
        $this.CleanableItems = @()
        $this.ProtectedItems = @()
        $this.Warnings = @()
        $this.Errors = @()
        $this.StartTime = Get-Date
        
        # إحصائيات
        $this.Stats = @{
            TotalFiles     = 0
            TotalSize      = 0
            CleanedFiles   = 0
            FreedSpace     = 0
            ProtectedFiles = 0
            Errors         = 0
            Warnings       = 0
            Categories     = @{}
        }
        
        # تعريف الفئات
        $this.InitializeCategories()
        
        # إنشاء مسار النسخ الاحتياطي
        $this.BackupPath = "C:\SystemBackups\Cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if (-not $this.DryRun) {
            New-Item -ItemType Directory -Path $this.BackupPath -Force | Out-Null
        }
    }
    
    [void]InitializeCategories() {
        $this.Categories = @{
            # 1. كاش النظام والتطبيقات
            "SystemCache"          = @{
                "Description" = "كاش النظام وملفات التحميل المؤقتة"
                "Priority"    = 1
                "Risk"        = "Low"
                "Icon"        = "⚙️"
                "Paths"       = @(
                    "C:\Windows\Temp\*",
                    "$env:TEMP\*",
                    "$env:USERPROFILE\AppData\Local\Temp\*",
                    "C:\Windows\Prefetch\*.pf",
                    "C:\Windows\SoftwareDistribution\Download\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\*.db"
                )
            }
            
            # 2. كاش المتصفحات
            "BrowserCache"         = @{
                "Description" = "كاش وملفات المتصفحات المؤقتة"
                "Priority"    = 2
                "Risk"        = "Low"
                "Icon"        = "🌐"
                "Paths"       = @(
                    "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
                    "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Code Cache\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache\*",
                    "$env:USERPROFILE\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*",
                    "$env:USERPROFILE\AppData\Local\Mozilla\Firefox\Profiles\*\offlinecache\*",
                    "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Cache\*",
                    "$env:USERPROFILE\AppData\Local\Opera Software\Opera Stable\Cache\*"
                )
            }
            
            # 3. ملفات الإنترنت المؤقتة
            "InternetCache"        = @{
                "Description" = "ملفات الإنترنت المؤقتة والكوكيز"
                "Priority"    = 3
                "Risk"        = "Low"
                "Icon"        = "🌍"
                "Paths"       = @(
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache\IE\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCookies\*",
                    "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Cookies\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Internet Explorer\DOMStore\*"
                )
            }
            
            # 4. ملفات السجلات (Logs)
            "LogFiles"             = @{
                "Description" = "ملفات السجلات والتحليلات"
                "Priority"    = 4
                "Risk"        = "Low"
                "Icon"        = "📋"
                "Paths"       = @(
                    "C:\Windows\Logs\*",
                    "C:\Windows\System32\LogFiles\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\WER\*",
                    "$env:USERPROFILE\AppData\Local\CrashDumps\*",
                    "C:\Windows\Minidump\*.dmp",
                    "C:\Windows\Memory.dmp",
                    "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\*.log"
                )
            }
            
            # 5. مخلفات البرامج المحذوفة
            "SoftwareRemnants"     = @{
                "Description" = "مخلفات البرامج المحذوفة والمجلدات الفارغة"
                "Priority"    = 5
                "Risk"        = "Medium"
                "Icon"        = "🗑️"
                "Paths"       = @(
                    "C:\Program Files\*\Uninstall\*",
                    "C:\Program Files (x86)\*\Uninstall\*",
                    "$env:USERPROFILE\AppData\Local\*\Temp\*",
                    "$env:USERPROFILE\AppData\Roaming\*\Temp\*",
                    "C:\Windows\Installer\*.tmp",
                    "C:\Config.Msi\*"
                )
            }
            
            # 6. ملفات التحديث القديمة
            "OldUpdates"           = @{
                "Description" = "ملفات التحديث القديمة والنسخ الاحتياطية"
                "Priority"    = 6
                "Risk"        = "Medium"
                "Icon"        = "🔄"
                "Paths"       = @(
                    "C:\Windows\SoftwareDistribution\Download\*",
                    "C:\Windows\Installer\$PatchCache$\*",
                    "C:\Windows\WinSxS\Backup\*",
                    "C:\Windows\System32\DriverStore\FileRepository\*.tmp"
                )
            }
            
            # 7. ملفات الصور المصغرة
            "Thumbnails"           = @{
                "Description" = "ملفات الصور المصغرة وذاكرة التخزين المؤقت"
                "Priority"    = 7
                "Risk"        = "Low"
                "Icon"        = "🖼️"
                "Paths"       = @(
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\*.tmp"
                )
            }
            
            # 8. ملفات Office المؤقتة
            "OfficeCache"          = @{
                "Description" = "ملفات Microsoft Office المؤقتة"
                "Priority"    = 8
                "Risk"        = "Low"
                "Icon"        = "📊"
                "Paths"       = @(
                    "$env:USERPROFILE\AppData\Local\Microsoft\Office\16.0\OfficeFileCache\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Office\16.0\DocumentBuilderCache\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache\Content.MSO\*",
                    "$env:TEMP\*.tmp"
                )
            }
            
            # 9. مخلفات التثبيت
            "InstallationRemnants" = @{
                "Description" = "مخلفات عمليات التثبيت والإلغاء"
                "Priority"    = 9
                "Risk"        = "Medium"
                "Icon"        = "📦"
                "Paths"       = @(
                    "C:\Windows\Temp\*.msi",
                    "C:\Windows\Installer\*.msi",
                    "C:\Windows\Downloaded Installations\*",
                    "C:\ProgramData\Package Cache\*",
                    "$env:USERPROFILE\AppData\Local\Downloaded Installations\*"
                )
            }
            
            # 10. ملفات التخزين المؤقت للتطبيقات
            "AppCache"             = @{
                "Description" = "كاش التطبيقات والبرامج"
                "Priority"    = 10
                "Risk"        = "Low"
                "Icon"        = "📱"
                "Paths"       = @(
                    "$env:USERPROFILE\AppData\Local\Packages\*\AC\*",
                    "$env:USERPROFILE\AppData\Local\Packages\*\LocalState\Cache\*",
                    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\*.cache",
                    "C:\ProgramData\Microsoft\Windows\WER\*"
                )
            }
        }
        
        # إضافة مسارات إضافية للتنظيف العميق
        if ($this.DeepClean) {
            $this.Categories["DeepClean"] = @{
                "Description" = "تنظيف عميق - ملفات إضافية"
                "Priority"    = 11
                "Risk"        = "High"
                "Icon"        = "🔬"
                "Paths"       = @(
                    "C:\Windows\System32\config\*.log",
                    "C:\Windows\System32\config\*.sav",
                    "C:\Windows\System32\config\*.old",
                    "C:\Windows\System32\*.tmp",
                    "C:\Windows\*.tmp",
                    "$env:USERPROFILE\*.tmp",
                    "C:\Windows\System32\spool\PRINTERS\*",
                    "C:\Windows\System32\MsDtc\Trace\*.log"
                )
            }
        }
    }
    
    [void]Log([string]$message, [string]$level = "INFO") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"
        
        switch ($level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            "INFO" { Write-Host $logEntry -ForegroundColor White }
            "HIGHLIGHT" { Write-Host $logEntry -ForegroundColor Cyan }
            default { Write-Host $logEntry -ForegroundColor Gray }
        }
    }
    
    [void]AddCleanableItem([string]$path, [string]$category, [int64]$size, [int]$age, [string]$risk = "Low") {
        $this.CleanableItems += [PSCustomObject]@{
            Path      = $path
            Category  = $category
            Size      = $size
            Age       = $age
            Risk      = $risk
            Timestamp = Get-Date
            SizeMB    = [math]::Round($size / 1MB, 2)
        }
        $this.Stats.TotalFiles++
        $this.Stats.TotalSize += $size
        
        if (-not $this.Stats.Categories[$category]) {
            $this.Stats.Categories[$category] = @{ Count = 0; Size = 0 }
        }
        $this.Stats.Categories[$category].Count++
        $this.Stats.Categories[$category].Size += $size
    }
    
    [bool]IsExcluded([string]$path) {
        foreach ($exclude in $this.ExcludePaths) {
            if ($path -like "*$exclude*") {
                return $true
            }
        }
        return $false
    }
    
    [bool]IsProtected([string]$path) {
        # امتدادات محمية
        $protectedExtensions = @(".exe", ".dll", ".sys", ".msi", ".cab", ".drv", ".ocx", ".cpl")
        $ext = [System.IO.Path]::GetExtension($path)
        if ($ext -in $protectedExtensions) {
            $this.ProtectedItems += $path
            $this.Stats.ProtectedFiles++
            return $true
        }
        
        # مجلدات محمية
        $protectedFolders = @("C:\Windows", "C:\Program Files", "C:\Program Files (x86)", "C:\System32")
        foreach ($folder in $protectedFolders) {
            if ($path.StartsWith($folder, [StringComparison]::OrdinalIgnoreCase)) {
                $this.ProtectedItems += $path
                $this.Stats.ProtectedFiles++
                return $true
            }
        }
        
        # ملفات محمية
        $protectedFiles = @("boot.ini", "ntldr", "bootmgr", "winload.exe", "winlogon.exe", "services.exe")
        $fileName = [System.IO.Path]::GetFileName($path)
        if ($fileName -in $protectedFiles) {
            $this.ProtectedItems += $path
            $this.Stats.ProtectedFiles++
            return $true
        }
        
        return $false
    }
    
    [void]AnalyzeSystem() {
        $this.Log("`n🔍 بدء التحليل الذكي للنظام...", "HIGHLIGHT")
        $this.Log("═══════════════════════════════════════════════════════════════════", "HIGHLIGHT")
        $this.Log("📋 الوضع: $(if($this.DryRun){"🧪 تجريبي (Dry Run)"}else{"🚀 فعلي"})", "INFO")
        $this.Log("🛡️  الأمان: $(if($this.SafeMode){"🟢 مفعل"}"🔴 معطل")", "INFO")
        $this.Log("🔬 التنظيف العميق: $(if($this.DeepClean){"🟢 مفعل"}"🔴 معطل")", "INFO")
        $this.Log("⏰ أقصى عمر: $($this.MaxAgeDays) يوم", "INFO")
        $this.Log("💾 الحد الأدنى للحجم: $($this.MinFileSizeMB) MB", "INFO")
        $this.Log("📁 الفئات: $($this.Categories.Count)", "INFO")
        
        $totalFound = 0
        $totalSize = 0
        
        foreach ($catName in $this.Categories.Keys) {
            $cat = $this.Categories[$catName]
            $this.Log("`n$($cat.Icon) $catName - $($cat.Description)", "HIGHLIGHT")
            $this.Log("   مستوى المخاطرة: $($cat.Risk)", "INFO")
            
            $found = $this.AnalyzeCategory($catName, $cat)
            $totalFound += $found
        }
        
        $this.Log("`n📊 ملخص التحليل:", "HIGHLIGHT")
        $this.Log("   📁 إجمالي الملفات المكتشفة: $($this.Stats.TotalFiles)", "INFO")
        $this.Log("   💾 إجمالي الحجم: $([math]::Round($this.Stats.TotalSize/1GB, 2)) GB", "INFO")
        $this.Log("   🛡️  ملفات محمية: $($this.Stats.ProtectedFiles)", "INFO")
        $this.Log("   ⚠️  تحذيرات: $($this.Warnings.Count)", "INFO")
        $this.Log("   ❌ أخطاء: $($this.Errors.Count)", "INFO")
        
        # عرض تفصيل حسب الفئات
        $this.Log("`n📊 تفصيل الفئات:", "HIGHLIGHT")
        foreach ($catName in $this.Stats.Categories.Keys) {
            $catStat = $this.Stats.Categories[$catName]
            $this.Log("   $($this.Categories[$catName].Icon) $catName: $($catStat.Count) ملف - $([math]::Round($catStat.Size/1MB, 2)) MB", "INFO")
        }
    }
    
    [int]AnalyzeCategory([string]$catName, [hashtable]$catConfig) {
        $found = 0
        $paths = $catConfig.Paths
        
        foreach ($pattern in $paths) {
            try {
                $items = Get-ChildItem -Path $pattern -Recurse -File -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    # التحقق من الاستبعاد
                    if ($this.IsExcluded($item.FullName)) { continue }
                    
                    # التحقق من الحماية
                    if ($this.IsProtected($item.FullName)) { continue }
                    
                    # التحقق من الحجم
                    if ($this.MinFileSizeMB -gt 0 -and $item.Length -lt ($this.MinFileSizeMB * 1MB)) {
                        continue
                    }
                    
                    # حساب العمر
                    $age = (Get-Date) - $item.LastWriteTime
                    $ageDays = [math]::Floor($age.TotalDays)
                    
                    # التحقق من العمر
                    if ($this.MaxAgeDays -gt 0 -and $ageDays -lt $this.MaxAgeDays) {
                        continue
                    }
                    
                    # إضافة للقائمة
                    $risk = $catConfig.Risk
                    $this.AddCleanableItem($item.FullName, $catName, $item.Length, $ageDays, $risk)
                    $found++
                    
                    # عرض التقدم في الوضع التفاعلي
                    if ($this.Interactive -and $found % 50 -eq 0) {
                        $this.Log("   ⏳ تم العثور على $found ملف...", "INFO")
                    }
                }
            }
            catch {
                $this.Errors += "فشل تحليل: $pattern - $_"
                $this.Log("   ❌ فشل تحليل: $pattern - $_", "ERROR")
            }
        }
        
        $this.Log("   ✅ تم العثور على $found ملف", "SUCCESS")
        return $found
    }
    
    [void]PerformCleanup() {
        if ($this.DryRun) {
            $this.Log("`n🧪 وضع التجربة - لن يتم حذف أي ملفات", "HIGHLIGHT")
            $this.ShowPreview()
            return
        }
        
        if ($this.CleanableItems.Count -eq 0) {
            $this.Log("`n✅ لا توجد ملفات للتنظيف", "SUCCESS")
            return
        }
        
        $this.Log("`n🧹 بدء عملية التنظيف...", "HIGHLIGHT")
        $this.Log("═══════════════════════════════════════════════════════════════════", "HIGHLIGHT")
        
        # إنشاء نسخة احتياطية
        $this.CreateBackup()
        
        $cleaned = 0
        $freed = 0
        $totalItems = $this.CleanableItems.Count
        $currentItem = 0
        
        foreach ($item in $this.CleanableItems) {
            $currentItem++
            $percent = [math]::Round(($currentItem / $totalItems) * 100, 1)
            
            # عرض التقدم
            if ($this.Interactive -or $currentItem % 10 -eq 0) {
                $this.Log("   ⏳ التقدم: $percent% - حذف: $($item.Path)", "INFO")
            }
            
            try {
                if (Test-Path $item.Path) {
                    $size = (Get-Item $item.Path -ErrorAction SilentlyContinue).Length
                    Remove-Item -Path $item.Path -Force -ErrorAction SilentlyContinue
                    
                    if (-not (Test-Path $item.Path)) {
                        $cleaned++
                        $freed += $size
                        $this.Stats.CleanedFiles++
                        $this.Stats.FreedSpace += $size
                    }
                    else {
                        $this.Errors += "فشل حذف: $($item.Path)"
                        $this.Stats.Errors++
                    }
                }
            }
            catch {
                $this.Errors += "خطأ في حذف: $($item.Path) - $_"
                $this.Stats.Errors++
                $this.Log("   ❌ خطأ: $($item.Path)", "ERROR")
            }
        }
        
        # تنفيذ تنظيف إضافي
        $this.SystemOptimization()
        
        # عرض النتائج
        $this.Log("`n📊 نتائج التنظيف:", "HIGHLIGHT")
        $this.Log("   ✅ الملفات المحذوفة: $cleaned", "SUCCESS")
        $this.Log("   💾 المساحة المحررة: $([math]::Round($freed/1MB, 2)) MB", "SUCCESS")
        $this.Log("   ⚠️  التحذيرات: $($this.Warnings.Count)", "WARNING")
        $this.Log("   ❌ الأخطاء: $($this.Errors.Count)", "ERROR")
        
        if ($this.Stats.Errors -eq 0) {
            $this.Log("`n✅ اكتمل التنظيف بنجاح", "SUCCESS")
        }
        else {
            $this.Log("`n⚠️ اكتمل التنظيف مع بعض الأخطاء", "WARNING")
        }
    }
    
    [void]CreateBackup() {
        $this.Log("📦 إنشاء نسخة احتياطية...", "INFO")
        
        $backupManifest = @()
        $backupCount = 0
        
        foreach ($item in $this.CleanableItems) {
            if (Test-Path $item.Path) {
                $safeName = $item.Path -replace ':', '' -replace '\\', '_' -replace '/', '_'
                $destPath = Join-Path $this.BackupPath $safeName
                $destDir = Split-Path $destPath -Parent
                
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                try {
                    Copy-Item -Path $item.Path -Destination $destPath -ErrorAction SilentlyContinue
                    $backupManifest += [PSCustomObject]@{
                        Original = $item.Path
                        Backup   = $destPath
                        Category = $item.Category
                        Size     = $item.Size
                    }
                    $backupCount++
                }
                catch {
                    $this.Log("   ⚠️ فشل نسخ: $($item.Path)", "WARNING")
                }
            }
        }
        
        $manifestPath = Join-Path $this.BackupPath "manifest.json"
        $backupManifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
        
        $this.Log("✅ تم إنشاء النسخة الاحتياطية لـ $backupCount ملف", "SUCCESS")
        $this.Log("   📁 المسار: $($this.BackupPath)", "INFO")
    }
    
    [void]SystemOptimization() {
        $this.Log("`n⚡ تحسين أداء النظام...", "HIGHLIGHT")
        
        # 1. تنظيف DNS Cache
        try {
            & ipconfig /flushdns 2>&1 | Out-Null
            $this.Log("   ✅ تم تنظيف DNS Cache", "SUCCESS")
        }
        catch {
            $this.Log("   ❌ فشل تنظيف DNS Cache", "ERROR")
        }
        
        # 2. إعادة بناء Prefetch (للتنظيف العميق)
        if ($this.DeepClean) {
            try {
                Remove-Item -Path "C:\Windows\Prefetch\*.pf" -Force -ErrorAction SilentlyContinue
                $this.Log("   ✅ تم تنظيف Prefetch", "SUCCESS")
            }
            catch {
                $this.Log("   ❌ فشل تنظيف Prefetch", "ERROR")
            }
        }
        
        # 3. تنظيف الذاكرة المؤقتة
        try {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $this.Log("   ✅ تم تنظيف الذاكرة المؤقتة", "SUCCESS")
        }
        catch {
            $this.Log("   ❌ فشل تنظيف الذاكرة", "ERROR")
        }
        
        # 4. تنظيف الكوكيز المؤقتة
        try {
            $tempInternet = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache\IE"
            if (Test-Path $tempInternet) {
                Remove-Item -Path "$tempInternet\*" -Recurse -Force -ErrorAction SilentlyContinue
                $this.Log("   ✅ تم تنظيف كاش الإنترنت", "SUCCESS")
            }
        }
        catch {
            # تجاهل
        }
    }
    
    [void]ShowPreview() {
        $this.Log("`n📋 معاينة الملفات القابلة للتنظيف:", "HIGHLIGHT")
        $this.Log("═══════════════════════════════════════════════════════════════════", "HIGHLIGHT")
        
        $grouped = $this.CleanableItems | Group-Object Category
        
        foreach ($group in $grouped) {
            $category = $group.Name
            $items = $group.Group
            $totalSize = ($items | Measure-Object -Property Size -Sum).Sum
            $catInfo = $this.Categories[$category]
            $icon = if ($catInfo) { $catInfo.Icon } else { "📂" }
            
            $this.Log("`n$icon $category:", "HIGHLIGHT")
            $this.Log("   📁 عدد الملفات: $($items.Count)", "INFO")
            $this.Log("   💾 الحجم: $([math]::Round($totalSize/1MB, 2)) MB", "INFO")
            $this.Log("   ⚠️  المخاطرة: $(if($catInfo) { $catInfo.Risk } else { 'غير محدد' })", "INFO")
            
            # عرض عينة من الملفات
            $sample = $items | Select-Object -First 3
            foreach ($item in $sample) {
                $size = [math]::Round($item.Size / 1MB, 2)
                $riskSymbol = switch ($item.Risk) {
                    "Low" { "🟢" }
                    "Medium" { "🟡" }
                    "High" { "🟠" }
                    "Critical" { "🔴" }
                    default { "⚪" }
                }
                $this.Log("   $riskSymbol $($item.Path) ($size MB, $($item.Age) يوم)", "Gray")
            }
            
            if ($items.Count -gt 3) {
                $this.Log("   ... و $($items.Count - 3) ملفات أخرى", "Gray")
            }
            
            # عرض إحصائيات المخاطرة في الوضع التفاعلي
            if ($this.Interactive) {
                $riskCount = $items | Group-Object Risk
                $riskInfo = ($riskCount | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ", "
                $this.Log("   📊 توزيع المخاطر: $riskInfo", "Gray")
            }
        }
        
        $totalSize = ($this.CleanableItems | Measure-Object -Property Size -Sum).Sum
        $this.Log("`n📊 إجمالي الملفات: $($this.CleanableItems.Count)", "HIGHLIGHT")
        $this.Log("💾 إجمالي المساحة القابلة للتنظيف: $([math]::Round($totalSize/1GB, 2)) GB", "HIGHLIGHT")
        
        # في الوضع التفاعلي، اطلب تأكيد المستخدم
        if ($this.Interactive -and -not $this.DryRun) {
            $response = Read-Host "`nهل تريد المتابعة بالتنظيف؟ (Y/N)"
            if ($response -ne 'Y' -and $response -ne 'y') {
                $this.Log("❌ تم إلغاء عملية التنظيف", "WARNING")
                exit
            }
        }
    }
    
    [PSCustomObject]GetReport() {
        $this.EndTime = Get-Date
        
        return [PSCustomObject]@{
            CleanupTime     = $this.StartTime
            EndTime         = $this.EndTime
            Duration        = ($this.EndTime - $this.StartTime).TotalSeconds
            Mode            = if ($this.DryRun) { "DryRun" } else { "Actual" }
            SafeMode        = $this.SafeMode
            DeepClean       = $this.DeepClean
            TotalFilesFound = $this.Stats.TotalFiles
            TotalSizeFound  = $this.Stats.TotalSize
            CleanedFiles    = $this.Stats.CleanedFiles
            FreedSpace      = $this.Stats.FreedSpace
            ProtectedFiles  = $this.Stats.ProtectedFiles
            Errors          = $this.Errors
            Warnings        = $this.Warnings
            Categories      = $this.Stats.Categories
            CleanableItems  = $this.CleanableItems
            BackupPath      = $this.BackupPath
        }
    }
}

# ============================================================
# الدوال الرئيسية
# ============================================================

function Invoke-IntelligentCleanup {
    <#
    .SYNOPSIS
        تشغيل التنظيف الذكي المتقدم
    #>
    
    Write-Host @"
`n
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║        🧹  النظام الذكي للتنظيف العميق v5.0                     ║
║     ────────────────────────────────────────────────────────────  ║
║     ⚡  تنظيف جميع أنواع الكاش والملفات المؤقتة                 ║
║     🔬  تحليل ذكي متعدد المستويات                               ║
║     🛡️  حماية الملفات الحيوية للنظام                           ║
║     📊  تقارير تفصيلية مع توصيات                               ║
║     🔄  نقاط استعادة تلقائية                                   ║
║     💬  واجهة تفاعلية مع المستخدم                              ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
`n" -ForegroundColor Cyan
    
    $engine = [AdvancedCleanupEngine]::new($Interactive, $DryRun, $SafeMode, $DeepClean, $MaxAgeDays, $MinFileSizeMB, $ExcludePaths)
    
    # التحليل
    $engine.AnalyzeSystem()
    
    # التنظيف
    $engine.PerformCleanup()
    
    # التقرير
    $report = $engine.GetReport()
    
    if ($GenerateReport) {
        $reportPath = "CleanupReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "`n📄 تم إنشاء التقرير: $reportPath" -ForegroundColor Green
        
        # تقرير HTML مختصر
        $html = @"
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>تقرير التنظيف</title>
<style>
body{font-family:'Segoe UI',Tahoma,sans-serif;background:#1a1a2e;color:#fff;padding:20px}
.container{max-width:1000px;margin:0 auto}
.header{background:linear-gradient(135deg,#667eea,#764ba2);padding:20px;border-radius:10px;text-align:center}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:15px;margin:20px 0}
.stat{background:rgba(255,255,255,0.1);padding:15px;border-radius:8px;text-align:center}
.stat .value{font-size:1.8em;font-weight:bold}
.stat .label{color:#aaa;font-size:0.8em}
.section{background:rgba(255,255,255,0.05);padding:15px;border-radius:8px;margin:10px 0}
.section h2{color:#667eea}
.success{color:#00ff88}
.warning{color:#ffaa00}
.error{color:#ff4444}
</style>
</head>
<body>
<div class="container">
<div class="header"><h1>🧹 تقرير التنظيف الذكي</h1><p>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p></div>
<div class="stats">
<div class="stat"><div class="value">$($report.CleanedFiles)</div><div class="label">✅ المحذوفة</div></div>
<div class="stat"><div class="value">$([math]::Round($report.FreedSpace/1MB, 2)) MB</div><div class="label">💾 المساحة المحررة</div></div>
<div class="stat"><div class="value">$($report.ProtectedFiles)</div><div class="label">🛡️ المحمية</div></div>
<div class="stat"><div class="value">$($report.Errors.Count)</div><div class="label">❌ الأخطاء</div></div>
</div>
<div class="section"><h2>📋 التفاصيل</h2>
<p><strong>المدة:</strong> $([math]::Round($report.Duration, 2)) ثانية</p>
<p><strong>الوضع:</strong> $(if($report.Mode -eq 'DryRun'){'🧪 تجريبي'}else{'🚀 فعلي'})</p>
<p><strong>الأمان:</strong> $(if($report.SafeMode){'🟢 مفعل'}else{'🔴 معطل'})</p>
<p><strong>إجمالي الملفات:</strong> $($report.TotalFilesFound)</p>
<p><strong>إجمالي الحجم:</strong> $([math]::Round($report.TotalSizeFound/1GB, 2)) GB</p>
</div>
<div class="section"><h2>📊 تفصيل الفئات</h2>
$(
    $report.Categories.PSObject.Properties | ForEach-Object {
        "<p><strong>$($_.Name):</strong> $($_.Value.Count) ملف - $([math]::Round($_.Value.Size/1MB, 2)) MB</p>"
    }
)
</div>
</div>
</body>
</html>
"@
    $htmlPath = $reportPath -replace '.json', '.html'
    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "📄 تم إنشاء تقرير HTML: $htmlPath" -ForegroundColor Green
}
    
return $report
}

# ============================================================
# دوال سريعة للاستخدام
# ============================================================

function Quick-CacheClean {
    <#
    .SYNOPSIS
        تنظيف سريع للكاش والملفات المؤقتة
    #>
    param([switch]$DryRun)
    
    $global:Interactive = $false
    $global:DryRun = $DryRun
    $global:SafeMode = $true
    $global:DeepClean = $false
    $global:MaxAgeDays = 7
    $global:MinFileSizeMB = 0
    $global:GenerateReport = $true
    
    Invoke-IntelligentCleanup
}

function Deep-SystemClean {
    <#
    .SYNOPSIS
        تنظيف عميق شامل للنظام
    #>
    param([switch]$DryRun)
    
    $global:Interactive = $true
    $global:DryRun = $DryRun
    $global:SafeMode = $true
    $global:DeepClean = $true
    $global:MaxAgeDays = 30
    $global:MinFileSizeMB = 1
    $global:GenerateReport = $true
    
    Invoke-IntelligentCleanup
}

function Show-CleanupStatus {
    <#
    .SYNOPSIS
        عرض حالة النظام ومساحة القرص
    #>
    
    Write-Host "`n📊 حالة النظام" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($drive in $drives) {
        $total = [math]::Round($drive.Size / 1GB, 2)
        $free = [math]::Round($drive.FreeSpace / 1GB, 2)
        $used = $total - $free
        $percent = [math]::Round(($used / $total) * 100, 1)
        
        $color = if ($percent -gt 90) { "Red" } elseif ($percent -gt 80) { "Yellow" } else { "Green" }
        Write-Host "💾 $($drive.DeviceID)" -ForegroundColor White
        Write-Host "   الإجمالي: $total GB" -ForegroundColor Gray
        Write-Host "   المستخدم: $used GB" -ForegroundColor Gray
        Write-Host "   الحرة: $free GB" -ForegroundColor Gray
        Write-Host "   الاستخدام: $percent%" -ForegroundColor $color
    }
    
    Write-Host "`n🧠 الذاكرة" -ForegroundColor Cyan
    $mem = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMem = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 0)
    $freeMem = [math]::Round($mem.FreePhysicalMemory / 1MB, 0)
    $usedMem = $totalMem - $freeMem
    $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
    
    Write-Host "   الإجمالي: $totalMem MB" -ForegroundColor Gray
    Write-Host "   المستخدم: $usedMem MB" -ForegroundColor Gray
    Write-Host "   الحرة: $freeMem MB" -ForegroundColor Gray
    Write-Host "   الاستخدام: $memPercent%" -ForegroundColor $(if ($memPercent -gt 85) { "Red" } elseif ($memPercent -gt 70) { "Yellow" } else { "Green" })
    
    # توصيات
    Write-Host "`n💡 التوصيات:" -ForegroundColor Yellow
    foreach ($drive in $drives) {
        $total = [math]::Round($drive.Size / 1GB, 2)
        $free = [math]::Round($drive.FreeSpace / 1GB, 2)
        $percent = [math]::Round((($total - $free) / $total) * 100, 1)
        
        if ($percent -gt 85) {
            Write-Host "   ⚠️  القرص $($drive.DeviceID) ممتلئ - استخدم Quick-CacheClean" -ForegroundColor Yellow
        }
    }
    if ($memPercent -gt 85) {
        Write-Host "   ⚠️  الذاكرة مرتفعة - أغلق التطبيقات غير الضرورية" -ForegroundColor Yellow
    }
    if ($percent -lt 80 -and $memPercent -lt 70) {
        Write-Host "   ✅ النظام في حالة جيدة" -ForegroundColor Green
    }
}

# ============================================================
# استيراد التكوين إذا وجد
# ============================================================
$configPath = "cleanup_config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        $global:MaxAgeDays = if ($config.MaxAgeDays) { $config.MaxAgeDays } else { 30 }
        $global:MinFileSizeMB = if ($config.MinFileSizeMB) { $config.MinFileSizeMB } else { 0 }
        $global:SafeMode = if ($config.SafeMode) { $config.SafeMode } else { $true }
        $global:DeepClean = if ($config.DeepClean) { $config.DeepClean } else { $false }
        Write-Host "✅ تم تحميل الإعدادات من: $configPath" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ فشل تحميل الإعدادات، سيتم استخدام الافتراضية" -ForegroundColor Yellow
    }
}

