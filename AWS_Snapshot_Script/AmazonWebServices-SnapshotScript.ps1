<#	
	.NOTES
	===========================================================================
	 Created on:   	4/11/2014 9:05 AM
	 Created by:   	Vitorrio Brooks
	 Organization: 	RightBrain Netowrks, LLC.
	 Filename:      AWSSnapshotScript.ps1
	 Additional Sources: Get-Ini Module by Microsoft
	===========================================================================
	.DESCRIPTION
		A snapshot backup script for EBS volumes
#>

#Aruments passed in from the console
#param([String]$path) #The path to the ini config file
Set-AWSCredentials -AccessKey xxxxxxxxx -SecretKey xxxxxxxxx
Set-DefaultAWSRegion us-east-1
Function global:Get-IniContent
{
    <# 
    .Synopsis 
        Gets the content of an INI file 
         
    .Description 
        Gets the content of an INI file and returns it as a hashtable 
         
    
    .Inputs 
        System.String 
         
    .Outputs 
        System.Collections.Hashtable 
         
    .Parameter FilePath 
        Specifies the path to the input file. 
         
    .Example 
        $FileContent = Get-IniContent "C:\myinifile.ini" 
        ----------- 
        Description 
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent 
     
    .Example 
        $inifilepath | $FileContent = Get-IniContent 
        ----------- 
        Description 
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent 
     
    .Example 
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini" 
        C:\PS>$FileContent["Section"]["Key"] 
        ----------- 
        Description 
        Returns the key "Key" of the section "Section" from the C:\settings.ini file 
         
    .Link 
        Out-IniFile 
    #>
	
	[CmdletBinding()]
	Param (
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ (Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini") })]
		[Parameter(ValueFromPipeline = $True, Mandatory = $True)]
		[string]$FilePath
	)
	
	Begin
	{ Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started" }
	
	Process
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"
		
		$ini = @{ }
		switch -regex -file $FilePath
		{
			"^\[(.+)\]$" # Section
			{
				$section = $matches[1]
				$ini[$section] = @{ }
				$CommentCount = 0
			}
			"^(;.*)$" # Comment
			{
				if (!($section))
				{
					$section = "No-Section"
					$ini[$section] = @{ }
				}
				$value = $matches[1]
				$CommentCount = $CommentCount + 1
				$name = "Comment" + $CommentCount
				$ini[$section][$name] = $value
			}
			"(.+?)=(.*)" # Key
			{
				if (!($section))
				{
					$section = "No-Section"
					$ini[$section] = @{ }
				}
				$name, $value = $matches[1..2]
				$ini[$section][$name] = $value
			}
		}
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $path"
		Return $ini
	}
	
	End
	{ Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended" }
}
$snapshot_queue = New-Object System.Collections.ArrayList
$include_queue = New-Object System.Collections.ArrayList #This is an array with a collection of volume-ids that matched the instance-ids in the [INCLUSIONS] section
$exclude_queue = New-Object System.Collections.ArrayList #This is an array with a collection of volume-ids that matched the instance-ids in the [EXCLUSIONS] section
$exclude_list = New-Object System.Collections.ArrayList
$path = "C:\Scripts\backup.ini"
$ConfigTable = Get-IniContent $path
echo "The content of the backup.ini file is as follows: " $ConfigTable 
$ServerList = $ConfigTable["SERVERS"]
$InclusionList = $ConfigTable["INCLUSIONS"]
$ExclusionList = $ConfigTable["EXCLUSIONS"]
$RotationList = $ConfigTable["ROTATION"]
################################################################################################################################################

#create initial list to hold the volumes to be snapshotted. Final list is $snapshot_queue #
$volume_list = New-Object System.Collections.ArrayList
$instance_list = New-Object System.Collections.ArrayList
$inst_to_volume_list = New-Object System.Collections.ArrayList


foreach ($t in $ServerList.values)
{
	$tag = $t.toString()
	#echo ""
	#echo "Tag: " + $tag
	$tag_to_instances = New-Object System.Collections.ArrayList
	$tag_to_instances = (Get-EC2Instance -Filter @{ Name = "tag-value"; Values = $tag.ToString() ; }).Instances.InstanceID
	foreach ($entry in $tag_to_instances)
	{
		
		$instance_id = $entry.toString()
		if ($instance_list.Contains($instance_id))
		{
			break
		}
		$instance_list.Add($instance_id)
	}
	}
	
	echo $tag
	echo "The list of instances being snapshotted is" $instance_list 
	foreach ($instance in $instance_list)
	{
		$instance = $instance.ToString()
		$inst_to_volume_list = ((Get-EC2Volume -Filter @{ Name = "attachment.instance-id"; Values = $instance.ToString(); }).VolumeId)
		foreach ($volume in $inst_to_volume_list)
		
	
		{
			$snapshot_queue.Add($volume)
		}
	
}




echo "The drives being snapshotted today, before adding the inclusion / exclusion list are: "
echo "-------------------------------------" 
echo $snapshot_queue 




#ADD INCLUSIONS TO LIST
foreach ($t in $InclusionList.Values)
{
	$tag = $t.toString()
	echo $tag
	$tag_to_instances = New-Object System.Collections.ArrayList
	$tag_to_instances = (Get-EC2Instance -Filter @{ Name = "tag-value"; Values = $tag.ToString(); }).Instances.InstanceID
	foreach ($entry in $tag_to_instances)
	{
		
		$instance_id = $entry.toString()
		if ($instance_list.Contains($instance_id))
		{
			break
		}
		$instance_list.Add($instance_id)
	}
}





foreach ($instance in $instance_list)
{
	$instance = $instance.ToString()
	$inst_to_volume_list = ((Get-EC2Volume -Filter @{ Name = "attachment.instance-id"; Values = $instance.ToString(); }).VolumeId)
	foreach ($volume in $inst_to_volume_list)
	{
		if ($snapshot_queue.Contains($volume)) {break }
		$snapshot_queue.Add($volume)
	}
	
}

echo "The contents of the inclusion list is as follows:  " 
echo $instance_list 

#REMOVE EXCLUSIONS
foreach ($t in $ExclusionList.Values)
{
	
	$tag = $t.toString()
	echo $tag
	$tag_to_instances = New-Object System.Collections.ArrayList
	$tag_to_instances = (Get-EC2Instance -Filter @{ Name = "tag-value"; Values = $tag.ToString(); }).Instances.InstanceID
	foreach ($entry in $tag_to_instances)
	{
		
		$instance_id = $entry.toString()
		if ($exclude_list.Contains($instance_id))
		{
			break
		}
		$exclude_list.Add($instance_id)
	}
}


foreach ($instance in $exclude_list)
{
	$instance = $instance.ToString()
	$inst_to_volume_list = ((Get-EC2Volume -Filter @{ Name = "attachment.instance-id"; Values = $instance.ToString(); }).VolumeId)
	foreach ($volume in $inst_to_volume_list)
	{
		$snapshot_queue.Remove($volume)
	}
	
}


echo "The contents of the exclusion list is as follows:  " 
echo $exclude_list



<#
***Snapshot***

Here we snapshot the drives that are in our list of drives, the snapshot_queue, to snapshot

***Snapshot***
#>
$today = Get-Date
foreach ($i in $snapshot_queue)
{
	#This date, the -eq 1, is where you decide which date is the start of the monthly backup
	if ($today.Day -eq 1)
	{
		$this_snapshot = New-EC2Snapshot -VolumeId $i
		sleep 1
		$new_tag = New-Object Amazon.EC2.Model.Tag
		$new_tag.Key = "Snap-Type"
		$new_tag.Value = "Monthly"
		New-EC2Tag -ResourceId $this_snapshot.SnapshotID -Tags $new_tag 
		
		#Now, name the snapshot.
		$object = Get-EC2Tag -Filter @{ Name = "resource-id"; Values = $i }
		for ($b = 0; $b -le $object.length; $b++)
		{
			if ($object.key[$b] -eq 'Name')
			{
				$object_name = $object.value[$b]
				$new_tag1 = New-Object Amazon.EC2.Model.Tag
				$new_tag1.Key = "Name"
				$new_tag1.Value = $object_name
				New-EC2Tag -ResourceId $this_snapshot.SnapshotID -Tags $new_tag1
			}
		}
		# Note that just above we are finding the 'name' tag of the volume 
		# and passing assigning it to the snapshot's 'name' tag. 
		
		
	}
	
	elseif ($today.DayOfWeek -eq 'Monday')
	{
		$this_snapshot = New-EC2Snapshot -VolumeId $i
		sleep 1
		$new_tag = New-Object Amazon.EC2.Model.Tag
		$new_tag.Key = "Snap-Type"
		$new_tag.Value = "Weekly"
		
		New-EC2Tag -ResourceId $this_snapshot.SnapshotID -Tags $new_tag
		
		#Now, name the snapshot.
		$object = Get-EC2Tag -Filter @{ Name = "resource-id"; Values = $i }
		for ($c = 0; $c -le $object.Length; $c++)
		{
			if ($object.key[$c] -eq 'Name')
			{
				$object_name = $object.value[$c]
				$new_tag1 = New-Object Amazon.EC2.Model.Tag
				$new_tag1.Key = "Name"
				$new_tag1.Value = $object_name
				New-EC2Tag -ResourceId $this_snapshot.SnapshotID -Tags $new_tag1
			}
		}
	}
	
	else
	{
		$this_snapshot = New-EC2Snapshot -VolumeId $i
		sleep 1
		$new_tag = New-Object Amazon.EC2.Model.Tag
		$new_tag.Key = "Snap-Type"
		$new_tag.Value = "Daily"
		
		New-EC2Tag -ResourceId $this_snapshot.SnapshotID -Tags $new_tag
		
		#And now name the snapshot.
		$object = Get-EC2Tag -Filter @{ Name = "resource-id"; Values = $i }
		for ($d = 0; $d -le $object.length; $d++)
		{
			#-if ($object.key[$d] -eq 'Name')
			if ($object.key -eq 'Name') #+
			{
				#-$object_name = $object.value[$d]
				$object_name = $object.value #+
				$new_tag1 = New-Object Amazon.EC2.Model.Tag
				$new_tag1.Key = "Name"
				$new_tag1.Value = $object_name
				New-EC2Tag -ResourceId $this_snapshot.SnapshotID -Tags $new_tag1
			}
		}
	}
}

#Output snapshot results to a log
$mydate = date
$snapshot_count = $snapshot_queue.Count
Add-Content -Value "On $mydate, there were $snapshot_count snapshots successfully started" -Path C:\Scripts\Logs\aws_snapshot.log

<#
***Delete Snapshots***

Here we are deleting snapshots that have "expired," based on the settings in the...
backup.ini file. 
#>

#Read the rotation settings from backup.ini [ROTATION] section.
$days_to_keep = ($RotationList.DAYS)
$weeks_to_keep = ($RotationList.WEEKS)
$months_to_keep = ($RotationList.MONTHS)

#Get a collection of all snapshots for account:
$removal_queue = New-Object System.Collections.ArrayList
$removal_queue = (Get-EC2Snapshot -ownerids "174198814254")
$ignore_queue = New-Object System.Collections.ArrayList


#Get today's date
$today = Get-Date

#Translate backup.ini file rotation entries to the number of days (type casting and 'day' conversion).
[int]$month_to_keep_int = $null
[int32]::TryParse($months_to_keep, [ref]$month_to_keep_int)
$month_threshold = $month_to_keep_int * 30

[int]$weeks_to_keep_int = $null
[int32]::TryParse($weeks_to_keep, [ref]$weeks_to_keep_int)
$week_threshold = $weeks_to_keep_int * 1

[int]$days_to_keep_int = $null
[int32]::TryParse($days_to_keep, [ref]$days_to_keep_int)
$day_threshold = $days_to_keep_int

<#
removal queue is a list of all snapshots. We iterate through the tags in the instances removing
any weekly or monthly snapshots whose dates have not passed the threshold listed in the .ini file. 
#>
echo "The list of snapshots we are removing today are: " 
echo $removal_queue
foreach ($i in $removal_queue)
{
	$snapid = $i.SnapshotID
	$this_snapshot = New-Object System.Collections.ArrayList
	$this_snapshot.Clear()
	$snap_date = (($i.StartTime).toString())
	$snap_date = ($snap_date.split())[0]
	$snapped_date = Get-Date $snap_date
	
	$this_snapshot = (Get-EC2Tag -Filters @{ Name = "resource-id"; Value = $snapid })
	if ($this_snapshot.value.contains("Weekly"))
	{
		if ($snapped_date -gt $today.AddDays(- $week_threshold))
		{
			$ignore_queue.Add($i.SnapshotID) 
			
		}
	}
	
	else
	{
		if ($this_snapshot.value.Contains("Monthly"))
		{
			if ($snapped_date -gt $today.AddDays(- $month_threshold))
			{
				$ignore_queue.Add($i.SnapshotID) 
				
			}
		}
	}
}


<#
We now remove all snapshots in the removal_queue based on the daily snapshot configuration in backup.ini, 
as the removal_queue no longer contains any weekly, or monthly snapshots that have not passed
their expiration point. 
#>



#here we are removin snapshots from the removal_queue,  if they are tagged with daily, weekly, or monthly.
foreach ($x in $removal_queue)
{
	$snapid = $x.SnapshotID
	$this_snapshot = New-Object System.Collections.ArrayList
	$this_snapshot.Clear()
	$snap_date = (($x.StartTime).toString())
	$snap_date = ($snap_date.split())[0]
	$snapped_date = Get-Date $snap_date
	
	$this_snapshot = (Get-EC2Tag -Filters @{ Name = "resource-id"; Value = $snapid })
	
	if ($this_snapshot.value.Contains("Daily"))
	{
		if ($snapped_date -gt $today.AddDays(- $day_threshold))
		{
			$ignore_queue.Add($x.SnapshotID)
			
		}
	}
	
	else
	{
		if ( $this_snapshot.value.Contains("Daily") -or $this_snapshot.value.Contains("Weekly") -or $this_snapshot.value.Contains("Monthly"))
		{
			
				echo "The snapshot must have contained one of the snap types" 
		}
		
		else 
		{
			$ignore_queue.Add($x.SnapshotID)
		}
	} # End else statement
	
	
	
}

#And finally we are removing all snapshots that should be removed.

[int]$remove = $null
[int32]::TryParse($removal_queue.length, [ref]$remove)

[int]$ignore = $null
[int32]::TryParse($ignore_queue.Count, [ref]$ignore)

$mydate = date
$final_removed = ($remove - $ignore)
Add-Content -Value "On $mydate ,There were $final_removed snapshots removed, as they had passed their expiration" -Path C:\Scripts\Logs\aws_snapshot.log
foreach ($y in $removal_queue)
{

		if ($ignore_queue.Contains($y.SnapshotID))
		{
			echo "The ignore queue contains snapshot " $y.SnapshotID "so we did not remove it" `n
		}
		else
		{
			Remove-EC2Snapshot -SnapshotId $y.SnapshotID -Force
		}
		
	}


