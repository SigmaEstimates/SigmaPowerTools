$id="AAABYPHQLMODZ4C3SAAA"
$bundlename = "sigmapowertools"
echo "Starting build process for $id"

$tmp = "fas87gqrliwahfai7fg"

Get-ChildItem "$tmp\*" -Recurse -ErrorAction Ignore | Remove-Item -Recurse

New-Item -ItemType Directory -Force -Path $tmp
Copy-Item manifest.xml -Destination $tmp

Select-Xml -Path ".\$bundlename.sigmabundleproj" -XPath "//file" | ForEach-Object {
	New-Item -Type Directory (Split-Path -Path "$tmp\$($_.Node.target)" ) -Force
	Copy-Item $_.Node.source -Destination "$tmp\$($_.Node.target)" 
	}

chdir "$tmp"
& 7z a -tzip -r "$bundlename.sigmabundle"
Move-Item "$bundlename.sigmabundle" -Destination "..\package\$bundlename.sigmabundle" -Force
chdir ".."

Get-ChildItem "$tmp\*" -Recurse -ErrorAction Ignore | Remove-Item -Recurse
Remove-Item $tmp

Remove-Item "package\$id.sigmapackage" -Force -ErrorAction Ignore

chdir "package"
& 7z a -tzip -r "-x!build.bat" "$id.sigmapackage"

