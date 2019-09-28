<#
    .VERSION
    0.2

    .DESCRIPTION
    Author: Nikitin Maksim
    Github: https://github.com/nikimaxim/service-1c-server.git
    Note: backup 1c logs & shrink 1c logs & logs users

    .TESTING
    OS: Windwos 2008R2 x64 and later
    PowerShell: 5.1 and later
    1C Server: 8 and later
#>

param (
    [string]$1c_exe = "C:\Program Files (x86)\1cv8\8.3.13.1690\bin\1cv8.exe",                       # "C:\Program Files (x86)\1cv8\<version>\bin\1cv8.exe"
    [array]$1c_base_all = @("work_1", "work_2"),                                                    # List DB
    [string]$1c_user = "service_1c",								                                # 1C user with the ability to delete the event log
    [string]$1c_password = "",                                                                      # 1C password
    [string]$1c_days_logs = 50, 									                                # Number of days to delete data
    [string]$service_logs = "B:\backup\shrink_1c_logs\shrink_logs.log",                             # Log
    [string]$1c_logs_archive = "B:\backup\shrink_1c_logs\",			                                # Path old log *.elf
	[string]$time_out_action = 180,									                                # Waiting for user action before disconnecting
	[string]$1c_log_archive_number = 10								                                # Number of backups *.elf
)

$server_1c = $env:COMPUTERNAME.ToLower()							                                # Name 1c server
$session_id = ""


"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") Preparation service 1C server:" | Tee-Object $service_logs -Append

# Search terminal session with open 1C
$1c_session = Get-WMIObject win32_process | where {$_.ProcessName -like "1cv8*.exe"}

# If $1c_session not empty
if ($1c_session)
{
	# Sending messages to users with open 1C
	foreach ($proc in $1c_session)
	{
		if ($proc.SessionId -ne $session_id)
		{
			$session_id = $proc.SessionId
            "$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") - Send message: $($server) user id: $($proc.SessionId)" | Tee-Object $service_logs -Append
			msg $proc.SessionId /server:$server /time:$time_out_action "Через $($time_out_action / 60) минуты будет отключена программа 1С. Пожалуйста завершите работу."
			# Work Windows Server 2016
			#Send-RDUserMessage -UnifiedSessionID $proc.SessionId -HostServer $server -MessageTitle "Сообщение от администратора" -MessageBody "Через $($time_out_action / 60) минуты будет отключена программа 1С. Пожалуйста завершите работу."
		}
	}

	# Sleep n sec before disconnecting
	Wait-Event -Timeout $time_out_action

	# Completion user process 1C
	foreach ($proc in $1c_session)
	{
		"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") - Completion process: $($proc.ProcessName) user id: $($proc.SessionId)" | Tee-Object $service_logs -Append
		Stop-Process $proc.ProcessId -Force
	}
}
else
{
    "$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") - Terminal session 1C not open" | Tee-Object $service_logs -Append
}


"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") Start removing old archive event log:" | Tee-Object $service_logs -Append

foreach ($1c_base in $1c_base_all)
{
	$1c_logs_archive_count = 1
	$1c_log_archive_db = Join-path $1c_logs_archive -childpath $1c_base

    try
    {
        foreach ($archive_name in Get-ChildItem -Path $($1c_log_archive_db + "\*.elf") -ErrorAction Stop | Sort-Object -Property LastWriteTime -Descending)
	    {
            if ($1c_logs_archive_count -gt $1c_log_archive_number)
            {
                "$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") - Delete 1C log archive: $($archive_name.FullName)" | Tee-Object $service_logs -Append
                Remove-Item -Path $archive_name.FullName
            }
            $1c_logs_archive_count++
	    }
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        "$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") Directory $1c_log_archive_db not found." | Tee-Object $service_logs -Append
    }
}


"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") Start removing cache from users and event log slice:" | Tee-Object $service_logs -Append

#"- Restart 1с Agent before deleting old events from the database" | Out-File $service_logs -Append
#Restart-Service -Name "1C:Enterprise 8.3 Server Agent"

# Sleep 5 sec
Wait-Event -Timeout 5

"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") - Delete user cache:" | Tee-Object $service_logs -Append
Get-ChildItem "C:\Users\*\AppData\Local\1C\1Cv8*\*","C:\Users\*\AppData\Roaming\1C\1Cv8*\*" | Where {$_.Name -as [guid]} | Remove-Item -Force -Recurse

foreach ($1c_base in $1c_base_all)
{
    $1c_log_archive_db = Join-path $1c_logs_archive -childpath $1c_base

    if (!$(Test-Path $1c_log_archive_db))
    {
        New-Item -Path $1c_log_archive_db -ItemType Directory
    }

    $1c_log_archive_name = $server_1c + "-1clog-" + $1c_base + "-" + (get-date).Date.ToString("yyyyMMdd") + ".elf"
    $1c_log_full_name = Join-path $1c_logs_archive -childpath $1c_base | Join-path -childpath $1c_log_archive_name
    $date_shrink = $((get-date).Date.AddDays(-$1c_days_log).ToString("yyyy-MM-dd"))

    "$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") - Delete old events from database $1c_base, on  $date_shrink" | Tee-Object $service_logs -Append
    cmd /c "`"$1c_exe`" CONFIG /s`"$server_1c/$1c_base`" /N`"$1c_user`" /P`"$1c_password`" /Out `"$service_logs`" -NoTruncate /ReduceEventLogSize $date_shrink -saveAs `"$1c_log_full_name`""
}


"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") Restart 1с Agent after deleting old events from the database" | Tee-Object $service_logs -Append
Restart-Service -Name "1C:Enterprise 8.3 Server Agent"


"$(Get-Date -Format "yyyyMMdd:HHmmss.ffff") Completed trimming event log and user log across all databases." | Tee-Object $service_logs -Append
