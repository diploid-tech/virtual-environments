################################################################################
##  File:  Install-KubernetesCli.ps1
##  Desc:  Install KubernetesCli
################################################################################

Choco-Install -PackageName kubernetes-cli

Invoke-PesterTests -TestFile "Tools" -TestName "KubernetesCli"