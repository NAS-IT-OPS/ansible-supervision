# this file is use for telegraf report.
# In a future release, it will be automatisate

<#
        .SYNOPSIS
        PRTG Veeam Advanced Sensor
  
        .DESCRIPTION
        Advanced Sensor will Report Statistics about Backups during last 24 Hours and Actual Repository usage. It will then convert them into JSON, ready to add into InfluxDB and show it with Grafana
	
        .Notes
        NAME:  veeam-stats.ps1
        ORIGINAL NAME: PRTG-VeeamBRStats.ps1
        LASTEDIT: 22/01/2018
        VERSION: 0.3
        KEYWORDS: Veeam, PRTG
   
        .Link
        http://mycloudrevolution.com/
        Minor Edits and JSON output for Grafana by https://jorgedelacruz.es/
        Minor Edits from JSON to Influx for Grafana by r4yfx
 
 #Requires PS -Version 3.0
 #Requires -Modules VeeamPSSnapIn    
 #>
[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
        [string] $BRHost = "srvsqysauv02",
    [Parameter(Position=1, Mandatory=$false)]
        $reportMode = "Monthly", # Weekly, Monthly as String or Hour as Integer
    [Parameter(Position=2, Mandatory=$false)]
        $repoCritical = 10,
    [Parameter(Position=3, Mandatory=$false)]
        $repoWarn = 20
  
)
# You can find the original code for PRTG here, thank you so much Markus Kraus - https://github.com/mycloudrevolution/Advanced-PRTG-Sensors/blob/master/Veeam/PRTG-VeeamBRStats.ps1
# Big thanks to Shawn, creating a awsome Reporting Script:
# http://blog.smasterson.com/2016/02/16/veeam-v9-my-veeam-report-v9-0-1/

#region: Start Load VEEAM Snapin (if not already loaded)
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
	if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
		# Error out if loading fails
		Write-Error "`nERROR: Cannot load the VEEAM Snapin."
		Exit
	}
}
#endregion

#region: Functions
Function Get-vPCRepoInfo {
[CmdletBinding()]
        param (
                [Parameter(Position=0, ValueFromPipeline=$true)]
                [PSObject[]]$Repository
                )
        Begin {
                $outputAry = @()
                Function Build-Object {param($name, $repohost, $path, $free, $total)
                        $repoObj = New-Object -TypeName PSObject -Property @{
                                        Target = $name
										RepoHost = $repohost
                                        Storepath = $path
                                        StorageFree = [Math]::Round([Decimal]$free/1GB,2)
                                        StorageTotal = [Math]::Round([Decimal]$total/1GB,2)
                                        FreePercentage = [Math]::Round(($free/$total)*100)
                                }
                        Return $repoObj | Select Target, RepoHost, Storepath, StorageFree, StorageTotal, FreePercentage
                }
        }
        Process {
                Foreach ($r in $Repository) {
                	# Refresh Repository Size Info
					[Veeam.Backup.Core.CBackupRepositoryEx]::SyncSpaceInfoToDb($r, $true)
					
					If ($r.HostId -eq "00000000-0000-0000-0000-000000000000") {
						$HostName = ""
					}
					Else {
						$HostName = $($r.GetHost()).Name.ToLower()
					}
					$outputObj = Build-Object $r.Name $Hostname $r.Path $r.info.CachedFreeSpace $r.Info.CachedTotalSpace
					}
                $outputAry += $outputObj
        }
        End {
                $outputAry
        }
}
#endregion

#region: Start BRHost Connection
$OpenConnection = (Get-VBRServerSession).Server
if($OpenConnection -eq $BRHost) {
	
} elseif ($OpenConnection -eq $null ) {
	
	Connect-VBRServer -Server $BRHost
} else {
    
    Disconnect-VBRServer
   
    Connect-VBRServer -Server $BRHost
}

$NewConnection = (Get-VBRServerSession).Server
if ($NewConnection -eq $null ) {
	Write-Error "`nError: BRHost Connection Failed"
	Exit
}
#endregion

#region: Convert mode (timeframe) to hours
If ($reportMode -eq "Monthly") {
        $HourstoCheck = 720
} Elseif ($reportMode -eq "Weekly") {
        $HourstoCheck = 168
} Else {
        $HourstoCheck = $reportMode
}
#endregion

#region: Collect and filter Sessions
# $vbrserverobj = Get-VBRLocalhost        # Get VBR Server object
# $viProxyList = Get-VBRViProxy           # Get all Proxies
$repoList = Get-VBRBackupRepository     # Get all Repositories
$allSesh = Get-VBRBackupSession         # Get all Sessions to VM (Backup/BackupCopy/Replica)
$allSeshComp = Get-VBRComputerBackupJobSession         # Get all Sessions to physical
$allTapeJob = Get-VBRTapeJob         # Get all tape jobs
#$lastsession = (Get-VBRJob).FindLastSession()

$seshListBk = @($allSesh | ?{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "Backup"})           # Gather all Backup sessions within timeframe
#$seshListBkc = @($allSesh | ?{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "BackupSync"})      # Gather all BackupCopy sessions within timeframe
#$seshListRepl = @($allSesh | ?{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "Replica"})        # Gather all Replication sessions within timeframe
#$seshListBkComp = @($allSeshComp | ?{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck))})    						    # Gather all BackupComputer sessions within timeframe
#endregion

#region: Collect Jobs
 $allJobsBk = @(((Get-VBRJob -WarningAction ignore | ? {$_.JobType -eq "Backup"})).findlastsession())        # Gather Backup jobs
 $allJobsBkPhys = @(((Get-VBRJob -WarningAction ignore | ? {$_.JobType -eq "EpAgentBackup"})).findlastsession())        # Gather Backup EpAgentBackup jobs (physical machine)
 #$allJobsBkC = @((Get-VBRJob -WarningAction ignore | ? {$_.JobType -eq "BackupSync"}).findlastsession())   # Gather BackupCopy jobs
 #$repList = @((Get-VBRJob -WarningAction ignore | ?{$_.IsReplica}).findlastsession())                      # Get Replica jobs
#endregion

#region: Get Backup session informations
$totalxferBk = 0
$totalReadBk = 0
$seshListBk | %{$totalxferBk += $([Math]::Round([Decimal]$_.Progress.TransferedSize/1GB, 0))}
$seshListBk | %{$totalReadBk += $([Math]::Round([Decimal]$_.Progress.ReadSize/1GB, 0))}
#endregion


#region : split job by result
$successJobBk = @($allJobsBk | ?{$_.Result -eq "Success" })
$warningJobBk = @($allJobsBk | ?{$_.Result -eq "Warning" })
$failedJobBk = @($allJobsBk | ?{$_.Result -eq "Failed" })

$successJobBkPhys = @($allJobsBkPhys | ?{$_.Result -eq "Success" })
$warningJobBkPhys = @($allJobsBkPhys | ?{$_.Result -eq "Warning" })
$failedJobBkPhys = @($allJobsBkPhys | ?{$_.Result -eq "Failed" })
#endregion

#region : spit tape job by result
$successTapeBk = @($allTapeJob | ?{$_.LastResult -eq "Success" -and $_.Enabled -eq $true})
$warningTapeBk = @($allTapeJob | ?{$_.LastResult -eq "Warning" -and $_.Enabled -eq $true})
$failedTapeBk = @($allTapeJob | ?{$_.LastResult -eq "Failed" -and $_.Enabled -eq $true})
#endregion





#region: Repo Reports


$RepoReport = $repoList | Get-vPCRepoInfo | Select     @{Name="Repository Name"; Expression = {$_.Target}},
                                                       @{Name="Host"; Expression = {$_.RepoHost}},
                                                       @{Name="Path"; Expression = {$_.Storepath}},
                                                       @{Name="Free (GB)"; Expression = {$_.StorageFree}},
                                                       @{Name="Total (GB)"; Expression = {$_.StorageTotal}},
                                                       @{Name="Free (%)"; Expression = {$_.FreePercentage}},
                                                       @{Name="Status"; Expression = {
                                                       If ($_.FreePercentage -lt $repoCritical) {"Critical"} 
                                                       ElseIf ($_.FreePercentage -lt $repoWarn) {"Warning"}
                                                       ElseIf ($_.FreePercentage -eq "Unknown") {"Unknown"}
                                                       Else {"OK"}}} | `
                                                       Sort "Repository Name" 
#endregion

#region: Number of Endpoints
$number_endpoints = 0
foreach ($endpoint in Get-VBREPJob ) {
$number_endpoints++;
}
#endregion
 

#region: Influxdb Output for Telegraf

# tape
$Count = $successTapeBk.Count
$body="veeam-stats successTapeBk=$Count"
Write-Host $body
$Count = $warningTapeBk.Count
$body="veeam-stats warningTapeBk=$Count"
Write-Host $body
$Count = $failedTapeBk.Count
$body="veeam-stats failedTapeBk=$Count"
Write-Host $body

# backup vm
$Count = $successJobBk.Count
$body="veeam-stats successJobBk=$Count"
Write-Host $body
$Count = $warningJobBk.Count
$body="veeam-stats warningJobBk=$Count"
Write-Host $body
$Count = $failedJobBk.Count
$body="veeam-stats failedJobBk=$Count"
Write-Host $body

# backup phys

# backup
$Count = $successJobBkPhys.Count
$body="veeam-stats successJobBkPhys=$Count"
Write-Host $body
$Count = $warningJobBkPhys.Count
$body="veeam-stats warningJobBkPhys=$Count"
Write-Host $body
$Count = $failedJobBkPhys.Count
$body="veeam-stats failedJobBkPhys=$Count"
Write-Host $body

# read transfer
$body="veeam-stats totalbackupread=$totalReadBk"
Write-Host $body
$body="veeam-stats totalbackuptransfer=$totalxferBk"
Write-Host $body

#endpoint
$body="veeam-stats protectedendpoints=$number_endpoints"
Write-Host $body

#repo
foreach ($Repo in $RepoReport){
$Name = "REPO " + $Repo."Repository Name" -replace '\s','_'
$Free = $Repo."Free (%)"
$body="veeam-stats $Name=$Free"
Write-Host $body
	}



#endregion

#region: Debug
if ($DebugPreference -eq "Inquire") {
	$RepoReport | ft * -Autosize
    
    $SessionObject = [PSCustomObject] @{
	    "Successful Backups"  = $successSessionsBk.Count
	    "Warning Backups" = $warningSessionsBk.Count
	    "Failes Backups" = $failsSessionsBk.Count
	    "Failed Backups" = $failedSessionsBk.Count
	    "Running Backups" = $runningSessionsBk.Count
	    "Warning BackupCopys" = $warningSessionsBkC.Count
	    "Failes BackupCopys" = $failsSessionsBkC.Count
	    "Failed BackupCopys" = $failedSessionsBkC.Count
	    "Running BackupCopys" = $runningSessionsBkC.Count
	    "Idle BackupCopys" = $IdleSessionsBkC.Count
	    "Successful Replications" = $successSessionsRepl.Count
        "Warning Replications" = $warningSessionsRepl.Count
        "Failes Replications" = $failsSessionsRepl.Count
        "Failed Replications" = $failedSessionsRepl.Count
        "Running Replications" = $RunningSessionsRepl.Count
        "Successful Tape Backup" = $successTapeBk.Count
        "Warning Tape Backup" = $warningTapeBk.Count
        "Failed Tape Backup" = $failedTapeBk.Count
		"Successful BackupJob" = $successJobBk.Count
        "Warning BackupJob" = $warningJobBk.Count
        "Failed BackupJob" = $failedJobBk.Count
    }
    $SessionResport += $SessionObject
    $SessionResport
}
#endregion
