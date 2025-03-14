# Extract version from git tags
$version = git describe --tags (git rev-list --tags --max-count=1)

# Replace <version> in ShockAlarmSetup.iss.template with the extracted version
(Get-Content windows/ShockAlarmSetup.iss.template) -replace "<version>", $version | Set-Content windows/ShockAlarmSetup.iss
