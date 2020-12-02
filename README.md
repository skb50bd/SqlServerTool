# Sql Server Tool

A simple tool to backup and restore SQL Server databases

## Requirements

- Powershell
- Microsoft SQL Server

## Usage

The tool is interactive i.e. you can just run the script and follow the prompt.

Run: `./SqlServerTool.ps1`

You can also just put all the answers in the argument of the script. 

### Example

#### Backup

`./SqlServerTool.ps1 backup . MyDb c:/SqlMyDbBackup mytag`

#### Restore
`./SqlServerTool.ps1 restore . MyDb c:/SqlMyDbBackup_20201202010101_mytag.bak`
