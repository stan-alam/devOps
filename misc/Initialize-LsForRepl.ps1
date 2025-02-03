<#
.NOTES
	This script requires PoSHLog and PoSHLog.Enhancers be installed before running
	the script. These commands will install the PoSHLog requirements:
		Install-Module -Name PoShLog
		Install-Module -Name PoShLog.Enrichers
.SYNOPSIS
    This is the entry point for the simulation
.DESCRIPTION
    Generates all the necessary files for Replenishments then optionally configures the
	Logiscend server with drivers, routes, parts, part-source, part-destination, workstations etc.
.PARAMETER Filename
    Required: [string] Points to a JSON file with all the parameters for this run.
.PARAMETER ConfigureLogiscend
    Required: [bool] Tells the script to configure Logiscend with pickers, routes, parts, 
    locations and so on. Useful when initially configuring a system for simulation. After
    the LS server is configured and has a checkpoint or snapshot, this flag isn't needed.
.PARAMETER RoutesFile
    Required: [string] Indicates the routes.json for creating locations, drivers, routes, parts and workstations
.PARAMETER CustomerProfile
    Required: [string] Customer Profile json. Mostly custom settings based on a Customer Profile
.EXAMPLE
    Initialize-LsForRepl `
        -Filename VirtualDriverTemplate.json `
        -ConfigureLogiscend: True `
		-RoutesFie routes.json `
		-CustomerProfile CustomerProfile.json      
#>

[CmdletBinding()]
Param
	(
	[Parameter( Mandatory = $true, Position = 0)]
    [string]$Filename,

	[Parameter( Mandatory = $true, Position = 1)]
    [string]$ConfigureLogiscend,

	[Parameter( Mandatory = $true, Position = 2)]
    [string]$RoutesFile,

	[Parameter( Mandatory = $true, Position = 3)]
    [string]$CustomerProfile
	)

function Get-TimeStamp
{
    <#
    .SYNOPSIS
        Creates a formatted timestamp
    .DESCRIPTION
        Creates a formatted timestamp suitable for output to the powershell terminal
        or to a log file.
    .EXAMPLE
        Get-TimeStamp
    #>
    return "[{0:MM/dd/yy} {0:HH:mm:ss.fff}]" -f (Get-Date)
}

function Add-LsDriver
{
    <#
    .SYNOPSIS
        Adds a driver to Logiscend using the /api/users API
    .DESCRIPTION
		Construct a JSON payload for each user to be added and POST to /api/users. Generates LineSide drivers only
		Duplicate user errors are ignored. All others cause the script to fail.
	.PARAMETER RoutesFile
    	Required: [string] Points to a JSON file with all the parameters for this run.
    .EXAMPLE
		Add-LsDriver -Filename VirtualDriverTemplate.json
    #>

	[CmdletBinding()]
    Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$Filename
    )
	# read the json user template file as a starting point
    $DriverTemplate = Get-Content ./DriverTemplate.json -Raw | ConvertFrom-Json
    
	# read the VirtualDriverTempplate file (this already has the username, password, and e-mail)
	# the VirtualDriverTemplate file is something like VirtualDriverTemplate -
	$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json

	# update the payload with specific values for this driver
	$DriverTemplate.username = $RouteConfig.LsDriverPassword # yes this is the username too
	$DriverTemplate.password = $RouteConfig.LsDriverPassword
	$DriverTemplate.firstName = $RouteConfig.LsDriverPassword
	$DriverTemplate.lastName = $RouteConfig.LsDriverPassword
	$DriverTemplate.email = $RouteConfig.LsDriverUsername

	$JsonPayload = $DriverTemplate | ConvertTo-Json

	$LsHost = $RouteConfig.LsHost
    $Uri = "https://${LsHost}/api/users"

	$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw

	#Read the number of routes and create virtual-drivers based on that number
	try 
	{
		$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri `
			-Method "POST" `
			-Authentication "Basic" `
			-AllowUnencryptedAuthentication `
			-Credential $Credential `
			-Body $JsonPayload `
			-ContentType "application/json"
	}
	catch 
	{
		$msg = $_.ErrorDetails.Message | ConvertFrom-Json
		if($msg.errorCode -eq "ERR_DUPLICATE_FIELD")
		{
			Write-InfoLog "Driver already exists. Continuing..."
		}
		else
		{
			Write-ErrorLog "Problem creating users. Review input parameters and try again."
			Stop-Script -Message $_.Exception.Response
		}
	}
	$Response
}

function New-LsVirtualDrivers
{
    <#
    .SYNOPSIS
    Adds a driver to Logiscend using the /api/users API
	.DESCRIPTION
	Generates VirtualDriver files based on the number of routes in the routes.json
	.PARAMETER RoutesFile
    Required: [string] Points to a JSON file with all the parameters for this run.
	.EXAMPLE
		Add-LsDriver routes.json
    #>

	$RouteFileDS = Get-Content $RoutesFile | ConvertFrom-Json -AsHashtable

	try 
	{
		# Generate a list drivers for each route
		# for every Route:
	    # create a Route-pecific virtualDriver-Route.json based off the parameters passed in.
	    #
		$Index = 0
		foreach($Name in $RouteFileDs.RouteName)
		{
			$RouteName = $RouteFileDS.RouteName.Keys[$Index]
		#	[string]$RouteName = $FileExt.Keys
    
			# read the VirtualDriverTemplate (this already has the username, password, and e-mail)
			$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
	     
	        # construct the username and password for the driver
	        $RouteConfig.LsDriverUsername = "driver$RouteName@panasonic.com"
	        $RouteConfig.LsDriverPassword = "driver$RouteName"
	
		#	[string]$RouteName = $FileExt.Keys
	        # write the route-specific VirtualDriverTemplate.json file
	        $NewFilename = "VirtualDriver-$RouteName.json" -f $RouteName
			Write-InfoLog "Creating $NewFilename"
	        $RouteConfig | ConvertTo-Json | Out-File $NewFilename
			$Index++
		}
	}
	catch 
	{
		Write-ErrorLog "Problem configuration files. Review command line parameters and try again."
		Stop-Script -Message $_.Exception.Message
	}
}


function Add-LsDrivers
{
    <#
    .SYNOPSIS
        Adds one driver for each route defined in the startup parameters.
    .DESCRIPTION
		For each route, the driver information is defined in the VirtualDriverTemplate file 
		for that route. For all route configuration files, pass the filename to Add-LsDriver
		for a user to be added to Logiscend.
    .EXAMPLE
		Add-LsDrivers
    #>

	$Add_LsDriversResponseList = New-Object System.Collections.ArrayList
	$Response = Get-ChildItem | Where-Object { $_.Name -match 'VirtualDriver-' } | ForEach-Object { Add-LsDriver -Filename $_.Name }
	$Add_LsDriversResponseList.Add($Response)
	$Add_LsDriversResponseList

}

function New-LsLocation()
{
    <#
    .SYNOPSIS
        Creates a location based on if the location is a part source or destination
    .DESCRIPTION
		Generates locations by posting to the api/locations endpoint
    .PARAMETER isPartSource
		Required: [bool] The true/false will differentiate between generating part source location or part destination
    .PARAMETER Filename
	    Required: [string] Points to the VirtualDriverTemplate.json for configuration details
    .EXAMPLE
		New-LsLocation -isPartSource:true -Filename VirtualDriverTemplate.json
    #>
    
	[CmdletBinding()]
    Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[bool]$isPartSource,

		[Parameter(Mandatory = $true, Position = 1)]
		[string]$Filename
	)
	# read the json user template file as a starting point
    $DriverTemplate = Get-Content ./DriverTemplate.json -Raw | ConvertFrom-Json
    
	$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json

	$Params = Get-Content $CustomerProfile -Raw | ConvertFrom-json 

	# update the payload with specific values for this Driver
	$DriverTemplate.username = $RouteConfig.LsDriverPassword # yes this is the username too
	$DriverTemplate.password = $RouteConfig.LsDriverPassword
	$DriverTemplate.firstName = $RouteConfig.LsDriverPassword
	$DriverTemplate.lastName = $RouteConfig.LsDriverPassword
	$DriverTemplate.email = $RouteConfig.LsDriverUsername
	
	[string]$Description = Get-Date
	
	try 
	{
		# request body for creating a part source
		if($Params.Version -ge "3" ) 
		{  
			if ($isPartSource)
			{
				# read how many Workstations there will be by counting the Workstation Array index in routes.json
				$RoutesFile = Get-Content "./routes.json" | ConvertFrom-Json -AsHashtable
				$SourceLocResponseObj = New-Object System.Collections.ArrayList
				$WorkStations = $RoutesFile.Values | ConvertTo-Json -depth 10 | ConvertFrom-Json -AsHashtable
				$NumberOfWorkstations = $Workstations.Values.PartsPerWorkStation

				foreach($WorkStation in $NumberOfWorkstations) 
				{
					$PartSourceLocationName = "PartSource"
					$LocationName = Get-Random
					$body = @{
						"isSelected"= "false"
						"isSelectable"= "true"
						"isReadOnly"= "false"
						"isPartSource"= "true"
						"isPartDestination"= "false"
						"callButtonTemplate" = "call_button_1"
						"isZoneBatchPickZone"= "false"
						"isZoneWavePickZone"= "false"
						"isZoneLinesidePickZone"= "false"
						"isPickZoneAutoStart"= "false"
						"isPickZone"= "false"
						"isDeleted"= "false"
						"name"= "$PartSourceLocationName-"+$LocationName
						"description"= $Description
						"pickZoneTemplate"= $Null
						"containerTypes"= @()
						"userGroupIds" = @("1")
						"userGroupNames" = @("Logiscend Default")
					}
					
					$LsHost = $RouteConfig.LsHost
					$Port = "443"
					$Uri = "https://${LsHost}:$Port/api/locations"
					$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
					$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
					$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($body|ConvertTo-Json) -ContentType "application/json"
					$ResponseObj = ($Response.Content | ConvertFrom-Json)
					$SourceLocResponseObj.Add($ResponseObj) | Out-Null
				}

				$SourceLocResponseObj
			}
			else 
			{
				$PartDestinationLocationName = "PartDestination"
				# read how many Workstations there will be by counting the Workstation Array index in routes.json
				$RoutesFile = Get-Content "./routes.json" | ConvertFrom-Json -AsHashtable
				$DestinationResponseObj = New-Object System.Collections.ArrayList
				$WorkStations = $RoutesFile.Values | ConvertTo-Json -depth 10 | ConvertFrom-Json -AsHashtable
				$NumberOfWorkstations = $Workstations.Values.PartsPerWorkStation
				$Index = 1
				foreach($WorkStation in $NumberOfWorkstations) 
				{
					# create a locationDestination
					$LocationName = Get-Random
					$body = @{
						"isSelected"= "false"
						"isSelectable"= "true"
						"isReadOnly"= "false"
						"isPartSource"= "false"
						"isPartDestination"= "true"
						"callButtonTemplate" = "call_button_1"
						"isZoneBatchPickZone"= "false"
						"isZoneWavePickZone"= "false"
						"isZoneLinesidePickZone"= "false"
						"isPickZoneAutoStart"= "false"
						"isPickZone"= "false"
						"isDeleted"= "false"
						"name"= "$PartDestinationLocationName-"+$LocationName
						"description"= $Description
						"pickZoneTemplate"= $Null
						"containerTypes"= @()
						"userGroupIds" = @("1")
						"userGroupNames" = @("Logiscend Default")
					}

					$LsHost = $RouteConfig.LsHost
					$Port = "443"
					$Uri = "https://${LsHost}:$Port/api/locations"
					$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
					$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
					$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($body|ConvertTo-Json) -ContentType "application/json"
					$ResponseObj = ($Response.Content | ConvertFrom-Json)  ### may need to use ID when associating partsource with destination, like when creating a destination ?
					$Index++
					$DestinationResponseObj.Add($ResponseObj)
				}
				
				$DestinationResponseObj 			
			}	
		} 
		else 
		{
			$body = @{
				"isSelected"= "false"
				"isSelectable"= "true"
				"isReadOnly"= "false"
				"isPartSource"= "true"
				"isPartDestination"= "false"
				"isZoneBatchPickZone"= "false"
				"isZoneWavePickZone"= "false"
				"isZoneLinesidePickZone"= "false"
				"isPickZoneAutoStart"= "false"
				"isPickZone"= "false"
				"isDeleted"= "false"
				"name"= "$Name-$Sequence"
				"description"= $Description
				"pickZoneTemplate"= $Null
				"containerTypes"= @()
				"parentLocationId"= $Parent
			}

			Write-InfoLog("Running 2.4 configuration")
			$LsHost = $RouteConfig.LsHost
			$Port = "443"
			$Uri = "https://${LsHost}:$Port/api/locations"
			$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
			$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
			$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($body|ConvertTo-Json) -ContentType "application/json"
			$Id = ($Response.Content | ConvertFrom-Json).Id	
		    $Id
		}

	}
	catch 
	{
		Write-ErrorLog "Problem creating Location"
		Stop-Script -Message $_.Exception.Message
	}
}
function New-LsPartSourceLocation()
# calls the New-LsLocation helper function to generate part Source Locations
{
	$SourceLocResponseObj= New-LsLocation -isPartSource $True -Filename $Filename
	return $SourceLocResponseObj

}

function New-LsPartDestinationLocation() 
# calls the New-LsLocation helper function to generate part destinations
{
	$DestinationResponseObj = New-LsLocation -isPartSource $False -Filename $Filename
	return $DestinationResponseObj

}

function New-LsPartPerSourceLocation()
{
	<#
    .SYNOPSIS
    Adds Parts per Source Location
	.DESCRIPTION
	Generates the json that is used to post a part to its SourceLocation. This is a helper function.
	.EXAMPLE
	New-LsLocation
	#>

	# read the json user template file as a starting point
    $DriverTemplate = Get-Content ./DriverTemplate.json -Raw | ConvertFrom-Json
	$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
	$DriverTemplate.username = $RouteConfig.LsDriverPassword # yes this is the username too
	$DriverTemplate.password = $RouteConfig.LsDriverPassword
	$DriverTemplate.firstName = $RouteConfig.LsDriverPassword
	$DriverTemplate.lastName = $RouteConfig.LsDriverPassword
	$DriverTemplate.email = $RouteConfig.LsDriverUsername
	$RoutesFile = Get-Content $RoutesFile | ConvertFrom-Json -AsHashtable
	$WorkStations = $RoutesFile.Values | ConvertTo-Json -depth 10 | ConvertFrom-Json -AsHashtable
	$NumberOfWorkstations = $Workstations.Values.PartsPerWorkStation
	$LsPartPerSourceLocationReturnObj = New-Object System.Collections.ArrayList	
	$Index = 0
	$locId = 1

	foreach($WorkStation in $NumberOfWorkstations)
	{	   
		[int]$Value = $NumberOfWorkstations[$Index]
							
		for($i=0; $i -lt $Value; $i++)
		{	
			[string]$Number = Get-Random
			$body = @{
				"replenishmentStageMode"= "Single"
				"number"= "$Number"
				"description"= "Part-$Number"
				"defaultQuantity"= "10"
				"locationIds"= @($locId)
				"userGroupIds" = @(1)
			}
			
			$LsHost = $RouteConfig.LsHost
			$Port = "443"
			$Uri = "https://${LsHost}:$Port/api/parts"
			$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
			$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
			$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($body|ConvertTo-Json) -ContentType "application/json"
			$ResponseObj = ($Response.Content | ConvertFrom-Json)  
			$LsPartPerSourceLocationReturnObj.Add($ResponseObj) | Out-Null			
	    }
		$Index++
		$locId++	
	}

	$LsPartPerSourceLocationReturnObj
}
function New-LsCallButton()
{
	<#
	.NOTES
		Each callbutton must represent a part
	.DESCRIPTION
		Generates all the necessary files for Replenishments then optionally configures the
		Logiscend server with drivers, routes, parts, part-source, part-destination, workstations etc.
	.PARAMETER partsIDs
		Required: [array] An array of Part IDs to be associated with their callbuton
	.PARAMETER destIDs
		Required: [array] An array of numbers which are used when creating a callbutton based on the destination the part is associated with
	.EXAMPLE
		New-LsCallButton `
			-partIDs 10, 12, 17 `
			-destIDs 1, 5, 3,    
	#>

	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Array]$partIDs,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[Array]$destIDs
	)

	$Index = 0
	$LsCallButtonResponseObj = New-Object System.Collections.ArrayList
	$RoutesFile = Get-Content $RoutesFile | ConvertFrom-Json -AsHashtable
	$WorkStations = $RoutesFile.Values | ConvertTo-Json -depth 10 | ConvertFrom-Json -AsHashtable
	$NumberOfWorkstations = $Workstations.Values.PartsPerWorkStation
	$PartsIndex = 0

	foreach($WorkStation in $NumberOfWorkstations) #create callbuttons based on the parts with their destination aka Workstations
	{	
		[int]$Value = $NumberOfWorkstations[$Index]
		
		for($i=0; $i -lt $Value; $i++)   #create callButtons
		{
			$FormattedZone = "{0:d3}" -f ( Get-Random -Minimum 0 -Maximum 999 )
			$uid = "D9AE240$FormattedZone" + '{0:d6}' -f ( Get-Random -Minimum 0 -Maximum 99999 )
			$CallButtonRequestBody = @{
				"uid" = "$uid"
				"buttons"= 
				@(@{
					"buttonNumber" = "1"
					"pageNumber" = "1"
					"partId" = $partIDs[$PartsIndex]
					"quantity" = "10"
				})
	
				"locationId" = $destIDs[$Index]
				}
		
			$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
		
			$LsHost = $RouteConfig.LsHost
			$Uri = "https://${LsHost}/api/callbuttons"
			$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
			$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
			$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($CallButtonRequestBody|ConvertTo-Json) -ContentType "application/json"
			$ResponseObj = $Response.Content | ConvertFrom-Json 
			$LsCallButtonResponseObj.Add($ResponseObj) | Out-Null
			$PartsIndex++			
		}
		$Index++
	}

	$LsCallButtonResponseObj
}

function New-LsThreshold
{
	<#
	.NOTES
		Only generates a static Threshold to be used throughout the script
		default is 180 seconds
	.DESCRIPTION
		Generates a threshold by consuming the /api/thresholds endpoint
	.EXAMPLE
		New-LsRoute -Name TestThreshold
	#>

	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		$Name     								# Name is the name of the Threshold and is a required field.
	)
	$body = @{
		"pickDurationInSeconds" = "180"   
		"deliverDurationInSeconds" = "180"
		"totalDurationInSeconds" = "360"
		"name"= "$Name"
		"description"= "Test"
		"warning" = "1"
	}

	$body|ConvertTo-Json
	$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
	
	$LsHost = $RouteConfig.LsHost
	$Uri = "https://${LsHost}/api/thresholds"
	$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
	$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
	$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($body|ConvertTo-Json) -ContentType "application/json"
	$ThresholdResponse = ($Response.Content | ConvertFrom-Json) ### use the Threshold ID for Routes
	$ThresholdResponse
}

function New-LsRoute
{
	<#
	.NOTES
		the routes.json must be properly formed json. it does not take any params
	.DESCRIPTION
		Generates the Routes from the route.json file by consuming the api/routes endpoint
	.EXAMPLE
		New-LsRoute
	#>

	#When Creating The Routes You need to add the Drivers - read the virtualDrivers
	# Read the VirtualDriver-*.json count and loop through
	$Index = 0
	$VirtualDriverFiles = Get-ChildItem | Where-Object { $_.Name -match 'VirtualDriver-' }
	# read the json user template file as a starting point
	$RouteFileContents = Get-Content $RoutesFile | ConvertFrom-Json -AsHashtable
	$RouteNames        = $RouteFileContents.RouteName
	
	foreach($Driver in $VirtualDriverFiles)
	{
		$DriverDetails = Get-Content  $VirtualDriverFiles[$Index] | ConvertFrom-Json -AsHashtable  
		$username  = $DriverDetails.LsDriverPassword
		$firstName = $DriverDetails.LsDriverPassword
		$lastName  = $DriverDetails.LsDriverPassword
		$email     = $DriverDetails.LsDriverUsername
		[int]$DriverID =  $DriverIDs.id[$Index].ToString()
		[string]$RouteName  =  $RouteNames.Keys[$Index]
		$RouteDesc = "test"

		$body = @{
			"name"= "$RouteName"
			"description" = "$RouteDesc"
			"userIds" = @($DriverID)
			"users" = @(@{
				"isDeleted"= "false"
				"deletedDate" = "null"
				"deletedBy"  = "null"
				"roleNames" = @("Lineside Driver")
				"userGroupNames" = @("Logiscend Default")
				"isLocal" = "true"
				"id" = $DriverID
				"username"  = $username
				"firstName" = $firstName
				"lastName"  = $lastName
				"email" = $email
				"isLocked" = "false"
				"doNotLogOff" = "false"
				"smsAddress" = "null"
				"invalidLoginAttempts" = "null"
				"roleIds" = @(2)
				"userGroupIds"= @(1)
			})
		}
		$Index++
		$Filename = "./VirtualDriverTemplate.json"
		$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
		$LsHost = $RouteConfig.LsHost
		$Uri = "https://${LsHost}/api/routes"
		$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
		$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
		$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "Post" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($body|ConvertTo-Json) -ContentType "application/json"
		($Response.Content | ConvertFrom-Json)  
	}
}

function New-LsWorkStation()
{
	<#
	.NOTES
		Routes and callbuttons must be setup, each callbutton must be associated with their source Location
	.DESCRIPTION
		Generates Workstations with parts and their source locations
	.PARAMETER LocationIDwithPartID
		Required: [array] An array of Part IDs associated with their part id
	.PARAMETER RouteNames
		Required: [array] An array route names from which workstations will be stored in
	.PARAMETER RouteIDs
		Required: [array] An array of numbers an id which refers to the route from which the workstation will belong to
	.PARAMETER DriverIDs
		Required: [array] An array of numbers that that identify which driver is assoicated with in a route
	.PARAMETER RouteDescriptions
		Required: [array] An array of strings describing routes
	.PARAMETER ThresholdResponseId
		Required: [int] A single number to identify the threshold of which will be used by the Workstations
	.EXAMPLE
		New-LsWorkStations `
			-LocationIDwithPartID `
			-RouteNames MyRoute01 Myroute02 `
			-RouteIDs 12 23 `
			-DriverIDs 04 234 `
			-RouteDescriptions "This is a test route", "This is the second test route" `
			-ThresholdResponseId 10
	#>
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		$LocationIDwithPartID,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[array]$RouteNames,

		[Parameter(Mandatory = $true, Position = 2)]
		[ValidateNotNullOrEmpty()]
		[array]$RouteIDs,

		[Parameter(Mandatory = $true, Position = 3)]
		[ValidateNotNullOrEmpty()]
		[array]$DriverIDs,

		[Parameter(Mandatory = $true, Position = 4)]
		[ValidateNotNullOrEmpty()]
		[array]$RouteDescriptions,

		[Parameter(Mandatory = $true, Position = 5)]
		[ValidateNotNullOrEmpty()]
		[int]$ThresholdResponseId
	)

	$RoutesFile = Get-Content "./routes.json" | ConvertFrom-Json -AsHashtable

	$RouteIndex = 0
	$Index = 0
	$partIDindex = 0
	$RouteNameIndex = 0
	
	foreach($NumberOfRoutes in $RouteNames) 
	{
    	[int]$Value = $RoutesFile.RouteName.Values[$RouteIndex].PartsPerWorkStation.count
									
		$NewJsonBody = New-Object System.Collections.ArrayList
		$RouteDetailArray = New-Object System.Collections.ArrayList
		#how many workstations in this route loop through them		
		for($j=0; $j -lt $Value; $j++)
		{				
			foreach($PartId in $LocationIDwithPartID[$RouteNameIndex].callButtons.buttons.partId) 
			{				
				$routeDetails = @{
				"locationId"= $LocationIDwithPartID[$RouteNameIndex].locationId
				"routeId"= $RouteIDs[$RouteIndex]
				"partId" = $PartId
				"thresholdId" = $ThresholdResponseId
				}
				$RouteDetailArray.Add($routeDetails)				
			}
			$RouteNameIndex++
		}

		$JsonBody = @{
			"isDeleted"= "false"
			"deletedDate"= "null"
			"deletedBy" = "null"
			"userIds"= @(2)
			"id" = $DriverIDs[$RouteIndex]
			"name" = $RouteNames[$RouteIndex]
			"description" = $RouteDescriptions[$RouteIndex]
			"routeDetails" =  @($RouteDetailArray)
		}

		$body = ($JsonBody | ConvertTo-Json)
		$partIDindex++
		$NewJsonBody.Add($body)
		$Filename = "./VirtualDriverTemplate.json"
		$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
		$RouteID = $RouteIDs[$RouteIndex]
		$LsHost = $RouteConfig.LsHost
		$Uri = "https://${LsHost}/api/routes/$RouteID"
		$Pw = ConvertTo-SecureString -String $RouteConfig.LsApiPassword -AsPlainText -Force
		$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RouteConfig.LsApiUsername, $Pw
		$Response = Invoke-WebRequest -SkipCertificateCheck -Uri $Uri -Method "PUT" -Authentication "Basic" -AllowUnencryptedAuthentication -Credential $Credential -Body ($NewJsonBody) -ContentType "application/json"
		$Index++
		$RouteIndex++		
	}
}
function Stop-Script
{
    <#
    .SYNOPSIS
        Universal exit point for this script.
    .DESCRIPTION
		This function is called any time the script needs to abort. Reasons for abort
		include but are not limited to:
			
			- Failure to configure Logiscend in any way. For example, failed to create 
			drivers, routes, parts, tags, etc.
			- Failure to commission tags
			- Failure to communicate with the Gateway Simulator server
			- Other failures TBD

		Minimally this function will close the logs so that their conent is available.
		Failire to close the logs results in the last few lines of the log being missing.

    .EXAMPLE
		Stop-Script
    #>

    [CmdletBinding()]
    Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$Message
    )

	Write-InfoLog($Message)
	Close-Logger
	exit
}

function Start-Script
{
    <#
    .SYNOPSIS
        Entry point for this script.
    .DESCRIPTION
		This is the first function called when this script is executed. This function takes
		no parameters as any parameters for the script have been passed in and are either
		globally available or are in a configuration file this script can derive from
		the parameteres or exist by convention.
    .EXAMPLE
		Start-Script
    #>

	# create a timestamp for the log file and start it
	$Stamp = (Get-Date).toString("yyyyMMddHHmmss")
	$Path = ".\Initialize-LsForRepl-Log-$Stamp.log"

	# Logging utility is required for this script to run
	Import-Module PoShLog
	Import-Module PoShLog.Enrichers
	$LogEntryTemplate = "[{Level:u3}]: [{MachineName} | {Timestamp:yyyy-MM-dd} | {Timestamp:HH:mm:ss.fff} | {Message:lj}{NewLine}{Exception}"
	New-Logger |
		Add-EnrichWithEnvironment |
		Add-EnrichWithExceptionDetails |
		Set-MinimumLevel -Value Verbose |
		Add-SinkFile -Path $Path -OutputTemplate $LogEntryTemplate |
		Add-SinkConsole -OutputTemplate $LogEntryTemplate |
		Start-Logger

	# if Logiscend is a fresh server, it needs all users and parts created.
	if($ConfigureLogiscend)
	{
		New-LsVirtualDrivers
		$Add_LsDriversResponseList = Add-LsDrivers
		$DriverIDs = $Add_LsDriversResponseList.Content | ConvertFrom-Json -AsHashtable
		$SourceLocResponseObj = New-LsPartSourceLocation
		$PartSourceLocationIDs = $SourceLocResponseObj.id
		$DestinationResponseObj = New-LsPartDestinationLocation
		$LsPartPerSourceLocationReturnObj = New-LsPartPerSourceLocation
		$ThresholdResponse = New-LsThreshold -Name "Threshold" 
        $partIDs = $LsPartPerSourceLocationReturnObj.id
		$destIDs = $DestinationResponseObj.id
		$CallButtonReturn = New-LsCallButton $partIDs $destIDs
		[int]$ThresholdResponseId = ($ThresholdResponse.id.ToString())
		$NewCallButtonReturn = $CallButtonReturn | Group-Object -Property locationId
		$RouteResponseObj = New-LsRoute $DriverIDs
		$DriverIDs 	= ($DriverIDs).id
	   	$RouteNames = $RouteResponseObj.Name
		$RouteIDs   = $RouteResponseObj.id
		$RouteDescriptions  = $RouteResponseObj.Description	
		$LocationIDwithPartID = $NewCallButtonReturn | ForEach-Object { [PSCustomObject]@{locationId = $_.Name; callButtons = $_.Group} }
	 	New-LsWorkStation $LocationIDwithPartID $RouteNames $RouteIDs $DriverIDs $RouteDescriptions $ThresholdResponseId
	 	Read-Host -Prompt "Copy the GatewaySimConfig.json to the Gateway Sim Server, start the Gateway Simulator, then hit enter to continue."
	}
}

# Because Powershell isn't friendly about passing arrays into a script when 
# it's invoked with the -File parameter, we have to do some manual array creation. 
# Also, because the parameter names are human readable (and were intended to be of
# the correct array type) and were intended to be used in the script as-is, we 
# needed a variable to hold the arrays.
$R1 = [int[]]($Routes -split ',')    
$P1 = [int[]]($PartCounts -split ',')

$RouteConfig = Get-Content $Filename -Raw | ConvertFrom-Json
$Sequence = Get-Random

# Entry point for the script
Start-Script
Stop-Script -Message "Completed Normally"