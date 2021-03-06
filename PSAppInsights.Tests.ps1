﻿<#PSScriptInfo
.DESCRIPTION 
    Pester tests for PowerShell App Insights Module
#Version is used in test 
.VERSION 0.3
.AUTHOR Jos Verlinde
.GUID bcff6b0e-509e-4c9d-af31-dccc41e148d0
#>

<# 
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

#Module 
$sut = $sut.Replace('.ps1', '.psd1') 
Write-Verbose "$here\$sut" #>

Get-Module psappInsights -All | Remove-Module
Import-Module ".\PSAppInsights.psd1" -Force 

Describe "PSAppInsights Module" {
    It "loads the AI Dll" {
        New-Object Microsoft.ApplicationInsights.TelemetryClient  -ErrorAction SilentlyContinue | Should not be $null
    }

    $key = "c90dd0dd-3bee-4525-a172-ddb55873d30a"

    $PropHash = @{ "Pester" = "Great";"Testrun" = "True" ;"PowerShell" = $Host.Version.ToString() } 
    $MetricHash = @{ "Powershell" = 5;"year" = 2016 } 

       

    It 'can log live metrics' {
        { Start-AILiveMetrics -Key $key } | Should not Throw
        $Global:AISingleton.QuickPulse | Should not be $null
    }

    Context 'New Session' {

        It 'can Init a new log AllowPII session' {

            $client = New-AIClient -Key $key -AllowPII -Version "2.3.4"
            
            $Global:AISingleton.Client | Should not be $null

            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name

            #Check PII 
            $client.Context.Device.Id      | Should be $env:COMPUTERNAME 
            $client.Context.User.Id        | Should be $env:USERNAME

            #Check Version number detection
            $Client.Context.Component.Version | should be "2.3.4"

        }


        It 'can Init Device properties' {

            { $TmtClient = New-AIClient -Key $key  -Init Device } | Should not Throw 
        }
        it 'can Init  Domain properties' {    

            { $TmtClient = New-AIClient -Key $key -Init Domain } | Should not Throw 
        }
        it 'can Init Operation Correlation' {    

            {  $TmtClient = New-AIClient -Key $key -Init Operation  } | Should not Throw 
        }
        it 'can Init Device & Domain & Operation' {    

            { $TmtClient = New-AIClient -Key $key -Init @('Device', 'Domain', 'operation' ) } | Should not Throw 
        }


        it 'can detect the calling script version ' {
            $client = New-AIClient -Key $key -AllowPII -Init Device, Domain, Operation

            #Check Version number  (match this script ) 
            $Client.Context.Component.Version | should be "0.3"  

        }

        it 'can log permon counters' {
            $Global:AISingleton.PerformanceCollector = $null
            { start-AIPerformanceCollector -key $key }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should not be $null

            #And a 2nd time 
            { start-AIPerformanceCollector -key $key }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should not be $null

        }
        #Mark Pester traffic As Synthethic traffic
        $SynthMarker= "Pester run $((get-date).ToString('g'))"
        $client = New-AIClient -Key $key -Synthetic $SynthMarker


        It 'can Init a new log session' {

            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name
        }
        it 'can mark synthetic traffic' {
            $AISingleton.Client.Context.Operation.SyntheticSource | Should be $SynthMarker
        }

        It 'can Init the log with user information'  {
            $client.Context.User.UserAgent | Should  be $Host.Name
            $client.Context.User.Id        | Should not be $env:USERNAME
            $client.Context.User.Id        | Should not be $null

        }

        It 'can Init the log with Computer information' {
            $client.Context.Device.Id              | Should not be $env:COMPUTERNAME #Should not be $null
            $client.Context.Device.Id              | Should not be $null
            $client.Context.Device.OperatingSystem | Should not be $null

        }

        #-----------------------------------------

        It 'can log a trace ' {
            {Send-AITrace -Client $client -Message "Test Trace Message" } | Should not throw 
            
            #using Global 
            {Send-AITrace -Message "Test Trace Message" } | Should not throw 

            {Send-AITrace -Message "Test Trace Message" -SeverityLevel 0 } | Should not throw 

        }

        It 'can log a trace - Complex' {

            #using Global 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash} | Should not throw 
        }
        It 'can log a trace - Complex + Levels' {

            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Verbose" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Information" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Error" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Warning" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Critical" } | Should not throw 

            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 0 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 1 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 2 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 3 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 4 } | Should not throw 

        }

        #-----------------------------------------
        
        It 'can log an event - Simple , implicit' {
            #Using Global
            {Send-AIEvent -Event "Test event - Simple Implicit" } | Should not throw 
        }

        It 'can log an event - Simple , explicit' {
            {Send-AIEvent -Client $client -Event "Test event - Simple Explicit" } | Should not throw 
        }


        It 'can log an event - NoStack' {
            {Send-AIEvent -Client $client -Event "Test event - Simple, no stack" -NoStack } | Should not throw 
        
        }


        It 'can log an event - with metrics'  {
            # BUGBUG on the sending end 
            # {"name":"Microsoft.ApplicationInsights.c90dd0dd3bee4525a172ddb55873d30a.Event","time":"2016-10-27T20:10:24.5050618Z","iKey":"c90dd0dd-3bee-4525-a172-ddb55873d30a","tags":{"ai.internal.sdkVersion":"dotnet: 2.1.0.26048","ai.device.osVersion":"10.0.14393","ai.operation.id":"db0c5074-8350-45b9-9c13-754fc8388ead","ai.session.id":"a9f87484-02b3-470d-a1b7-99189af7c34e","ai.user.userAgent":"Windows PowerShell ISE Host","ai.user.id":"ba3734482aa24856f1d253a5bae74e06","ai.device.id":"518aeec5d382166090a20484145b67f9"},"data":{"baseType":"EventData","baseData":{"ver":2,"name":"name is a required field for Microsoft.ApplicationInsights.DataContracts.EventTelemetry","properties":{"ScriptName":"<No file>","Command":"<ScriptBlock>","FunctionName":"<ScriptBlock>","ScriptLineNumber":"1"}}}}
            {Send-AIEvent -Client $client -Event "Test Event - Complex" -Metrics $MetricHash} | Should not throw 
        }

        It 'can log an event - with Properties'  {
            $hash = @{ "Pester" = "Great";"Testrun" = "True"  } 
            {Send-AIEvent -Client $client -Event "Test Event - Complex" -Properties $PropHash} | Should not throw 
        }

        It 'can log an event - with metrics' {
            $hash = @{ "Pester" = "Great";"Testrun" = "True"  } 
            {Send-AIEvent -Client $client -Event "Test Event - Complex" -Metrics $MetricHash -Properties $PropHash} | Should not throw 
        }

        #-----------------------------------------

        It 'can log a Metric' {
            {Send-AIMetric -Client $client -Metric "testMetric" -Value 1} | Should not throw 
            #Using Global
            {Send-AIMetric -Metric "testMetric" -Value 1} | Should not throw 
       
        }

        It 'can log a Metric - Complex' {
            #Using Global
            {Send-AIMetric -Metric "testMetric" -Value 1 -Properties $PropHash } | Should not throw 
      
        }

        #-----------------------------------------
        $ex = new-object System.Management.Automation.ApplicationFailedException
        try  
        {  
            $fileContent = Get-Content -Path "C:\Does.not.exists.txt" -ErrorAction Stop  
        }  
        catch  
        {  
            $ex = $_.Exception
            $er = $_ 
        }


        It 'can log an Exception - Simple' {

            {Send-AIException -Client $client -Exception  $ex } | Should not throw 
            #Using Global
            {Send-AIException -Exception  $ex } | Should not throw 

        }
        It 'can log an Exception Via an Error object ' -Pending {
            {Send-AIException -Severity 4 -Error $Er  } | Should not throw 
      
        }

        It 'can log an Exception - Complex' -Pending  {
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Properties $PropHash  } | Should not throw 
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Metrics $MetricHash   } | Should not throw 
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Metrics $MetricHash -Properties $PropHash  } | Should not throw 
      
        }

        #-----------------------------------------

        It 'can log a Page view ' -Skip {
       
        }

        #-----------------------------------------


        It 'can log server request - One Off ' {
        
        }

        It 'can Start a Server Request' {
        
        }

        It 'can Finalize a Server Request' {
        
        }

        #-----------------------------------------



        It 'can Push/Flush the log session' {
            {Flush-AIClient -Client $client }| Should not throw
            {Push-AIClient -Client $client }| Should not throw

        }

        it 'can stop logging permon counters' {
            { stop-AIPerformanceCollector }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should be $null
        }

        It 'can stop loggin log live metrics' {
            { Stop-AILiveMetrics } | Should not Throw
            $Global:AISingleton.QuickPulse | Should be $null
        }


    }
}

