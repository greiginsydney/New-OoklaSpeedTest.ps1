<#
.SYNOPSIS
	This script runs a speedtest using the Ookla API (https://www.speedtest.net/apps/cli).

.DESCRIPTION
	This script runs a speedtest using the Ookla API (https://www.speedtest.net/apps/cli).
	The output is XML (formatted for PRTG).
	Add a Filename and the same output will be saved to the named file.

.NOTES
	Version				: 0.0
	Date				: 1st July 2020
	Author				: Greig Sheridan
	See the credits at the bottom of the script

	Based on https://github.com/greiginsydney/Get-WeatherLinkData.ps1
	Blog post: https://greiginsydney.com/Get-WeatherLinkData.ps1

	WISH-LIST / TODO:

	KNOWN ISSUES:

	Revision History 	:
				v0.0 1st July 2020
					Commenced

.LINK
  https://www.speedtest.net/apps/cli
	https://greiginsydney.com/New-OoklaSpeedTest.ps1 - also https://github.com/greiginsydney/New-OoklaSpeedTest.ps1

.EXAMPLE
	.\New-OoklaSpeedTest.ps1

	Description
	-----------
	This executes a standard speed test against the default server for your location. Outputs to screen as XML (formatted for PRTG).

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -ServerId nnnn

	Description
	-----------
	Queries the Ookla server Id 'nnnn' and displays the output to screen and pipeline in PRTG XML format.

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -ServerId nnnn -FileName OoklaSpeedTest.csv

	Description
	-----------
	Queries the Ookla server Id 'nnnn' and displays the output on screen in csv format. The same output is written to the file at OoklaSpeedTest.csv.



.PARAMETER ServerID
	String. The ID of a designated Ookla Server.

.PARAMETER FileName
	File name (and path if you wish) of a file to which the script will write the data. Any existing file of the same name will be over-written without prompting.

.PARAMETER Retries
	Integer. How many attempts will be made to get a good Speed Test. The default is 2.

#>

[CmdletBinding(SupportsShouldProcess = $False)]
param(
	[parameter(ValueFromPipeline, ValueFromPipelineByPropertyName = $true)]
	[string]$ServerId,
	[alias('File')][string]$FileName,
	[int]$Retries=2
)

$Error.Clear()		#Clear PowerShell's error variable
$Global:Debug = $psboundparameters.debug.ispresent


#--------------------------------
# START CONSTANTS ---------------
#--------------------------------

#--------------------------------
# END CONSTANTS -----------------
#--------------------------------

#--------------------------------
# START FUNCTIONS ---------------
#--------------------------------

#--------------------------------
# END FUNCTIONS -----------------
#--------------------------------


$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path -Path $scriptpath
$LogFile = (Join-Path -path $dir -childpath "New-OoklaSpeedTestLOG-")
$LogFile += (Get-Date -format "yyyyMMdd-HHmm") + ".log"

if ($FileName)
{
	#If the user only provided a filename, add the script's path for an absolute reference:
	if ([IO.Path]::IsPathRooted($FileName))
	{
		#It's absolute. Safe to leave.
	}
	else
	{
		#It's relative.
		$FileName = [IO.Path]::GetFullPath((Join-Path -path $dir -childpath $FileName))
	}
}

$SpeedTestExe = Join-Path -path $dir -childpath "Speedtest.exe"
if (!(test-path $SpeedTestExe))
{
	$message = "Speedtest not found in this directory. Aborting"
	write-warning $message
	add-content -path $LogFile -value $message -force
	return
}

$params = ""
if (!([string]::IsNullorWhiteSpace($ServerId)))
{
	$params += "--server-id=$ServerId "
}

$params += "--format=json 2>&1"	# Append the handler that will capture errors
#write-host $params -foregroundcolor cyan

$Success = $false
$Attempt = 0
:nextAttempt while ($retries - $attempt -ge 0)
{
	$attempt ++
	#write-verbose "Attempt #$($attempt)"
	
	try
	{
		$response = Invoke-Expression "& '$SpeedTestExe' $params" 	# "$Response" will contain <what?>
		add-content -path $LogFile -value "Success:`n`r$response" -force
		$success = $true
		break
	}
	catch 
	{
		$response = "Error caught by handler: $_"
		add-content -path $LogFile -value "Error: $_" -force
	}
}
$result = $response | convertfrom-json 
#$result
#$Result.packetLoss
#$Result.isp
#($result.server).location

[xml]$Doc = New-Object System.Xml.XmlDocument
$dec = $Doc.CreateXmlDeclaration("1.0","UTF-8",$null)
$doc.AppendChild($dec) | Out-Null
$root = $doc.CreateNode("element","prtg",$null)
if ($Success)
{
	foreach ($Title in @('Server ID', 'Latency', 'Jitter', 'Packet Loss', 'Download Speed', 'Upload Speed'))
	{
		$child = $doc.CreateNode("element","Result",$null)
		$ChannelElement = $doc.CreateElement('Channel')
		$UnitElement = $doc.CreateElement('customUnit')
		$FloatElement = $doc.CreateElement('float');
		$ValueElement = $doc.CreateElement('value');
		$ChartElement = $doc.CreateElement('showChart');
		$TableElement = $doc.CreateElement('showTable');

		switch ($Title)
		{
			'Server ID'
			{
				$ChannelElement.InnerText = $Title;
				$Value = ($result.server).id
				#$UnitElement.InnerText = if ($metric) { "&#8451;" } else { "&#8457;" };
				$FloatElement.InnerText = '0';
				$ChartElement.InnerText = '0';
				$TableElement.InnerText = '1';
			}
			'Latency'
			{
				$channelelement.innertext = $Title;
				$Value = ($result.ping).latency
				#$UnitElement.InnerText = "%";
				$FloatElement.InnerText = "1";
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Jitter'
			{
				$channelelement.innertext = $Title;
				$Value = ($result.ping).jitter
				#$UnitElement.InnerText = if ($metric) { "&#8451;" } else { "&#8457;" };
				$FloatElement.InnerText = "1";
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Packet Loss'
			{
				$channelelement.innertext = $Title;
				$Value = $result.packetLoss
				#$UnitElement.InnerText = "%";
				$FloatElement.InnerText = '0';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Download Speed'
			{
				$channelelement.innertext = $Title;
				$Value = ($result.download).bandwidth
				#$UnitElement.InnerText = if ($metric) { "hPa" } else { "Hg" };
				$FloatElement.InnerText = '0';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Upload Speed'
			{
				$channelelement.innertext = $Title;
				$Value = ($result.upload).bandwidth
				#$UnitElement.InnerText = if ($metric) { "km/h" } else { "mph" };
				$FloatElement.InnerText = '0';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			default { continue }
		}
		$child.AppendChild($ChannelElement)	| Out-Null;
		#$child.AppendChild($UnitElement)	| out-null;
		$child.AppendChild($FloatElement)	| out-null;
		$ValueElement.InnerText = $Value
		$child.AppendChild($ValueElement)	| out-null;
		$child.AppendChild($ChartElement)	| out-null;
		$child.AppendChild($TableElement)	| out-null;
		#append to root
		$root.AppendChild($child) | Out-Null
	}
}
else
{
	$child = $doc.CreateNode("element","error",$null)
	$child.InnerText = '1';
	$root.AppendChild($child) | Out-Null
	$child = $doc.CreateNode("element","text",$null)
	$child.InnerText = 'error';
	#append to root
	$root.AppendChild($child) | Out-Null
}
$doc.AppendChild($root) | Out-Null
$doc.InnerXML
if ($FileName) { $doc.Save($Filename)}


# CREDITS:
