function Pipleline([string]$server, [string]$attribute, [bool]$daily_build)
{
    Write-Host "Running Automation Pipeline"
    Write-Host "##octopus[stderr-ignore]"

    Write-Host "====== Preparing Variables ======"
    $argumentList = @()
    $argumentList += @{Name="TEST_SERVER_ADDRESS"; Value=$server}
    $buffer = New-Object System.Text.StringBuilder
    $argumentList | foreach { $buffer.AppendFormat("&{0}={1}", $_.Name, $_.Value) | Out-Null }
    $commandLineArgs = $buffer.ToString()
    Write-Host "Command lines: $commandLineArgs"
    Write-Host "====== Variables Preparing Done ======"

    Write-Host "====== Release Notes Start ======"
    Write-Host $OctopusParameters["Octopus.Release.Notes"]
    Write-Host "====== Release Notes End ======"

    if ($daily_build){
        Write-Host "====== Start Call Pipeline on Jenkins Cloud ======"
        $user = "$usr"
        $password = "$pwd"
        $pair = "${user}:${password}"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"
        $headers = @{ Authorization = $basicAuthValue }

        Try
        {
            $result = Invoke-WebRequest -uri |  ConvertFrom-Json
        }
        Catch
        {
            $_.Exception
        }
        $next_build_number = $result | Select -ExpandProperty "nextBuildNumber"
        Write-Host "Build Number:" $next_build_number

        $params = @{uri = $run_line;
                      Method = 'Get';
                      Headers = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($user):$($password)"));
                            }
                    }

        invoke-restmethod @params

        Write-Host "====== Start Pipeline......  ======"

        Write-Host "Waitting For The Automation Result For Echo....."
        DO
        {
            $result = Invoke-WebRequest -uri  -Headers $headers -UseBasicParsing |  ConvertFrom-Json

            $complete_build_number = $result | Select -ExpandProperty "lastCompletedBuild"
            $complete_build_number = $complete_build_number -match '.*number=(?<contents>.*);.*'
            $complete_build_number = $matches['contents']

            $success_build_number = $result | Select -ExpandProperty "lastSuccessfulBuild"
            $success_build_number = $complete_build_number -match '.*number=(?<contents>.*);.*'
            $success_build_number = $matches['contents']

            Start-Sleep -s 10
            Write-Host $next_build_number
            Write-Host $complete_build_number
            Write-Host $success_build_number

        }Until([int]$next_build_number -eq [int]$complete_build_number)

        Write-Host "Automation Results"

        if ($success_build_number -eq $next_build_number){
            Write-Host "Automation tests successful"
        }
        else{
            Write-Host "Automation tests failed. PLS check Email and Jenkins report!"
            throw "Automation tests failed. PLS check Email and Jenkins report!"
        }
    }
}

function Run-Automation()
{
    write-host "Start Automation Process"
    Write-host $OctopusParameters["Octopus.Release.Number"]
    Write-host "$OctopusParameters["Octopus.Release.Number"]"
    Write-Host "===================================================="
    $ReleaseNotesUsers = Select-String '[A-Z]{1}\d{5} \- [a-zA-Z]+ [a-zA-Z]+' -input $OctopusParameters["Octopus.Release.Notes"] -AllMatches | Foreach {$_.matches.Groups.Value.Substring(9)}
    $ReleaseNotesUsers = $ReleaseNotesUsers | select -uniq
    $ReleaseNotesUsers = $ReleaseNotesUsers -join ','
    Write-Host $ReleaseNotesUsers
    $platformNamesList = $OctopusParameters["UpgradePlatformNamesList"]
    if ($OctopusParameters["ExecuteAutomationTests"] -eq "1" ){
        if (![String]::IsNullOrEmpty($platformNamesList)) {
            Write-Host "On Maintaining !"
        }
        else {
            $platformNamesList = $OctopusParameters["BuildPlatformNamesList"]
            $platformNamesArray = $platformNamesList.Split(",") | ForEach { $_.Trim() } | Where { ![String]::IsNullOrEmpty($_) }
            }
        }
    }
    else{
        Write-Host "Skiped Automation Testing"
    }
}

function Run-On-Demand-Automation()
{
    $TestServer = $OctopusParameters["TestServer"]
    $Attribute = $OctopusParameters["Attribute"]
    Pipleline -server $TestServer -attribute $Attribute -daily_build $false
}