#Prompt user for IP, user and domain to be used in remote connection        
Write-host "What is the " -NoNewLine ; Write-host -f green "IP adress / name" -NoNewLine ; Write-host " of the remote computer ?" 
$IP = read-host

Write-host "What is the " -NoNewLine ; Write-host -f green "User" -NoNewLine ; Write-host " name ?" 
$user = read-host

Write-host "What is the " -NoNewLine ; Write-host -f green "Domain" -NoNewLine ; Write-host " of the user ?" 
$dom = read-host

#Add the new session to a variable and attempts to connect to it 
try {
    $session = New-PSSession -ComputerName $IP -Credential $dom\$user
    Enter-PSSession $session
}
catch{
    Write-host -f red "Failed" -NoNewLine ; Write-host " to connect to $IP !" 
}