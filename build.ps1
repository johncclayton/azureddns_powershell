$exclude = @(".vs", "build", "build.ps1", ".gitignore", ".terra*", "*.tf", ".vscode")
Get-ChildItem -Path . -Exclude $exclude | Compress-Archive -DestinationPath build/functionapp.zip -Force