# Build-only SDK download. The installed app reuses the system WebView2 Runtime;
# it never downloads a browser at launch and retains MSHTML as an offline fallback.
function Initialize-StartupHostDependencies([string]$Destination) {
    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $sdkVersion = '1.0.3912.50'
    $sdkHash = '8DD696301D8E5AD8389F26B636329BBF35754B793974E82168B1F6DDA234EB07'
    $cacheDirectory = Join-Path $repositoryRoot ".buildtool\dependencies\webview2\$sdkVersion"
    $archive = Join-Path $cacheDirectory 'sdk.zip'
    $sdkDirectory = Join-Path $cacheDirectory 'sdk'
    New-Item -ItemType Directory -Path $cacheDirectory,$Destination -Force | Out-Null
    if (!(Test-Path -LiteralPath $archive)) {
        Invoke-WebRequest -Uri "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$sdkVersion/microsoft.web.webview2.$sdkVersion.nupkg" -OutFile $archive -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $sdkHash) { throw 'WebView2 SDK checksum mismatch.' }
    if (!(Test-Path -LiteralPath "$sdkDirectory\lib\net462\Microsoft.Web.WebView2.WinForms.dll")) {
        Expand-Archive -LiteralPath $archive -DestinationPath $sdkDirectory -Force
    }
    Copy-Item -LiteralPath "$sdkDirectory\lib\net462\Microsoft.Web.WebView2.Core.dll", "$sdkDirectory\lib\net462\Microsoft.Web.WebView2.WinForms.dll", "$sdkDirectory\runtimes\win-x64\native\WebView2Loader.dll" -Destination $Destination
    Copy-Item -LiteralPath "$sdkDirectory\LICENSE.txt" -Destination "$Destination\WebView2-SDK-LICENSE.txt"
    return @("/reference:$Destination\Microsoft.Web.WebView2.Core.dll", "/reference:$Destination\Microsoft.Web.WebView2.WinForms.dll")
}
