#!/usr/bin/env pwsh

## Portions stollen from:
##    https://github.com/MADE-Apps/MADE.NET/blob/main/build/GetBuildVersion.psm1

## Parses a $VersionString parameter of the form:
##   'refs/tags/v6.0.1-beta1.0'
##   'refs/tags/v6.0.1'
##
## If $VersionString does not start with "refs/tags/",
## the VERSION_DEFAULT environment variable is parsed instead.

function Get-VersionVariables {
    [CmdletBinding()]
    Param (
      [Parameter(Position = 0, Mandatory)]
      [string]$VersionString
    )

    Write-Host "`$VersionString: '$VersionString'"

    $graphResult = gh api graphql -F owner='{owner}' -F name='{repo}' -f query=' 
query($name: String!, $owner: String!) {
  repository(owner: $owner, name: $name) {
    refs(refPrefix: \"refs/tags/\", last: 1) {
      nodes { name }
    }
  }
}'

    Write-Host "GraphQL result: $graphResult"

    # Parse via regex
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

    if (-not $version_default.PreRelease)
    {
        $version_default.PreRelease = 'build'
    }
	
	$matches = $null

    if ($env:GITHUB_REF_TYPE -eq 'tag')
    {
        $null = $VersionString -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?(\+(?<build>[0-9A-Za-z\-\.]+))?'
	    if (!$matches)
	    {
		    throw 'Could not parse a valid version value from the specified $VersionString parameter.'
	    }
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
        If ( ($Major -ne $version_default.Major) -or ($Minor -ne $version_default.Minor) -or ($Patch -ne $version_default.Patch) )
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
