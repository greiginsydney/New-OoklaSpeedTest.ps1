<#
.SYNOPSIS
	This script runs a speedtest using the Ookla API (https://www.speedtest.net/apps/cli).

.DESCRIPTION
	This script runs a speedtest using the Ookla API (https://www.speedtest.net/apps/cli).
	The output is XML (formatted for PRTG).
	Add a Filename and the same output will be saved to the named file.

.NOTES
	Version				: 1.0
	Date				: 11th July 2020
	Author				: Greig Sheridan
	See the credits at the bottom of the script

	Based on :  https://github.com/greiginsydney/Get-WeatherLinkData.ps1
	Blog post:  https://greiginsydney.com/New-OoklaSpeedTest.ps1

	WISH-LIST / TODO:

	KNOWN ISSUES:

	Revision History 	:
				v1.0 11th July 2020
					Initial release

.LINK
	https://www.speedtest.net/apps/cli
	https://greiginsydney.com/New-OoklaSpeedTest.ps1 - also https://github.com/greiginsydney/New-OoklaSpeedTest.ps1

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -precision 3

	Description
	-----------
	This executes a standard speed test against the default server for your location. Outputs to screen as XML (formatted for PRTG).
	The test results will be shown rounded to 3 decimal places.

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -ServerId nnnn

	Description
	-----------
	Queries the Ookla server Id 'nnnn' and displays the output to screen and pipeline in PRTG XML format.
	('speedtest.exe -L' lists your nearest servers.)

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -ServerId nnnn -Retries 2

	Description
	-----------
	Queries the Ookla server Id 'nnnn' and displays the output to screen and pipeline in PRTG XML format.
	If the first test fails it will initiate up to 2 more attempts before outputting a failure message.

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -ServerId nnnn -FileName OoklaSpeedTest.xml

	Description
	-----------
	Queries the Ookla server Id 'nnnn' and displays the output on screen in PRTG XML format. The same output is written to the file at OoklaSpeedTest.xml.
	If that file apready exists it will be overwritten without prompting.

.EXAMPLE
	.\New-OoklaSpeedTest.ps1 -FileName OoklaSpeedTest.xml -Debug

	Description
	-----------
	Queries the default Ookla server for your location, displaying the output on screen in PRTG XML format & saving the same output to the file at OoklaSpeedTest.xml.
	If that file apready exists it will be overwritten without prompting.
	A debug "New-OoklaSpeedTest-yyyyMMM.log" will be saved in the same location as the script.


.PARAMETER ServerID
	String. The ID of a designated Ookla Server.

.PARAMETER FileName
	File name (and path if you wish) of a file to which the script will write the data. Any existing file of the same name will be over-written without prompting.

.PARAMETER Precision
	Integer. How many digits will be displayed after the decimal point. The default is 1, minimum is zero and maximum is 8.

.PARAMETER Retries
	Integer. How many attempts will be made to get a good Speed Test. The default is 2, minimum is zero and maximum is 4.

.PARAMETER Debug
	Switch. If present, the script will drop a detailed debug log file into its own folder. One per month.

#>

[CmdletBinding(SupportsShouldProcess = $False)]
param(
	[parameter(ValueFromPipeline, ValueFromPipelineByPropertyName = $true)]
	[string]$ServerId,
	[alias('File')][string]$FileName,
	[ValidateRange(0,8)]
	[int]$Precision=1,
	[ValidateRange(0,4)]
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

function logme
{
	param ([string]$message)

	if ($debug)
	{
		add-content -path $LogFile -value ('{0:MMMdd-HHmm} {1}' -f (get-date), $message) -force
	}
}

#--------------------------------
# END FUNCTIONS -----------------
#--------------------------------


$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path -Path $scriptpath
$Global:LogFile = (Join-Path -path $dir -childpath (("New-OoklaSpeedTest-{0:yyyyMMM}.log") -f (Get-Date)))

logme ''
logme 'Launched'

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
	logme ('Output file is     "{0}"' -f $Filename)
}
else
{
	logme 'No `$Filename provided. Outputting to screen only.'
}

$SpeedTestExe = Join-Path -path $dir -childpath 'Speedtest.exe'
if (test-path $SpeedTestExe)
{
	logme ('Speedtest found at "{0}"' -f $SpeedtestExe)
}
else
{
	$message = 'Speedtest not found in this directory. Aborting.'
	write-warning $message
	logme $message
	return	
}

$params = ''
if (!([string]::IsNullorWhiteSpace($ServerId)))
{
	$params += "--server-id=$($ServerId) "
}

$params += "--format=json --precision=$($precision) --accept-license 2>&1"	# Append the handler that will capture errors
logme ('Params   = "{0})"' -f $params)

$Success = $false
$Attempt = 0
:nextAttempt while ($retries - $attempt -ge 0)
{
	$attempt ++
	write-verbose "Attempt #$($attempt)"
	try
	{
		$response = Invoke-Expression "& '$SpeedTestExe' $params" 	# "$Response" will contain <what?>
		logme "Response = $response"
		$result = $response | convertfrom-json
		if ($result.type -eq "result")
		{
			$success = $true
			break
		}
	}
	catch 
	{
		$result = "Error caught by handler: $_"
		logme $result
	}
	start-sleep -seconds 5
	logme "Retrying" 
}

[xml]$Doc = New-Object System.Xml.XmlDocument
$dec = $Doc.CreateXmlDeclaration('1.0','UTF-8',$null)
$doc.AppendChild($dec) | Out-Null
$root = $doc.CreateNode('element','prtg',$null)
	
if ($Success)
{
	logme ('InternalIp   : {0}' -f ($result.interface).InternalIp)
	logme ('IsVpn        : {0}' -f ($result.interface).IsVpn)
	logme ('ExternalIp   : {0}' -f ($result.interface).ExternalIp)
	logme ('ISP          : {0}' -f ($Result.isp))
	logme ('ID           : {0}' -f ($result.server).id)
	logme ('Name         : {0}' -f ($result.server).name)
	logme ('Location     : {0}' -f ($result.server).location)
	logme ('Country      : {0}' -f ($result.server).country)
	logme ('Host         : {0}' -f ($result.server).host)
	logme ('IP           : {0}' -f ($result.server).ip)
	logme ('Download b/w : {0}' -f ($result.download).bandwidth)
	logme ('Upload b/w   : {0}' -f ($result.upload).bandwidth)
	logme ('Jitter       : {0}' -f ($result.ping).jitter)
	logme ('Latency      : {0}' -f ($result.ping).latency)
	logme ('Packet loss  : {0}' -f $result.packetLoss)
	
	foreach ($Title in @('Download Speed', 'Upload Speed' , 'Latency', 'Jitter', 'Packet Loss'))
	{
		$child = $doc.CreateNode('element','Result',$null)
		$ChannelElement = $doc.CreateElement('Channel')
		$UnitElement = $doc.CreateElement('customUnit')
		$FloatElement = $doc.CreateElement('float');
		$ValueElement = $doc.CreateElement('value');
		$ChartElement = $doc.CreateElement('showChart');
		$TableElement = $doc.CreateElement('showTable');

		switch ($Title)
		{
			'Download Speed'
			{
				$channelelement.innertext = $Title;
				$Value = [math]::round(($result.download).bandwidth / 125000, $precision);
				$UnitElement.InnerText = 'Mb/s';
				$FloatElement.InnerText = '1';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Upload Speed'
			{
				$channelelement.innertext = $Title;
				$Value = [math]::round(($result.upload).bandwidth / 125000, $precision);
				$UnitElement.InnerText = 'Mb/s';
				$FloatElement.InnerText = '1';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Latency'
			{
				$channelelement.innertext = $Title;
				$Value = [math]::round(($result.ping).latency, $precision);
				$UnitElement.InnerText = 'ms';
				$FloatElement.InnerText = '1';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Jitter'
			{
				$channelelement.innertext = $Title;
				$Value = [math]::round(($result.ping).jitter, $precision);
				$UnitElement.InnerText = 'ms';
				$FloatElement.InnerText = '1';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			'Packet Loss'
			{
				$channelelement.innertext = $Title;
				$Value = [math]::round($result.packetLoss, $precision);
				$UnitElement.InnerText = '%';
				$FloatElement.InnerText = '0';
				$ChartElement.InnerText = '1';
				$TableElement.InnerText = '1';
			}
			default { continue }
		}
		$child.AppendChild($ChannelElement)	| Out-Null;
		$child.AppendChild($UnitElement)	| out-null;
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
	$child = $doc.CreateNode('element','error',$null)
	$child.InnerText = '1';
	$root.AppendChild($child) | Out-Null
	$child = $doc.CreateNode('element','text',$null)
	$child.InnerText = 'error';
	#append to root
	$root.AppendChild($child) | Out-Null
}
$doc.AppendChild($root) | Out-Null
$doc.InnerXML
if ($FileName) { $doc.Save($Filename)}

logme 'Exited cleanly.'

# CREDITS:
