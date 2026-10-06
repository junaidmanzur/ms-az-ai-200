param([string]$BaseUrl = 'http://localhost:7071/runtime/webhooks/mcp')
$ErrorActionPreference = 'Stop'
$headers = @{ Accept = 'application/json, text/event-stream' }
function Send-Mcp($Message) {
    $response = Invoke-WebRequest -Uri $BaseUrl -Method Post -Headers $headers -ContentType 'application/json' -Body ($Message | ConvertTo-Json -Depth 10 -Compress) -UseBasicParsing -TimeoutSec 30
    if ($response.Headers['Mcp-Session-Id']) {
        $headers['Mcp-Session-Id'] = $response.Headers['Mcp-Session-Id']
    }
    if (-not $response.Content) { return }
    if ($response.Headers['Content-Type'] -like 'text/event-stream*') {
        $data = ($response.Content -split '\r?\n' | Where-Object { $_ -like 'data:*' } | ForEach-Object { $_.Substring(5).Trim() }) -join "`n"
        $result = $data | ConvertFrom-Json
    } else {
        $result = $response.Content | ConvertFrom-Json
    }
    if ($result.error) { throw ($result.error | ConvertTo-Json -Compress) }
    if ($result.result.isError) { throw ($result.result | ConvertTo-Json -Depth 10 -Compress) }
    return $result.result
}
$init = Send-Mcp @{ jsonrpc='2.0'; id=1; method='initialize'; params=@{ protocolVersion='2025-03-26'; capabilities=@{}; clientInfo=@{name='powershell-smoke-test';version='1.0'} } }
$headers['MCP-Protocol-Version'] = $init.protocolVersion
Write-Host "Connected to $($init.serverInfo.name)"
Send-Mcp @{jsonrpc='2.0';method='notifications/initialized'} | Out-Null
$tools = Send-Mcp @{jsonrpc='2.0';id=2;method='tools/list';params=@{}}
foreach ($name in @('summarize_text', 'classify_document')) {
    if ($name -notin $tools.tools.name) { throw "Missing tool: $name" }
}
$tools | ConvertTo-Json -Depth 10
Send-Mcp @{jsonrpc='2.0';id=3;method='tools/call';params=@{name='summarize_text';arguments=@{text='Azure Functions exposes tools through MCP.'}}} | ConvertTo-Json -Depth 10
Send-Mcp @{jsonrpc='2.0';id=4;method='tools/call';params=@{name='classify_document';arguments=@{text='An invoice for consulting.';categories='finance, general'}}} | ConvertTo-Json -Depth 10
Write-Host 'PASS: initialization, tool discovery, and both tool calls.'
