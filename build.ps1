param(
	  $mysy = "C:\msys64"
	, $mingw32 = "C:\msys64\mingw32"
	, $mingw64 = "C:\msys64\mingw64"
	, $src = "C:\tmp\x264-snapshot-20180829-2245-stable"
)

$ErrorActionPreference = "Stop";
$my_dir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

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
	
	ls 'libx264*' | foreach{cp $_ $bin}
	
	$lib = "$target/lib"
	mdc $lib
	
	$dll = ls "$bin\libx264*.dll"
	
	$arch = $plat
	if("Win32" -eq $arch)
	{$arch = "x86"}
	
	& "$my_dir\gen-lib.ps1" $dll $arch $lib
}

function build($configure, $plat, $config)
{
	bash -c "$configure"
	if(0 -ne $LASTEXITCODE)
	{
		Write-Error "FAILED $plat $config Configuration"
	}
	
	bash -c "make"
	if(0 -ne $LASTEXITCODE)
	{
		Write-Error "FAILED $plat $config Build"
	}
	
	collect $plat $config
	
	bash -c "make clean"
	$LASTEXITCODE | oh
	if(0 -ne $LASTEXITCODE)
	{
		Write-Warning "FAILED $plat $config Clean"
	}
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
