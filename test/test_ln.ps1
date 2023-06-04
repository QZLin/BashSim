$res_dir = Get-Item $PSScriptRoot/res
Push-Location $PSScriptRoot
. ../BashSim.ps1
Remove-Item temp/* -Exclude '.gitkeep' -Recurse

Push-Location temp
ln $res_dir/test.txt
ln $res_dir/folder1

ln -s $res_dir/folder1 _folder1
ln -s -r $res_dir/test2.txt test2.txt
ln $res_dir/f.txt test2.txt -f

mkdir d1
ln $res_dir/test.txt -t d1 TEXT_1

ln $res_dir/test2.txt hello -r
ln $res_dir/test.txt hello -b
ln $res_dir/test.txt hello -r -b -suffix _

Pop-Location
Write-Output "result:"
Get-ChildItem temp

Pop-Location