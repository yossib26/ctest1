# Simple static file server for this folder: http://localhost:8080/
$port = 8080
$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$port/ (Ctrl+C to stop)"

$types = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css"; ".js" = "application/javascript" }

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = $ctx.Request.Url.AbsolutePath.TrimStart("/")
    if ($path -eq "") { $path = "login.html" }
    $file = Join-Path $root $path
    $res = $ctx.Response
    if ((Test-Path $file -PathType Leaf) -and ((Resolve-Path $file).Path.StartsWith($root))) {
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ext = [System.IO.Path]::GetExtension($file)
      if ($types.ContainsKey($ext)) { $res.ContentType = $types[$ext] }
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
    }
    $res.Close()
  }
} finally {
  $listener.Stop()
}
