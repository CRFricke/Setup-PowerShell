#!/usr/bin/env pwsh

## Portions stollen from:
##    https://github.com/MADE-Apps/MADE.NET/blob/main/build/GetBuildVersion.psm1

function Get-VersionVariables {
    [CmdletBinding()]
    Param (
      [Parameter(Position = 0)]
      [string]$VersionString
    )

    Write-Host "GITHUB_REF: $env:GITHUB_REF"

	# For GITHUB_REF_TYPE 'tag', the old tag is the 2nd to last one.
	$count = ($env:GITHUB_REF_TYPE -eq 'tag') ? 2 : 1

	$graphResult = gh api graphql -F owner='CRFricke' -F name='Authorization.Core' -F count=$count -f query=' 
	query($name: String!, $owner: String! $count: Int!) {
	  repository(owner: $owner, name: $name) {
		refs(refPrefix: \"refs/tags/\", last: $count) {
		  nodes { name }
		}
	  }
	}'

	$oldTag = ($graphResult | ConvertFrom-Json).data.repository.refs.nodes[0].name
	if ($oldTag)
	{
		Write-Host "Repository tag version: $oldTag"

		$null = $oldTag -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?'
		if (!$matches)
		{
			throw "Invalid tag value found in repository: '$oldTag'."
		}

		$oldTagVersion = @{
			Major = [uint64]$matches['major']
			Minor = [uint64]$matches['minor']
			Patch = [uint64]$matches['patch']
			PreRelease = $matches['pre']
			Build = $env:GITHUB_RUN_NUMBER
		}

		if (!$oldTagVersion.PreRelease)
		{
			$oldTagVersion.PreRelease = 'build'
		}
	}
	else
	{
		$oldTagVersion = @{
			Major = 1
			Minor = 0
			Patch = 0
			PreRelease = 'alpha1.0'
			Build = $env:GITHUB_RUN_NUMBER
		}
	}

	if ($env:GITHUB_REF_TYPE -eq 'tag')
	{
		$null = $env:GITHUB_REF -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?(\+(?<build>[0-9A-Za-z\-\.]+))?'
		if (!$matches)
		{
			throw "Invalid tag value found in GITHUB_REF value: $env:GITHUB_REF."
		}

		$tagVersion = @{
			Major = [uint64]$matches['major']
			Minor = [uint64]$matches['minor']
			Patch = [uint64]$matches['patch']
			PreRelease = [string]$matches['pre']
			Build = [string]$matches['build']
		}

		$newTag = 'v' + $tagVersion.Major + '.' + $tagVersion.Minor + '.' + $tagVersion.Patch 
		if ($tagVersion.PreRelease)
		{
			$newTag += '-' + $tagVersion.PreRelease
		}
		if ($tagVersion.Build)
		{
			$newTag += '+' + $tagVersion.Build
		}

		$verOld = New-Object -TypeName System.Version -ArgumentList (
			$oldTagVersion.Major, $oldTagVersion.Minor, $oldTagVersion.Patch
			)

		$verNew = New-Object -TypeName System.Version -ArgumentList (
			$tagVersion.Major, $tagVersion.Minor, $tagVersion.Patch
			)

		if ($verOld.CompareTo($verNew) -gt 0 -or ($verOld.CompareTo($verNew) -eq 0 -and $oldTagVersion.PreRelease -gt $tagVersion.PreRelease))
		{
			throw "Error: repository tag version ($oldTag) is greater than new tag version ($newTag)."
		}
	}
	else
	{
		$tagVersion = $oldTagVersion

		$newTag = 'v' + $tagVersion.Major + '.' + $tagVersion.Minor + '.' + $tagVersion.Patch 
		if ($tagVersion.PreRelease)
		{
			$newTag += '-' + $tagVersion.PreRelease
		}
		if ($tagVersion.Build)
		{
			$newTag += '+' + $tagVersion.Build
		}
	}

	Enter-ActionOutputGroup "Dump Output Variables"

	$env:TAG_MAJOR = $tagVersion.Major
	$global:Tag_Major = $tagVersion.Major
	Write-Host "`$Tag_Major: $Tag_Major"

	$env:TAG_MINOR = $tagVersion.Minor
	$global:Tag_Minor = $tagVersion.Minor
	Write-Host "`$Tag_Minor: $Tag_Minor"

	$env:TAG_PATCH = $tagVersion.Patch
	$global:Tag_Patch = $tagVersion.Patch
	Write-Host "`$Tag_Patch: $Tag_Patch"

	$env:TAG_PRERELEASE = $tagVersion.PreRelease
	$global:Tag_PreRelease = $tagVersion.PreRelease
	Write-Host "`$Tag_PreRelease: $Tag_PreRelease"

	$env:TAG_BUILD = $tagVersion.Build
	$global:Tag_Build = $tagVersion.Build
	Write-Host "`$Tag_Build: $Tag_Build"

	$env:TAG_VERSION = $newTag
	$global:Tag_Version = $newTag
	Write-Host "`$Tag_Version: $Tag_Version"

	Exit-ActionOutputGroup

	Enter-ActionOutputGroup "Dump GitHub Variables"

	Write-Host "GITHUB_REF: $env:GITHUB_REF"
	Write-Host "GITHUB_REF_TYPE: $env:GITHUB_REF_TYPE"
	Write-Host "GITHUB_RUN_NUMBER: $env:GITHUB_RUN_NUMBER"

	Exit-ActionOutputGroup
}
