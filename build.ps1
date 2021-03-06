param(
	  $mysy = "C:\msys64"
	, $mingw32 = "C:\msys64\mingw32"
	, $mingw64 = "C:\msys64\mingw64"
	, $src = "./src/x264"
    , $buildPlatform = "*"
    , $buildConfiguration = "*"
)

$ErrorActionPreference = "Stop";
$my_dir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

"BUILDING $buildPlatform $buildConfiguration" | oh

function add-dir2path($dir)
{
	if(-Not ($env:path -match $dir.Replace("\", "\\")))
	{
		$env:path = "$dir;$env:path"
	}
}

function patch_prefix($dir, $cmd, $prefix)
{
	$target = "$dir\$($prefix)$($cmd).exe"
	$source = "$dir\$($cmd).exe"
	
	if( -not (test-path $target))
	{
		cp $source $target
	}
}

function mdc($target)
{
	if(-not (test-path $target))
	{
		md $target
	}
}

function collect($plat, $config)
{
	$target = "$pwd/build/$config/$plat"
	mdc $target
	
	$include = "$target/include"
	mdc $include
	
	cp 'x264.h' $include
	cp 'x264_config.h' $include
	
	$bin = "$target/bin"
	mdc $bin

    if("Win32" -eq $plat)
    {
        cp "$mingw32\bin\libgcc_s_dw2-1.dll" $bin
        cp "$mingw32\bin\libwinpthread-1.dll" $bin
    }
	
	ls 'libx264*' | foreach{cp $_ $bin}
	
	$lib = "$target/lib"
	mdc $lib
	
	$dll = ls "$bin\libx264*.dll"
	
	$arch = $plat
	if("Win32" -eq $arch)
	{$arch = "x86"}
	
	& "$my_dir\gen-lib.ps1" $dll $arch $lib
}

function log($name, $success, $msg, $file)
{
    $outcome = 'Passed'
    if(-not $success)
    {$outcome = 'Failed'}

    if( (get-command Add-AppveyorTest -ea SilentlyContinue) -ne $null)
    {
        Push-AppveyorArtifact $file
        Add-AppveyorTest -Name "$name" -Framework 'NUnit' -Filename 'build.ps1' -Outcome $outcome
        return true;
    }
    else
    {
        $msg | oh
        return false;
    }
}

#if( (get-command gyp -ea SilentlyContinue) -eq $null)

function build($configure, $plat, $config)
{
    if(($buildPlatform -ne $plat) -and ($buildPlatform -ne '*'))
    {
        "Skip platform $plat. Target $buildPlatform" | oh
        return;
    }

    if(($buildConfiguration -ne '*') -and ($buildConfiguration -ne $config))
    {
        "Skip platform $plat. Target $buildConfiguration" | oh
        return;
    }

	bash -c "$configure"
	if(0 -ne $LASTEXITCODE)
	{
		Write-Error "FAILED $plat $config Configuration"
	}
	
    $file = "$($plat)_$($config).txt";

$ErrorActionPreference = "Continue";
	bash -c "make V=1" > $file -ea 
    $BASHEXIT = $LASTEXITCODE
    "MAKE EXIT CODE: $BASHEXIT" | oh
$ErrorActionPreference = "Stop";

	if(0 -ne $BASHEXIT)
	{
        $msg = "FAILED $plat $config Configuration"
        if(-not (log "$($plat)_$($config)" $false $msg $file))
        {
            Write-Error $msg
            return;
        }
	}
	
	collect $plat $config
	
	bash -c "make clean"
	$LASTEXITCODE | oh
	if(0 -ne $LASTEXITCODE)
	{
		Write-Warning "FAILED $plat $config Clean"
	}

    log "$($plat)_$($config)" $true $msg $file
}

function main()
{
	$mingw32bin = "$mingw32\bin"
	$mingw64bin = "$mingw64\bin"
    add-dir2path "$mysy\usr\bin"
	add-dir2path $mingw32bin
	
	#WIN32
	
	$env:MSYSTEM="MINGW32"
	$prefix = "i686-w64-mingw32-"
	
	patch_prefix $mingw32bin "strings" $prefix
    patch_prefix $mingw32bin "strip" $prefix
	
	$dumpbinpath = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\bin"
	
	if(-not (test-path $dumpbinpath))
	{
		$dumpbinpath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin"
		if(-not (test-path $dumpbinpath))
		{
			Write-Error "CANNOT FIND DUMPBIN"
		}
		
	}
	
	$dumpbinpath64 = "$dumpbinpath\amd64"
	
	add-dir2path $dumpbinpath
	
	$loc = get-location
	
	set-location $src
	
	#WIN32 DEBUG
	$configure = "./configure --enable-debug --enable-shared --enable-pic --disable-asm --cross-prefix=i686-w64-mingw32- --host=i686-pc-mingw32"
		
	build $configure "Win32" "Debug"
	
	
	#WIN32 RELEASE
	$configure = "./configure --enable-shared --enable-pic --cross-prefix=i686-w64-mingw32- --host=i686-pc-mingw32"
		
    build $configure "Win32" "Release"
	
	
	
	#x64
	
	$env:path = $env:path.Replace($mingw32bin, $mingw64bin)
	$env:path = $env:path.Replace($dumpbinpath, $dumpbinpath64)
	$env:MSYSTEM="MINGW64"
	
	#X64 DEBUG
	$configure = "./configure --enable-shared --enable-pic --enable-debug --disable-asm"
		
	build $configure "x64" "Debug"
	
	#X64 RELEASE
	$configure = "./configure --enable-shared --enable-pic"
		
	build $configure "x64" "Release"
	
	set-location $loc
	
}


main 
