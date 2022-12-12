#make all errors terminating, so they are all caught by the try catch blocks
$ErrorActionPreference = "Stop"

#Functions
function InitInstall {
            #Install Active directory services as well as DHCP and DNS features
            Install-WindowsFeature AD-Domain-Services -IncludeManagementTools ; Install-WindowsFeature DHCP -IncludeManagementTools ; Install-WindowsFeature DNS -IncludeManagementTools
}

function Domains{
            Write-host @"
            1) Create a new forest and domain
            2) Create organizational units
"@
            [int]$re2 = $(Write-Host "Please, make a selection : " -ForegroundColor cyan -NoNewLine; Read-Host)
            switch ($re2) 
            {
                1 {
                    #Prompts user for low and top level domain names as well as NETBIOS name
                    Write-host "Name of the low level domain (" -NoNewLine ; Write-host -f green "domain" -NoNewLine ; Write-host ".exemple)"
                    $LLdom = read-host 
                    Write-host "Name of the top level domain (domain." -NoNewLine ; Write-host -f green "exemple" -NoNewLine ; Write-host ")"
                    $TLdom = read-host
                    $bname = read-host -prompt "Domain BIOS name"
                   
                    #Creation of forest and associated domain 
                    Install-ADDSForest -DomainName "$LLdom.$TLdom" -InstallDNS -DomainNetBiosName "$bname" 
                    Write-host "The domain " -NoNewLine ; Write-host -f green "$LLdom.$TLdom" -NoNewLine ; Write-host " has been successfully created !" 
                }

                2 {  
                   #Prompt user for domain name in which OU are to be created, and then the name of the OU
                   Write-host "Name of the low level domain (" -NoNewLine ; Write-host -f green "domain" -NoNewLine ; Write-host ".exemple)"
                   $LLdom = read-host 
                   Write-host "Name of the top level domain (domain." -NoNewLine ; Write-host -f green "exemple" -NoNewLine ; Write-host ")"
                   $TLdom = read-host
                   $OU = read-host -prompt "Name of the Company"
                   [int]$OUnb= read-host -prompt "How many sub OU to create" 
                    
                   #Create new OU based on the aformentionned info ( Only the main OU is protected from accidental deletion )
                   New-ADOrganizationalUnit -Name "$OU" -Path "DC=$LLdom,DC=$TLdom" -ProtectedFromAccidentalDeletion $True 
                   for ($i = 1; $i -le $OUnb; $i++) {$OUname = read-host -Prompt "Nom de l'OU numéro $i"; New-ADOrganizationalUnit -Name "$OUname"  -Path "OU=$OU,DC=$LLdom,DC=$TLdom" -ProtectedFromAccidentalDeletion $False } 

                   #Display all OU Names and Distinguished Names
                   Get-ADOrganizationalUnit -Filter 'Name -like "*"' | Format-Table Name, DistinguishedName -A 
                }
            }
}

function UserCreation{
            #Prompt user for amount of users to be created and their default password
            [int]$usernb = read-host -prompt "How many users would you like to create ?"
            $pass = read-host -prompt "Choose a COMPLEX default password "
            $pass2 = ConvertTo-SecureString -AsPlainText $pass -force
                
        	#Run the user creation loop for set amount of users chosen
            for ($i = 1; $i -le $usernb; $i++){
                try{
                    $username = read-host -Prompt "Nom de l'utilisateur $i"; New-ADuser -Name "$username" ; Set-ADaccountPassword -NewPassword $pass2 ; Write-host "User " -NoNewLine ; Write-host -f green "$username" -NoNewLine ; Write-host " has been successfully created !" 
                }
                catch{
                    Write-host -f red "$username " -NoNewLine ; Write-host "could not be created or already exists"
                }
            } 
}

function DHCP{
    		#Call domain and host names, and prompt user for DHCP server info
            $dom = Read-Host -prompt "Full domain Name"
            $hostn = Read-Host -prompt "Server Name"
            $ipdns = Read-Host -prompt "Server IP"
            $iprouteur = Read-Host -prompt "Router IP"
            $dhcpname = Read-Host -prompt "Name of the new scope"
            $minscope = Read-Host -prompt "First IP of the scope"
            $maxscope = Read-Host -prompt "End IP of the scope"
            $smask = Read-Host -prompt "subnet mask"
            Write-host "Installing the DHCP server " -NoNewLine ; Write-host -f green "$dhcpname.$dom" -NoNewLine ; Write-host "."
            try{
                #Create a new DHCP server and set it up with given info
                Add-DhcpServerInDC -DnsName $hostn.$dom -IPAddress 10.0.0.3
                Set-DhcpServerv4OptionValue -DNSServer $ipdns -DNSDomain $dom -Router $iprouteur
                Add-DhcpServerv4Scope -Name "$dhcpname" -StartRange $minscope -EndRange $maxscope -SubnetMask $smask
                Restart-Service dhcpserver

            }             
            catch{
                Write-host "Something went " -NoNewLine ; Write-host -f red "wrong" -NoNewLine ; Write-host "!"

            }
}

function Reset{
 Write-host @"
            1) Disable all users 
            2) Reset all passwords to default 
            3) Reveal default password
"@
            [int]$re5 = $(Write-Host "Please, make a selection : " -ForegroundColor cyan -NoNewLine; Read-Host)
            switch ($re5){

                  1 {
                    #Get all users in the Active Directory EXCEPT for sys accounts like admin
                    $users = (Get-ADUser -Filter * | Where-Object {$_.info -notmatch "System Account"})

                    #Loop through each user and disable them
                    foreach ($user in $users)
                    {
                        Disable-ADAccount -Identity $user
                    }
                    }
                  2 {
                    #Get all users EXCEPT for sys accounts like admin
                    $users = (Get-ADUser -Filter * | Where-Object {$_.info -notmatch "System Account"})

                    #Loop through each user
                    foreach ($user in $users)
                    {
                        #Reset user's password
                        Set-ADAccountPassword -Identity $user -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "P4ssword!" -Force) -PassThru
                    }
                    }
                  3 {
                    #Display the default password, very secure !
                    write-host -f cyan "The default password is " -NoNewline; write-host -f yellow "P4ssword!" -NoNewline; write-host -f cyan " ."
                    }
               }
}

function Tree{
            #Create parameters for the domain name and format the display of each OU discovered
            $get = {param([string]$path,[int]$indent = 2)
                $ous = Get-ADOrganizationalUnit -Filter * -Properties canonicalname -SearchBase $path -SearchScope OneLevel
                
                #Adds another indent for each child in each OU to create a tree structure
                foreach ($child in $ous) {
                  $tab = "-" * $indent
                  "|{0} {1}" -f $tab, $child.name
                  &$get -path $child.distinguishedname -indent ($indent+=2)
                  $indent-=2
                }
            }
            #Call the domain name and parse it to the scriptblock
            $curdom = (Get-ADDomain -Current LoggedOnUser).distinguishedname 
            (Get-ADDomain).Name;invoke-command $get -ArgumentList "$curdom"
}

function Export{
            #Prompt user for desired export name and process it to current working directory
            $path = (get-location).path
            $exportname = Read-Host "Name of export file "
            Get-ADUser -f * | convertto-csv | Out-file -FilePath "$path\$exportname.csv"
            Write-host "The export of " -NoNewLine ; Write-host -f green "$exportname" -NoNewLine ; Write-host " is successful !"
}

function Import{
            #Prompt user for name of the file to import and default password to be used for imported users
            Write-host "Name of the import file (" -NoNewLine ; Write-host -f green "file" -NoNewLine ; Write-host ".csv)" 
            $file = read-host
            $path = (get-location).path 
            $password = read-host -Prompt "Define a password"
           
            #Import file and loop on user creation for each instance in the file
            Import-Csv "~/$file.csv" -Delimiter ';' | ForEach-Object { 
            try{
                New-ADUser `
                -Name $_.Name `
                -Path "OU=users" `
                -SamAccountName $_.samAccountName `
                -UserPrincipalName ($_.samAccountName + '@' + $env:userdnsdomain) `
                -AccountPassword (ConvertTo-SecureString "$password" -AsPlainText -Force) 
                -Enabled $true `
                -ChangePasswordAtLogon $true
                Write-host "Import from " -NoNewLine ; Write-host -f green "$file" -NoNewLine ; Write-host " successful !"      
            }
            catch{
                Write-host "Something went " -NoNewLine ; Write-host -f red "wrong" -NoNewLine ; Write-host " during the import !"
            }
            }

}

#Menu
Write-host @"
1) Install AD, DHCP and DNS services
2) Create new domain & organizational units
3) Create users 
4) Add and enable new DHCP scope
5) Reset user passwords or disable accounts
6) Show full AD tree
7) Export AD users to csv file
8) Import AD users from csv file
9) Exit
"@

#Main script
do{
    [int]$rep = $(Write-Host "Please, make a selection : " -ForegroundColor cyan -NoNewLine; Read-Host)

    switch ($rep){
    1 { InitInstall }
    
    2 { Domains }
       
    3 { UserCreation }
   
    4 { DHCP }
    
    5 { Reset }

    6 { Tree }

    7 { Export }

    8 { Import }
    
    9 { Write-host -f magenta "Bye $env:UserName !" }
    }

}

#Loop through the main script after a function until the user chooses "exit"
until ($rep -ge '9')
