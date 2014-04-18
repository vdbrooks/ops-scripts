ops-scripts
===========

Amazon Web Services Snapshot Rotation Script For Powershell:
  
  Description:
  ------------
  
    Powershell script to automate daily, weekly, monthly snapshots and their rotation. An .ini file is currently used
    for the configuration file. The script reads a list of server names from a backup.ini file, translates the names
    to instance ids, pulls all the volumes that belong to an instance-id, and snapshots them, according to settings
    in the configuration file. The script will also tag each snapshot as daily, weekly, or monthly, and will auto-name
    the snapshots after the 'Name' tag currently on the volume
    
  ## Usage:
  
    # backup.ini:
    
      + [SERVERS] section is where you enter a list of server names ('Name' tag on instance) that you want to incude
      in the daily, weekly, monthly rotation schedule. 
      
      + [ROTATION] section is where you determine how long you want to keep any snapshot. How many days, weeks, months
      do you want to keep your daily, weekly, and monthly snapshots
      
      + [INCLUSIONS] section is for temporarily adding servers you want to include in the snapshot rotation
      
      + [EXCLUSIONS] section is for temporarily adding servers you want to exclude from the snapshot rotation
      
    # AmazonWebServices-SnapshotScript.ps1
    
      + $path variable is the path to your backup.ini configuration file
      
      + note: Snapshots that are not tagged with daily, weekly, or monthly (i.e., any snapshot that is not created
      by the script, will be left alone. 
      
    # Planned:
    
        + Change configuration file from INI to YAML.
        
        + Autoname snapshots with no name (i.e., your volume has no name, so your snapshot has no name). 
        
    ## Contributing:

      Fork it
      Create your feature branch (git checkout -b my-new-feature)
      Commit your changes (git commit -am 'Added some feature')
      Push to the branch (git push origin my-new-feature)
      Create new Pull Request
    
## Make IIS Website Provision Script For Powershell:

  ### Description:
  
    Powershell script to automate creation of any running IIS site. Includes creating sites, setting bindings,
    settings options, and deploying code. 
               
