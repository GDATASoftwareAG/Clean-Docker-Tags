# Clean Docker Tags

This _PowerShell_ script shows and deletes unused _Docker_ tags from an [JFrog Artifactory](https://jfrog.com/artifactory/) _Docker_ registry.

## What it does

The script searches for unused _Docker_ tags based on a given date. All Docker tags which haven't been downloaded since the date are presented. If the user wants, he can delete those tags. Per default, the script keeps all "latest" tags and the last three version tags. How many version tags should be kept, can be specified by a parameter.

## Usage

Download the script and run it in _PowerShell_. To show help with examples and explained parameters, run:

```powershell
Get-Help -detailed ./clean_unused_tags.ps1
```
