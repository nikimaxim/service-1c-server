## Service 1C Server 8 and later
- https://github.com/nikimaxim/service-1c-server.git

### Windows Install 
#### Requirements:
- OS: Windows 2008R2 and later
- PowerShell: 5.1 and later
- 1C Server: 8 and later

#### Check correct versions PowerShell: (Execute in PowerShell!) (Requirements!)
- Get-Host|Select-Object Version

#### Copy powershell script:
- **github**/service_1c_server.ps1 in C:\service\service_1c_server.ps1

#### Create a login and password in 1C DB with the ability to delete the log

#### Edit variables 
- in C:\service\service_1c_server.ps1

#### Check powershell script: (CMD!)
- powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\service\service_1c_server.ps1"

<br/>

#### Examples images:
- Log

<br/>

![Image alt](https://github.com/nikimaxim/service-1c-server/blob/master/img/1.png)

<br/>

#### License
- GPL v3
