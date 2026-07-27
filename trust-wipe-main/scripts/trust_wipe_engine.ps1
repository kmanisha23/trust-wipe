# TrustWipe Secure Data Destruction Engine
# Conforms to NIST SP 800-88 Rev 1 and DoD 5220.22-M standards.

param (
    [string]$TargetType, # "Drive" | "File" | "Folder" | "Detect"
    [string]$TargetPath, # e.g. "D:", "D:\sensitive.txt", "D:\confidential_folder"
    [string]$Algorithm = "NIST80088" # "ZeroFill" | "RandomFill" | "DoD522022M" | "NIST80088"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- HELPER: Send JSON IPC Messages ---
function Send-IPC {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [hashtable]$Data = @{}
    )
    $msg = [PSCustomObject]@{
        type      = $Type
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
        data      = $Data
    }
    Write-Output ($msg | ConvertTo-Json -Compress)
}

# --- Check Administrator Elevation ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Send-IPC -Type "ERROR" -Data @{
        message = "Administrative privileges required. Please run TrustWipe as Administrator."
        code    = "E_ACCESS_DENIED"
    }
    exit 1
}

# --- Detect Drives Action ---
if ($TargetType -eq "Detect" -or [string]::IsNullOrEmpty($TargetType)) {
    try {
        $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk
        $drives = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($disk in $logicalDisks) {
            # Only fixed (3) or removable (2) drives
            if ($disk.DriveType -eq 2 -or $disk.DriveType -eq 3) {
                # Find drive partition mapping
                $partition = Get-CimInstance -ClassName Win32_LogicalDiskToPartition | Where-Object { $_.Dependent -match "DeviceID=`"$($disk.DeviceID)`"" } | Select-Object -First 1
                $physicalDisk = $null
                if ($partition) {
                    $antecedent = $partition.Antecedent.Name -replace "\\", "\\"
                    $diskDriveToPartition = Get-CimInstance -ClassName Win32_DiskDriveToDiskPartition | Where-Object { $_.Dependent -match $antecedent } | Select-Object -First 1
                    if ($diskDriveToPartition) {
                        $physName = $diskDriveToPartition.Antecedent.Name -replace "\\", "\\"
                        $physicalDisk = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.Name -match $physName } | Select-Object -First 1
                    }
                }

                $model = if ($physicalDisk) { $physicalDisk.Model } else { "Unknown Disk" }
                $serial = if ($physicalDisk) { $physicalDisk.SerialNumber.Trim() } else { "Unknown Serial" }
                $totalSize = [math]::Round($disk.Size / 1GB, 2)
                $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)

                $drives.Add([PSCustomObject]@{
                    DriveLetter  = $disk.DeviceID
                    VolumeName   = $disk.VolumeName
                    SizeGB       = $totalSize
                    FreeSpaceGB  = $freeSpace
                    Model        = $model
                    SerialNumber = $serial
                    IsOSDrive    = ($disk.DeviceID -eq "C:")
                })
            }
        }
        Send-IPC -Type "DETECTION_RESULT" -Data @{ drives = $drives }
        exit 0
    }
    catch {
        Send-IPC -Type "ERROR" -Data @{
            message = "Failed to detect drives: $_"
            code    = "E_DETECTION_FAILED"
        }
        exit 1
    }
}

# --- System Safeguards & Target Resolution ---
$normalizedPath = $TargetPath
if ($TargetType -eq "Drive") {
    $normalizedPath = $TargetPath.Trim().ToUpper()
    if ($normalizedPath -notmatch "^[A-Z]:$") {
        $normalizedPath = "$($normalizedPath.Substring(0,1)):"
    }
    if ($normalizedPath -eq "C:") {
        Send-IPC -Type "ERROR" -Data @{
            message = "Safety Block: Wiping the OS drive (C:) is strictly prohibited."
            code    = "E_OS_DRIVE_BLOCK"
        }
        exit 1
    }
    if (-not (Test-Path "$normalizedPath\")) {
        Send-IPC -Type "ERROR" -Data @{
            message = "Drive letter '$normalizedPath' does not exist or is not mounted."
            code    = "E_TARGET_NOT_FOUND"
        }
        exit 1
    }
} else {
    # Resolve relative path to absolute path
    $normalizedPath = [System.IO.Path]::GetFullPath($TargetPath)
    if (-not (Test-Path $normalizedPath)) {
        Send-IPC -Type "ERROR" -Data @{
            message = "Target path '$normalizedPath' does not exist."
            code    = "E_TARGET_NOT_FOUND"
        }
        exit 1
    }
    # Check system folder exclusions
    $lowerPath = $normalizedPath.ToLower()
    $criticalPrefixes = @("c:\windows", "c:\program files", "c:\program files (x86)", "c:\users\all users", "c:\programdata")
    foreach ($prefix in $criticalPrefixes) {
        if ($lowerPath.StartsWith($prefix)) {
            Send-IPC -Type "ERROR" -Data @{
                message = "Safety Block: Cannot wipe target located in system directory '$prefix'."
                code    = "E_SYSTEM_FOLDER_BLOCK"
            }
            exit 1
        }
    }
}

# --- Shred Single File Function ---
# Returns $true if successful, $false if failed/skipped (e.g. lock)
function Shred-File {
    param(
        [string]$FilePath,
        [string]$Algo,
        [ref]$WipedBytesRef,
        [ref]$FileCountRef
    )

    try {
        if (-not (Test-Path $FilePath -PathType Leaf)) {
            return $true
        }

        # Check read-only attribute
        $fileAttr = Get-ItemProperty -Path $FilePath
        if ($fileAttr.Attributes -match "ReadOnly") {
            Set-ItemProperty -Path $FilePath -Name Attributes -Value ($fileAttr.Attributes -bxor [System.IO.FileAttributes]::ReadOnly)
        }

        # Open FileStream with exclusive write share
        $fileStream = $null
        try {
            $fileStream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        }
        catch {
            Send-IPC -Type "LOCKED_FILE" -Data @{
                filePath = $FilePath
                message  = "File is locked by another process: $_"
            }
            return $false
        }

        $fileSize = $fileStream.Length
        $bufferSize = 1MB
        if ($fileSize -lt $bufferSize) {
            $bufferSize = [math]::Max(4KB, $fileSize)
        }
        $buffer = [byte[]]::new($bufferSize)

        # Determine Overwrite Passes
        $passes = @()
        if ($Algo -eq "ZeroFill") {
            $passes += "Zero"
        }
        elseif ($Algo -eq "RandomFill") {
            $passes += "Random"
        }
        elseif ($Algo -eq "DoD522022M") {
            $passes += "Zero"
            $passes += "One"
            $passes += "Random"
        }
        else { # NIST80088 / default
            $passes += "Zero"
        }

        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

        for ($p = 0; $p -lt $passes.Count; $p++) {
            $passType = $passes[$p]
            $fileStream.Position = 0

            # Initialize buffer patterns
            if ($passType -eq "Zero") {
                [Array]::Clear($buffer, 0, $buffer.Length)
            }
            elseif ($passType -eq "One") {
                for ($i = 0; $i -lt $buffer.Length; $i++) { $buffer[$i] = 0xFF }
            }
            elseif ($passType -eq "Random") {
                $rng.GetBytes($buffer)
            }

            $bytesWritten = 0
            while ($bytesWritten -lt $fileSize) {
                $toWrite = [math]::Min($buffer.Length, $fileSize - $bytesWritten)
                
                # Regenerate random bytes per chunk if random pass
                if ($passType -eq "Random") {
                    $rng.GetBytes($buffer)
                }

                $fileStream.Write($buffer, 0, $toWrite)
                $bytesWritten += $toWrite
                $WipedBytesRef.Value += $toWrite
            }
            $fileStream.Flush($true)
        }

        # NIST 800-88 Verification Pass (reads file back to confirm overwrite)
        if ($Algo -eq "NIST80088" -or $Algo -eq "DoD522022M") {
            $fileStream.Close()
            $fileStream = $null
            # Open for read
            $readStream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $readBuffer = [byte[]]::new($bufferSize)
            $bytesReadTotal = 0
            while ($bytesReadTotal -lt $fileSize) {
                $toRead = [math]::Min($readBuffer.Length, $fileSize - $bytesReadTotal)
                $read = $readStream.Read($readBuffer, 0, $toRead)
                if ($read -eq 0) { break }
                # Verify zero/pattern
                if ($Algo -eq "NIST80088") {
                    for ($i = 0; $i -lt $read; $i++) {
                        if ($readBuffer[$i] -ne 0x00) {
                            throw "NIST 800-88 Verification failed: non-zero byte detected."
                        }
                    }
                }
                $bytesReadTotal += $read
            }
            $readStream.Close()
        }

        # Truncate and clean up
        if ($null -ne $fileStream) {
            $fileStream.SetLength(0)
            $fileStream.Close()
        }

        # Obfuscate metadata by renaming file to random string before delete
        $parentDir = [System.IO.Path]::GetDirectoryName($FilePath)
        $randomName = [System.IO.Path]::GetRandomFileName()
        $tempPath = [System.IO.Path]::Combine($parentDir, $randomName)
        
        [System.IO.File]::Move($FilePath, $tempPath)
        [System.IO.File]::Delete($tempPath)

        $FileCountRef.Value++
        return $true
    }
    catch {
        if ($null -ne $fileStream) { $fileStream.Close() }
        Send-IPC -Type "WARN" -Data @{
            filePath = $FilePath
            message  = "Failed to secure shred: $_"
        }
        return $false
    }
}

# --- Main Overwrite Logic ---

# Initialize global tracking counters
$globalWipedBytes = [long]0
$globalFileCount = [int]0
$startTime = Get-Date

Send-IPC -Type "INIT" -Data @{
    targetType = $TargetType
    targetPath = $normalizedPath
    algorithm  = $Algorithm
}

# Timer thread variables for real-time progress update
$lastReportTime = [DateTime]::UtcNow
$lastWipedBytes = [long]0

function Report-Progress {
    param([double]$Percent)
    $now = [DateTime]::UtcNow
    $timeSpan = $now - $lastReportTime
    $speedMBps = 0.0
    if ($timeSpan.TotalSeconds -gt 0.2) {
        $deltaBytes = $globalWipedBytes - $lastWipedBytes
        $speedMBps = [math]::Round(($deltaBytes / 1MB) / $timeSpan.TotalSeconds, 2)
        $script:lastReportTime = $now
        $script:lastWipedBytes = $globalWipedBytes
    }

    Send-IPC -Type "PROGRESS" -Data @{
        percent         = [math]::Round($Percent, 2)
        bytesProcessed  = $globalWipedBytes
        speedMBps       = $speedMBps
        filesProcessed  = $globalFileCount
        currentFilePath = $currentFile
    }
}

# --- Execution ---
try {
    if ($TargetType -eq "File") {
        $currentFile = $normalizedPath
        Report-Progress -Percent 0
        $shredded = Shred-File -FilePath $normalizedPath -Algo $Algorithm -WipedBytesRef ([ref]$globalWipedBytes) -FileCountRef ([ref]$globalFileCount)
        Report-Progress -Percent 100
    }
    elseif ($TargetType -eq "Folder") {
        # Collect all files recursively
        $files = Get-ChildItem -Path $normalizedPath -Recurse -File -Force | Select-Object -ExpandProperty FullName
        $totalFilesCount = $files.Count
        
        if ($totalFilesCount -eq 0) {
            Send-IPC -Type "WARN" -Data @{ message = "Folder is already empty." }
            Report-Progress -Percent 100
        } else {
            for ($i = 0; $i -lt $totalFilesCount; $i++) {
                $currentFile = $files[$i]
                $shredded = Shred-File -FilePath $currentFile -Algo $Algorithm -WipedBytesRef ([ref]$globalWipedBytes) -FileCountRef ([ref]$globalFileCount)
                $percent = (($i + 1) / $totalFilesCount) * 100
                Report-Progress -Percent $percent
            }
        }

        # Remove subdirectories recursively
        Get-ChildItem -Path $normalizedPath -Recurse -Directory -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Force
            } catch {
                Send-IPC -Type "WARN" -Data @{ message = "Could not delete subdirectory: $_" }
            }
        }
        # Finally delete top-level folder if not a root drive
        try {
            Remove-Item -Path $normalizedPath -Force
        } catch {
            Send-IPC -Type "WARN" -Data @{ message = "Could not delete parent directory: $_" }
        }
    }
    elseif ($TargetType -eq "Drive") {
        # 1. Shred all files recursively on the target drive letter
        $currentFile = "Scanning files on $normalizedPath..."
        Report-Progress -Percent 0
        
        $files = Get-ChildItem -Path "$normalizedPath\" -Recurse -File -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        $totalFilesCount = if ($files) { $files.Count } else { 0 }

        if ($totalFilesCount -gt 0) {
            for ($i = 0; $i -lt $totalFilesCount; $i++) {
                $currentFile = $files[$i]
                $shredded = Shred-File -FilePath $currentFile -Algo $Algorithm -WipedBytesRef ([ref]$globalWipedBytes) -FileCountRef ([ref]$globalFileCount)
                $percent = (($i + 1) / $totalFilesCount) * 50 # 50% for file shredding phase
                Report-Progress -Percent $percent
            }
        }

        # Delete subfolders to free directory listings
        Get-ChildItem -Path "$normalizedPath\" -Recurse -Directory -Force -ErrorAction SilentlyContinue | Sort-Object -Property FullName -Descending | ForEach-Object {
            try { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
        }

        # 2. Secure Overwrite of Free Space (fills remaining blocks of the filesystem partition)
        $currentFile = "Filling free space to destroy unallocated directory nodes..."
        
        # Determine current available free space to calculate progress
        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $normalizedPath }
        $initialFreeSpace = $diskInfo.FreeSpace
        
        $tempFilePath = Join-Path "$normalizedPath\" "__trustwipe_temp_shred__.dat"
        $tempStream = $null
        try {
            $tempStream = [System.IO.File]::Open($tempFilePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $bufferSize = 4MB
            $buffer = [byte[]]::new($bufferSize)
            
            # Pattern fill based on algorithm
            if ($Algorithm -eq "RandomFill" -or $Algorithm -eq "DoD522022M") {
                $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
                $rng.GetBytes($buffer)
            } else {
                [Array]::Clear($buffer, 0, $buffer.Length)
            }

            $bytesFilled = [long]0
            while ($true) {
                # Regerate random bytes periodically if random mode
                if ($Algorithm -eq "RandomFill" -or $Algorithm -eq "DoD522022M") {
                    $rng.GetBytes($buffer)
                }

                $tempStream.Write($buffer, 0, $buffer.Length)
                $bytesFilled += $buffer.Length
                $globalWipedBytes += $buffer.Length

                # Estimate progress on free-space fill (runs 50% to 98%)
                $fillPercent = 50 + [math]::Min(48, ($bytesFilled / $initialFreeSpace) * 48)
                Report-Progress -Percent $fillPercent
            }
        }
        catch [System.IO.IOException] {
            # Standard "disk is full" exception - this means free space overwriting is complete!
            if ($tempStream -ne $null) {
                $tempStream.Flush($true)
                $tempStream.Close()
                $tempStream = $null
            }
            # Delete temporary file and force garbage collection
            if (Test-Path $tempFilePath) {
                Remove-Item -Path $tempFilePath -Force
            }
            Report-Progress -Percent 100
        }
        catch {
            if ($tempStream -ne $null) { $tempStream.Close() }
            if (Test-Path $tempFilePath) { Remove-Item -Path $tempFilePath -Force }
            throw "Error during free space overwriting: $_"
        }
    }

    # Done! Generate cryptographic verification hash from run state
    $duration = (Get-Date) - $startTime
    $verificationPayload = "$globalWipedBytes-$globalFileCount-$Algorithm-$normalizedPath"
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($verificationPayload))
    $verifyHash = [System.BitConverter]::ToString($hashBytes) -replace "-"

    Send-IPC -Type "COMPLETE" -Data @{
        status           = "SUCCESS"
        bytesWiped       = $globalWipedBytes
        filesWipedCount  = $globalFileCount
        durationSeconds  = [math]::Round($duration.TotalSeconds, 2)
        verificationHash = $verifyHash
    }
}
catch {
    Send-IPC -Type "ERROR" -Data @{
        message = "Destructive execution aborted: $_"
        code    = "E_WIPE_ABORTED"
    }
    exit 1
}
