##########################################################################################
# Name: Dedupe-WeeklySummary.ps1
# Author: Adrian Begg (adrian.begg@ehloworld.com.au)
#
# Date: 10/01/2017
#
# Purpose: The purpose of this script is to generate a very simple summary report for the
# Deduplication Volumes which I use on my Laptop for hosting Virtual machine labs.
# 
# Produces simple report and alerts on basic errors such as jobs not running or not completing
# and free space. Run as a scheduled task.
# 
# Requires the Deduplication role installed
##########################################################################################

# Global Variables/Configurables
[string] $EmailFrom = "no-reply@domain.com"
[string] $EmailTo = "recipient@domain.com"
[string] $SMTPMailServer = "<INSERT SMTP SERVER>"
[string] $MailServerUserName = "<INSERT USERNAME>"
[string] $MailServerPassword = "<INSERT PASSWORD>"
[int] $daysSinceLastJobAlert = 9 # Number of days to alert if one of the jobs has not run
[int] $freeSpaceGBAlert = 30 # Free space in GB to alert if the Free Space falls below

# MAIN
Import-Module Deduplication
$secpasswd = ConvertTo-SecureString $MailServerPassword -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($MailServerUserName, $secpasswd)

$dedupeStatus = Get-DedupStatus
[string] $summary = ""

# Check if the Deduplication jobs have all run in the last 9 days; if they have not thrown an alert or if the last result was anything other than successful
Foreach($dedupeObject in $dedupeStatus){
	[string] $strVolume = $dedupeObject.Volume
	$dtDaysLastThreshold = (Get-Date).AddDays(-$daysSinceLastJobAlert)
	If($dedupeObject.LastGarbageCollectionTime -lt $dtDaysLastThreshold){
		$summary += ":: ALERT :: Garbage Collection has not run in the last $daysSinceLastJobAlert days for $strVolume ! Investigate.`r`n"
	}
	If($dedupeObject.LastOptimizationTime -lt $dtDaysLastThreshold){
		$summary += ":: ALERT :: Optimization has not run in the last $daysSinceLastJobAlert days for $strVolume ! Investigate.`r`n"
	}
	If($dedupeObject.LastScrubbingTime -lt $dtDaysLastThreshold){
		$summary += ":: ALERT :: Scrubbing has not run in the last $daysSinceLastJobAlert days for $strVolume ! Investigate.`r`n"
	}
	If(!($dedupeObject.LastOptimizationResultMessage.StartsWith("The operation completed successfully."))){
		$summary += ":: ALERT :: The last Optimization job did not complete successfully for $strVolume ! Investigate.`r`n"
	}
	If(!($dedupeObject.LastGarbageCollectionResultMessage.StartsWith("The operation completed successfully."))){
		$summary += ":: ALERT :: The last Garbage Collection job did not complete successfully for $strVolume ! Investigate.`r`n"
	}
	If(!($dedupeObject.LastScrubbingResultMessage.StartsWith("The operation completed successfully."))){
		$summary += ":: ALERT :: The last Scrubbing job did not complete successfully for $strVolume ! Investigate.`r`n"
	}
	# Finally check Free Space
	If(($dedupeObject.FreeSpace / 1GB) -lt $freeSpaceGBAlert){
		$summary += ":: ALERT :: There is less than $freeSpaceGBAlert GB free on the volume $strVolume Investigate.`r`n"
	}
}
# Clean up the format a bit
if($summary -ne ""){ $summary += "`r`n" }
$summary += "Summary`r`n==================================================" + ($dedupeStatus | fl | Out-String)

Send-MailMessage -From $EmailFrom -To $EmailTo -Subject "$env:computername - Deduplication Summary" -Body $summary -smtpServer $SMTPMailServer -credential $mycreds -useSSL 
