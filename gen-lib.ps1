param($dll, $arch = "x86", $loc = [IO.Path]::GetDirectoryName($dll))
$out = ""
$fb = [IO.Path]::GetFileNameWithoutExtension($dll)

$fb  | oh
$loc | oh


DUMPBIN /EXPORTS "$dll" > "$fb.txt"
$export = get-content  "$fb.txt" | out-string
remove-item "$fb.txt"
        
$m = [System.Text.RegularExpressions.RegEx]::matches($export, "\s+(\d{1,5})\s+(\w{1,3})\s+\w{8}\s+(\w+)")
$m.Count


foreach($mm in $m){$out += "`t$($mm.Groups[3].Value)`r`n"}

$out

$export = "EXPORTS`r`n$out"

$f = "$fb.def"

$l = gl
set-location $loc
set-content "$f" $export
lib "/machine:$arch" "/def:$f" "/out:$fb.lib"
set-location $l
