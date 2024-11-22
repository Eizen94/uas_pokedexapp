while ($true) {
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $changes = git status --porcelain
        
        if ($changes) {
            Write-Host "Changes detected at $timestamp" -ForegroundColor Yellow
            Write-Host "Changed files:" -ForegroundColor Cyan
            Write-Host $changes -ForegroundColor Gray
            
            git add .
            git commit -m "auto: update at $timestamp"
            git push origin development
            
            Write-Host "Changes pushed successfully!" -ForegroundColor Green
        } else {
            Write-Host "No changes detected at $timestamp" -ForegroundColor DarkGray
        }
        
        Write-Host "Waiting 5 minutes before next check..." -ForegroundColor Cyan
        Start-Sleep -Seconds 300
        
    } catch {
        Write-Host "Error occurred:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Retrying in 1 minute..." -ForegroundColor Yellow
        Start-Sleep -Seconds 60
    }
}