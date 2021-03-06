<#
    This tool allows to display a customized notification which can be used during SCCM deployments.
    For task sequences ServiceUI.exe must be used to display information in system context in interactive mode. 
    This tool also checks for proccesses mentioned in the ProcessList.txt file and allow user to either close and retry, or force and proceed with the installation. 

    Created By:        (UK) Umakanth Kallakuri
    Creation Date:     19 November 2018
    Last Modified By:  (UK) Umakanth Kallakuri
    Last Mdofied Date: 19 November 2018

    Changes:
    0.1 - Initial version
#>

Param(
        [Parameter(Mandatory=$false, Position=0)] $TimerDuration = 360,
        [Parameter(Mandatory=$false, Position=1)] $LogFile
    )

If (!$LogFile) {
    $LogFile = "$PSScriptRoot\Display-Notification.log"
}
# Function displays the message on the screen and writes to a log file. 
Function Write-ToLog {

    Param(
        [Parameter(Mandatory=$true)] $Message
    )
    
    "[$(Get-date)] $Message" | Out-File -FilePath $LogFile -Encoding Unicode -Append

    Write-Host "[$(Get-date)] $Message"
}



# Check if a user is logged in
Function Check-UserLoggedIn {

    #Check if the explorer is in use
    $CheckExplorer = Get-WmiObject -Query 'Select * from Win32_process WHERE name=''explorer.exe''' | Foreach-Object { $($_.GetOwner()).user  }
    If ($CheckExplorer -ne $null) {
        $Status = $true
    } else {
        $Status = $false
    }

    Return $status

}

Function Get-RunningProcess {
    Param(
        [Parameter(Mandatory=$false)] $ProcessList = "$PSScriptRoot\ProcessList.txt"
    )

    $Object = @()
    
    If (Test-Path $ProcessList ) {
        $ProcessList = Get-Content $PSScriptRoot\ProcessList.txt

        
        Foreach ($Process in $ProcessList) {

            $CurrentProcess = Get-Process $Process -ErrorAction SilentlyContinue | Select Name, Description -ErrorAction SilentlyContinue | Sort Name, Description -Unique
            If($CurrentProcess) {
                $Object += $CurrentProcess
            }
        }
    }

    Return $Object
}

Function Stop-RunningProccess {

    Param(
        [Parameter(Mandatory=$true)] $ProcessList = @()
    )

   $ProcessList | Get-Process | Stop-Process   #-Force 
   $ProcessList | Foreach { Wait-Process -Name $_.Name}
}

Function Check-PreReqs {

    $errorMessage = ""
    $errorCode = 0

    $ProcessList = Get-RunningProcess 


    If ($ProcessList) {
        $errorCode = 1
        $i = 1
        Foreach ($Process in $ProcessList) {
    
            If ($i -lt $ProcessList.Count) {
                $ErrorMessage += "-- $($Process.Description)`n"
            } else {
                $ErrorMessage += "-- $($Process.Description)"
            }

            $i++
        }
    }

    $Object = [PSCustomObject] @{
        ErrorCode = $errorCode
        ErrorMessage = $errorMessage
    }

    Return $object

}

Function LoadXml {
    Param(
        [Parameter(Mandatory=$true)] $FileName
    )
    
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($FileName)
    Return $XamlLoader
}

$UserLoggedIn  = Check-UserLoggedIn

Write-ToLog "StartTime: $(Get-Date)"

Write-ToLog "TimerDuration: $TimerDuration"
Write-ToLog "UserLoggedIn: $UserLoggedIn"

# Load the required assemblies for the GUI
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 	| out-null
[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\assembly\MahApps.Metro.dll")  | out-null
[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\assembly\ControlzEx.dll")  | out-null


# Load MainWindow
$XamlMainWindow = LoadXml "$PSScriptRoot\Display-Notification.xaml"
$Reader = (New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form = [Windows.Markup.XamlReader]::Load($Reader)

# Form elements initialization

$MainContent = $Form.FindName("MainContent")
$ErrorMessageText = $Form.FindName("ErrorMessageText")
$ErrorMessagePanel = $Form.FindName("ErrorMessagePanel")
$FinalTextPanel = $Form.FindName("FinalTextPanel")
$StartButton = $Form.FindName("StartButton")
$TryagainButton = $Form.FindName("TryagainButton")

$TimerPanel = $Form.FindName("TimerPanel")
$TimerHour = $Form.FindName("TimerHour")
$TimerMinute = $Form.FindName("TimerMinute")
$TimerSecond = $Form.FindName("TimerSecond")
$HoursGroup = $Form.FindName("HoursGroup")

# Script block to create a timer
$TimerScriptBlock = {

    $startTime = Get-Date
    
    $endTime = $startTime.AddMinutes($TimerDuration)
    $totalSeconds = (New-TimeSpan -Start $startTime -End $endTime).TotalSeconds

    #$secondsElapsedForShowWindow = 0
    do {
        $now = Get-Date
        $secondsElapsed = (New-TimeSpan -Start $startTime -End $now).TotalSeconds

        $secondsRemaining = $totalSeconds - $secondsElapsed
        $timespan = [timespan]::FromSeconds($secondsRemaining)

        $percentDone = ($secondsElapsed / $totalSeconds) * 100
        
        $TimerHour.Content = $timespan.Hours
        $TimerMinute.Content = $timespan.Minutes
        $TimerSecond.Content = $timespan.Seconds

        $Form.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ContextIdle);
        
    } Until ($now -ge $endTime)
    
    Write-ToLog Get-Date
    $Form.close()
    Exit 0
}

# Script block to show the error panel
$ShowErrorPanelScriptBlock = {
    # Show the error message
    $ErrorMessagePanel.Visibility = "Visible"
    $ErrorMessageText.Text = $PreCheckStatus.ErrorMessage

    # Hide the upgrade now and upgrade now text
    $StartButton.Visibility = "Visible"
    $TimerPanel.Visibility = "Collapsed"

    # Show the Tryagain button
    $TryagainButton.Visibility = "Visible"
}

# Script block to hide the error panel
$HideErrorPanelScriptBlock = {
    # Hide the error message
    $ErrorMessagePanel.Visibility = "Collapsed"

    # Hide the Tryagain button and show the upgrade now button
    $TimerPanel.Visibility = "Visible"
    $FinalTextPanel.Visibility = "Visible"
    $StartButton.Visibility = "Visible"
    $TryagainButton.Visibility = "Collapsed"
}

# Hide the Hours timer if the time is less than 60 minutes
If ($TimerDuration -le 60) {
    $HoursGroup.Visibility = "Collapsed"
}


$MainContent.Visibility = "Visible"

# Check prereqs
$PreCheckStatus = Check-PreReqs 

If ($PreCheckStatus.ErrorCode -eq 0) {
    
    # If no user is loggedin then exit with precheck exit code instead of displaying the form
    If ($UserLoggedIn -eq $false) {
        Write-ToLog "ExitCode: $($PreCheckStatus.ErrorCode)"
        Write-ToLog "EndTime: $(Get-Date)"
        
        Exit $PreCheckStatus.ErrorCode
    } else {
        & $HideErrorPanelScriptBlock
        $Form.Add_ContentRendered({    
            & $TimerScriptBlock
        })
    }
} else {

    # If no user is loggedin then exit with precheck exit code instead of displaying the form
    If ($UserLoggedIn -eq $false) {
        Write-ToLog "ExitCode: $($PreCheckStatus.ErrorCode)"
        Write-ToLog "EndTime: $(Get-Date)"

        Exit $PreCheckStatus.ErrorCode
    } else {

        & $ShowErrorPanelScriptBlock
    }
}

# Tryagain prereqs
$TryagainButton.add_click({
    $PreCheckStatus = Check-PreReqs 

    If ($PreCheckStatus.ErrorCode -eq 0) {
               
        & $HideErrorPanelScriptBlock
        & $TimerScriptBlock
    } else {
        & $ShowErrorPanelScriptBlock
    }
})

$StartButton.add_click({
    $ProcessList = Get-RunningProcess

    IF ($ProcessList) {
        Stop-RunningProccess $ProcessList
        Start-Sleep 3
    }

    $PreCheckStatus = Check-PreReqs 

    If ($PreCheckStatus.ErrorCode -eq 0) {
        & $HideErrorPanelScriptBlock
        #& $TimerScriptBlock

        # Exit 0 if user clicks Upgrade Now 
        $ExitCode = 0

        Write-ToLog "ExitCode: $ExitCode"
        Write-ToLog "EndTime: $(Get-Date)"
        
        $Form.close()
        
        Exit $ExitCode
    } else {
        & $ShowErrorPanelScriptBlock
    }
})

$Form.Add_Closing({
    # This will preventing closing the form using Alt F4
    $_.cancel = $true
    })

    
$Form.ShowDialog() | Out-Null
