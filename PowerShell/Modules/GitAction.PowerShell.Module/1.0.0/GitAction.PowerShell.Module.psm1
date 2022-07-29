#!/usr/bin/env pwsh

## Portions stollen from:
##    https://github.com/MADE-Apps/MADE.NET/blob/main/build/GetBuildVersion.psm1
##    https://github.com/Amadevus/pwsh-script/blob/master/lib/GitHubActionsCore/GitHubActionsCore.psm1
##
## who adapted from:
##    https://github.com/ebekker/pwsh-github-action-base/blob/b19583aaecd66696896e9b7dbc9f419e2fca458b/lib/ActionsCore.ps1
## 
## which in turn was adapted from:
##    https://github.com/actions/toolkit/blob/c65fe87e339d3dd203274c62d0f36f405d78e8a0/packages/core/src/core.ts

## Parses a $VersionString parameter of the form:
##   'refs/heads/master'
##   'refs/tags/v6.0.1-beta1.0'
##   'refs/tags/v6.0.1'

function Get-VersionVariables {
    [CmdletBinding()]
    Param (
      [Parameter(Position = 0, Mandatory)]
      [string]$VersionString
    )

    Write-Host "`$VersionString: '$VersionString'"

    $null = $env:VERSION_DEFAULT -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?'
	if (!$matches)
	{
		throw "Invalid VERSION_DEFAULT environment variable value: '$env:VERSION_DEFAULT'."
	}
	
	$version_default = @{
	    Major = [uint64]$matches['major']
		Minor = [uint64]$matches['minor']
		Patch = [uint64]$matches['patch']
		PreRelease = [string]$matches['pre']
	}
	
	$matches = $null

    if ($env:GITHUB_REF_TYPE -eq 'tag')
    {
        # Parse via regex
        $null = $VersionString -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?(\+(?<build>[0-9A-Za-z\-\.]+))?'
    }

    if (!$matches)
    {
        $Major = $version_default.Major
        $Minor = $version_default.Minor
        $Patch = $version_default.Patch
        $PreRelease = $version_default.PreRelease
    }
    else
    {
        $Major = [uint64]$matches['major']
        $Minor = [uint64]$matches['minor']
        $Patch = [uint64]$matches['patch']
        $PreRelease = [string]$matches['pre']
        $Build = [string]$matches['build']
    }

    if ($PreRelease -and !$Build)
    {
        $Build = [string]$env:GITHUB_RUN_NUMBER
    }

    if ($env:GITHUB_REF_TYPE -eq 'tag')
    {
        If ( ($Major -ne $version_default.Major) -or ($Minor -ne $version_default.Minor) -or ($Patch -ne $version_default.Patch) -or ($PreRelease -ne $version_default.PreRelease) )
        {
            throw "Specified Git tag does not match VERSION_DEFAULT environment variable ($env:VERSION_DEFAULT). Are you pushing to correct branch?"
        }
    }

    Enter-ActionOutputGroup "Dump Output Variables"

    Write-Host "`$Tag_Major: $Major"
    $env:TAG_MAJOR = $Major
    $global:Tag_Major = $Major

    Write-Host "`$Tag_Minor: $Minor"
    $env:TAG_MINOR = $Minor
    $global:Tag_Minor = $Minor

    Write-Host "`$Tag_Patch: $Patch"
    $env:TAG_PATCH = $Patch
    $global:Tag_Patch = $Patch

    Write-Host "`$Tag_PreRelease: $PreRelease"
    $env:TAG_PRERELEASE = $PreRelease
    $global:Tag_PreRelease = $PreRelease

    Write-Host "`$Tag_Build: $Build"
    $env:TAG_BUILD = $Build
    $global:Tag_Build = $Build

    Exit-ActionOutputGroup
}
