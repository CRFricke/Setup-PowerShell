#!/usr/bin/env pwsh

## Portions stollen from:
##    https://github.com/MADE-Apps/MADE.NET/blob/main/build/GetBuildVersion.psm1

function Get-VersionVariables {
	$tagPrefix = $env:TAG_PREFIX
	if (!$tagPrefix)
	{
		throw "Required environment variable 'TAG_PREFIX' was not found."
	}

	# For GITHUB_REF_TYPE 'tag', the old tag is the 2nd to last one.
	$count = ($env:GITHUB_REF_TYPE -eq 'tag') ? 2 : 1

	try
	{
	    $graphResult = gh api graphql -F owner='{owner}' -F name='{repo}' -F tagPrefix=$tagPrefix -F count=$count -f query=' 
query($owner: String!, $name: String!, $tagPrefix: String!, $count: Int!) {
  repository(owner: $owner, name: $name) {
    refs(refPrefix: "refs/tags/", query: $tagPrefix, last: $count) {
      nodes { name }
    }
  }
}'
	    $jsonNodes = ($graphResult | ConvertFrom-Json).data.repository.refs.nodes
		$oldTag = $jsonNodes[0].name
	}
	catch
	{
        Write-Warning "GitHub API query to find last tag failed:"
        Write-Warning "Error message: $_"
        Write-Warning "Will use default version number."
        $global:LastExitCode = 0
        $Error.Clear()
	}

	if ($oldTag)
	{
		Write-Host "Found repository tag '$oldTag'."

		$null = $oldTag -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?'
		if (!$matches)
		{
			throw "Invalid tag value found in repository: '$oldTag'."
		}

		$oldTagVersion = @{
			Major = [uint64]$matches['major']
			Minor = [uint64]$matches['minor']
			Patch = [uint64]$matches['patch']
			PreRelease = [string]$matches['pre']
			Build = $env:GITHUB_RUN_NUMBER
		}

		if (!$oldTagVersion.PreRelease)
		{
			$oldTagVersion.Patch += 1
			$oldTagVersion.PreRelease = 'beta1.0'
		}
		else
		{
			$null = $oldTagVersion.PreRelease -match '(?<prefix>[\w\d\-\.]+)\.(?<suffix>\d+)?'
			if ($matches)
			{
				$prefix = [string]$matches['prefix']
				$suffix = [uint64]$matches['suffix'] + 1
				$oldTagVersion.PreRelease = $prefix  + "." + $suffix
			}
		}
	}
	else
	{
		$null = $env:TAG_PREFIX -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?'
		if (!$matches)
		{
			throw "Invalid tag prefix found in TAG_PREFIX environment variable: $env:TAG_PREFIX."
		}

		$oldTagVersion = @{
			Major = [uint64]$matches['major']
			Minor = [uint64]$matches['minor']
			Patch = [uint64]$matches['patch']
			PreRelease = 'alpha1.0'
			Build = $env:GITHUB_RUN_NUMBER
		}
	}

	if ($env:GITHUB_REF_TYPE -eq 'tag')
	{
		$null = $env:GITHUB_REF -match '(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?(\+(?<build>[0-9A-Za-z\-\.]+))?'
		if (!$matches)
		{
			throw "Invalid tag value found in GITHUB_REF environment variable: $env:GITHUB_REF."
		}

		$tagVersion = @{
			Major = [uint64]$matches['major']
			Minor = [uint64]$matches['minor']
			Patch = [uint64]$matches['patch']
			PreRelease = [string]$matches['pre']
			Build = [string]$matches['build']
		}

		$newTag = [string]$tagVersion.Major + '.' + $tagVersion.Minor + '.' + $tagVersion.Patch 
		if ($tagVersion.PreRelease)
		{
			$newTag += '-' + $tagVersion.PreRelease
		}
		if ($tagVersion.Build)
		{
			$newTag += '+' + $tagVersion.Build
		}

		### If node count is less than count requested, skip tag validation
		### (this is the first tag for the specified TAG_PREFIX)

		if ($jsonNodes.count -eq $count)
		{
			$verOld = New-Object -TypeName System.Version -ArgumentList (
				$oldTagVersion.Major, $oldTagVersion.Minor, $oldTagVersion.Patch
				)

			$verNew = New-Object -TypeName System.Version -ArgumentList (
				$tagVersion.Major, $tagVersion.Minor, $tagVersion.Patch
				)

			if ($verOld.CompareTo($verNew) -gt 0 -or (
				$verOld.CompareTo($verNew) -eq 0 -and 
				![string]::IsNullOrEmpty($tagVersion.PreRelease) -and
				$oldTagVersion.PreRelease -gt $tagVersion.PreRelease))
			{
				throw "Error: New tag version (v$newTag) is not greater than repository tag version ($oldTag)."
			}
		}
	}
	else
	{
		$tagVersion = $oldTagVersion

		$newTag = [string]$tagVersion.Major + '.' + $tagVersion.Minor + '.' + $tagVersion.Patch 
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

	Enter-ActionOutputGroup "Dump Referenced Environment Variables"

	Write-Host "GITHUB_REF: $env:GITHUB_REF"
	Write-Host "GITHUB_REF_TYPE: $env:GITHUB_REF_TYPE"
	Write-Host "GITHUB_RUN_NUMBER: $env:GITHUB_RUN_NUMBER"
	Write-Host "TAG_PREFIX: $env:TAG_PREFIX"

	Exit-ActionOutputGroup
}
