################################################################################
##  File:  Install-Chrome.ps1
##  Desc:  Install Google Chrome
################################################################################

# Download and install latest Chrome browser
$ChromeInstallerFile = "chrome_installer.exe"
$ChromeInstallerUrl = "https://dl.google.com/chrome/install/375.126/${ChromeInstallerFile}"
Install-Binary -Url $ChromeInstallerUrl -Name $ChromeInstallerFile -ArgumentList ("/silent", "/install")
