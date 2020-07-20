# New-OoklaSpeedTest.ps1

New-OoklaSpeedTest.ps1 is a Powershell script that uses [speedtest.net’s API](https://www.speedtest.net/apps/cli) to run an Internet speed test and then format the result for Paessler’s [PRTG Network Monitor](https://www.paessler.com/prtg) to graph your Internet connection's performance. 

![PRTG-Ookla-12](https://user-images.githubusercontent.com/44954153/87398915-f075c500-c5f9-11ea-802f-6bc7e385cdb2.png)

There are five Parameters that can be used with the script. 

Parameter | Description
------------ | -------------
-ServerID | The ID of a designated Ookla Server.
-FileName | File name (and path if you wish) of a file to which the script will write the data. Any existing file of the same name will be over-written without prompting.
-AcceptGdpr | If present, this switch will add the "--accept-gdpr" switch to the Ookla query.
-Precision |	How many digits will be displayed after the decimal point. The default is 1, minimum is zero and maximum is 8.
-Retries	| How many attempts will be made to get a good Speed Test. The default is 2, minimum is zero and maximum is 4.
-Debug	| If present, the script will drop a detailed debug log file into its own folder. One per month.

You'll find more information on my blog, including detailed "how-to" steps to get your data into PRTG: https://greiginsydney.com/new-ooklaspeedtest-ps1/

&nbsp;<br>
\-G.
