[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Candidate,
    [Parameter(Mandatory)] [string] $Control,
    [Parameter(Mandatory)] [string] $Oha,
    [Parameter(Mandatory)] [string] $Results
)

$ErrorActionPreference = 'Stop'
$Candidate = (Resolve-Path $Candidate).Path
$Control = (Resolve-Path $Control).Path
$Oha = (Resolve-Path $Oha).Path
$Results = [IO.Path]::GetFullPath($Results)
if (Test-Path $Results) { throw "Results directory already exists: $Results" }
New-Item -ItemType Directory -Path $Results | Out-Null
@{
    candidateSha256 = (Get-FileHash $Candidate).Hash
    controlSha256 = (Get-FileHash $Control).Hash
    sourceCommit = $env:GITHUB_SHA
    ohaSha256 = (Get-FileHash $Oha).Hash
    repeats = 6
    workers = 4
    duration = '7s'
} | ConvertTo-Json | Set-Content "$Results/metadata.json" -Encoding UTF8

function Invoke-Node([string[]] $Arguments) {
    & node @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Node command failed: $($Arguments -join ' ')"
    }
}

function Invoke-Sample([string] $Binary, [string] $Label, [string] $Directory) {
    New-Item -ItemType Directory -Path $Directory | Out-Null
    $prefix = Join-Path $Directory 'server'
    New-Item -ItemType Directory -Path "$prefix/logs", "$prefix/html" | Out-Null
    [IO.File]::WriteAllBytes("$prefix/html/64k.bin", [byte[]]::new(65536))
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    $prefixWin = $prefix.Replace('\', '/')
    $config = @"
worker_processes 4;
error_log logs/error.log notice;
pid logs/nginx.pid;
events {
    use iocp;
    worker_connections 2048;
    iocp_threads 1;
    post_acceptex 32;
}
http {
    access_log off;
    keepalive_timeout 30;
    keepalive_requests 1000000;
    server {
        listen 127.0.0.1:$port;
        location = /empty.gif { empty_gif; }
        location / { root "$prefixWin/html"; }
    }
}
"@
    Set-Content "$prefix/nginx.conf" $config -Encoding ASCII
    $master = $null
    try {
        $master = Start-Process $Binary -ArgumentList @(
            '-p', "$prefixWin/", '-c', 'nginx.conf') -PassThru -NoNewWindow
        $ready = $false
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            if ($master.HasExited) { throw "nginx exited: $($master.ExitCode)" }
            try {
                $response = Invoke-WebRequest "http://127.0.0.1:$port/empty.gif" `
                    -TimeoutSec 2 -DisableKeepAlive
                $ready = $response.StatusCode -eq 200
            } catch { }
            if ($ready) { break }
            Start-Sleep -Milliseconds 200
        }
        if (-not $ready) { throw 'nginx did not become ready' }
        if (-not (Select-String -LiteralPath "$prefix/logs/error.log" `
            -Pattern 'using the "iocp" event method' -SimpleMatch -Quiet)) {
            throw 'Benchmark did not start IOCP'
        }

        foreach ($workload in @(
            @{name = '/empty.gif'; path = '/empty.gif'; churn = '0'; connections = '48'; clients = '4'},
            @{name = '/64k.bin'; path = '/64k.bin'; churn = '0'; connections = '48'; clients = '4'},
            @{name = '/churn'; path = '/empty.gif'; churn = '1'; connections = '8'; clients = '1'}
        )) {
            foreach ($duration in @('2s', '7s')) {
                $output = if ($duration -eq '2s') {
                    "$prefix/warmup.jsonl"
                } else {
                    "$Directory/$Label-$($workload.name.TrimStart('/')).jsonl"
                }
                Invoke-Node @("$PSScriptRoot/win32-oha-runner.js", $Oha,
                    "http://127.0.0.1:$port$($workload.path)",
                    $workload.connections, $duration, $prefixWin, $output,
                    'iocp', $Label, $workload.name, $workload.clients,
                    '0', '1.1', $workload.churn)
            }
        }
        Invoke-Node @("$PSScriptRoot/validate-oha-results.js", $Directory)
    } finally {
        if ($master -and -not $master.HasExited) {
            $signal = Start-Process $Binary -ArgumentList @(
                '-p', "$prefixWin/", '-c', 'nginx.conf', '-s', 'quit') `
                -PassThru -NoNewWindow -Wait
            if (-not $master.WaitForExit(10000)) {
                Stop-Process -Id $master.Id -Force -ErrorAction SilentlyContinue
            }
        }
        Get-CimInstance Win32_Process -Filter "Name='nginx.exe'" |
            Where-Object { $_.CommandLine -and $_.CommandLine.Contains($prefixWin) } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        Copy-Item "$prefix/logs/*" $Directory -ErrorAction SilentlyContinue
        Copy-Item "$prefix/nginx.conf" $Directory -ErrorAction SilentlyContinue
        Remove-Item $prefix -Recurse -Force -ErrorAction SilentlyContinue
    }
}

foreach ($direction in @('forward', 'reverse')) {
    $directory = "$Results/$direction"
    New-Item -ItemType Directory -Path "$directory/candidate-raw", `
        "$directory/control-raw" | Out-Null
    for ($repeat = 1; $repeat -le 6; $repeat++) {
        $candidateFirst = ($repeat % 2) -eq 0
        if ($direction -eq 'reverse') { $candidateFirst = -not $candidateFirst }
        $order = if ($candidateFirst) { @('candidate', 'control') } `
            else { @('control', 'candidate') }
        foreach ($label in $order) {
            Write-Host "$direction round $repeat/6: $label"
            $binary = if ($label -eq 'candidate') { $Candidate } else { $Control }
            Invoke-Sample $binary $label "$directory/$label-raw/repeat$repeat-$label"
        }
    }
    Invoke-Node @("$PSScriptRoot/noise-compare.js", "$directory/candidate-raw",
        "$directory/control-raw", 'candidate', 'control',
        "$directory/candidate-vs-control.jsonl")
}
