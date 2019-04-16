<#
.SYNOPSIS
    Cleans up unused Docker tags from an Artifactory registry.
.DESCRIPTION
    Searches for unused Docker tags based on a given time period.
    Deletes all tags except a specified amount of the newest tags and 
    always keeps the "latest" tag.
.EXAMPLE
    .\clean_unsused_tags -User "user@company.org" -Password "super_secret" -NotUsedSince "01-06-2018" -ArtifactoryUri "https://artifactory.company.org" -Repository "team-docker"
    Show candidates for deletion.
.EXAMPLE
    .\clean_unsused_tags -User "user@company.org" -Password "super_secret" -NotUsedSince "01-06-2018" -ArtifactoryUri "https://artifactory.company.org" -Repository "team-docker" -CleanUp
    Delete all candidates.
.PARAMETER User
    Admin user for Artifactory login.
.PARAMETER Password
    Admin password for Artifactory login.
.PARAMETER ArtifactoryUri
    URI of your Artifactory, e.g. "https://artifactory.company.org" 
    without tailing slash.
.PARAMETER Repository
    Name of the Docker repository to clean up.
.PARAMETER NotUsedSince
    Date string which specifies since when an tag has to be
    unused to be a candidate for deletion. Format "dd-MM-yyyy".
.PARAMETER TagsToKeep
    How many tags (except "latest") you want to keep. Defaults to 3.
.PARAMETER CleanUp
    If this flag is set, the tags are deleted. If the flag is not set
    the candidates for deletion are only printed but nothing gets 
    deleted.
#>

Param(
    [Parameter(Mandatory = $true)]
    [string]$User, 
    
    [Parameter(Mandatory = $true)]
    [string]$Password,

    [Parameter(Mandatory = $true)]
    [string]$ArtifactoryUri,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$NotUsedSince,

    [int]$TagsToKeep = 3,

    [switch] $CleanUp
)

function getCredentialsHeaders($user, $password) {
    $credPair = "$($user):$($password)"
    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
    $headers = @{ Authorization = "Basic $encodedCredentials" }
    return $headers
}

function convertToUnixTimestamp($date) {
    $dateTime = [datetime]::ParseExact($date, 'dd-MM-yyyy', $null)
    return [int64]($dateTime - (Get-Date "1/1/1970")).TotalMilliseconds
}

function getUnusedArtifacs($notUsedSinceMs, $repo) {
    $requestUri = $ArtifactoryUri + "/api/search/usage?notUsedSince=$notUsedSinceMs&createdBefore=$notUsedSinceMs&repos=$repo"
    $credentialHeader = getCredentialsHeaders $User $Password
    return (Invoke-WebRequest -Uri $requestUri -Headers $credentialHeader | ConvertFrom-Json).results
}

function deleteArtifact($repo, $image) {
    $requestUri = $ArtifactoryUri + "/" + $repo + "/" + $image.Image + "/" + $image.Tag
    $credentialHeader = getCredentialsHeaders $User $Password
    if ((Invoke-WebRequest -Method Delete -Uri $requestUri -Headers $credentialHeader).statuscode -eq 204) {
        return $true
    }
    else {
        return $false
    }
}
function convertArtifactsToHashTable($artifacts) {
    $images = @()
    foreach ($artifact in $artifacts) {
        if ($artifact.downloadCount -eq 0) {
            $split = $artifact.uri.Split("/")
            $artifact = @{
                Image = ([string]$split[6 .. ($split.count - 3)]).Replace(" ", "/")
                Tag   = [string]$split[-2]
            }
            $images += $artifact
        }
    }
    return $images
}

function filterTagsToKeep($images) {
    $images | 
    Sort-Object -Unique -Property { $_.Image + $_.Tag } | 
    Where-Object { $_.Tag -cne "latest" } | 
    Group-Object -Property { $_.Image } | 
    Where-Object { $_.Count -gt $TagsToKeep } | 
    Sort-Object -Property Count -Descending
}

$unusedArtifacs = getUnusedArtifacs (convertToUnixTimestamp $NotUsedSince) $Repository
$images = convertArtifactsToHashTable $unusedArtifacs
$candidates = filterTagsToKeep $images

$count = 0
foreach ($group in $candidates) {
    $delete = $group.Group[0 .. ($group.Count - $tagsToKeep)]

    foreach ($entry in $delete) {
        $image = "Image: " + $entry.Image + "Tag: " + $entry.Tag
        Write-Host "Deletion candidate ->" $image -ForegroundColor Yellow
        
        if ($CleanUp) {
            if (deleteArtifact $repo $entry) {
                Write-Host "Successfully deleted ->" $image -ForegroundColor Green
            }
            else {
                Write-Host "Failed to delete ->" $image -ForegroundColor Red
            }
        }
        $count = $count + 1
    }
}

Write-Host "# Candidates for deletion: $count"

