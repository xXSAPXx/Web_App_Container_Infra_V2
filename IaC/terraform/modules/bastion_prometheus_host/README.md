
Replace `<BASTION_PUBLIC_IP>` below with `terraform output bastion_host_public_ip`
(no Elastic IP is attached, so this changes on every apply/recreate).

##### CREATE A VALID KEY FOR THE SSH CONNECTION #####

 1) HAVE THE PRIVATE SSH KEYPAIR:

 2) CONVERT TO OpenSSH NORMAL FORMAT:
 
 3) Change SSH KEY PERMISISONS [Windows_11] [PowerShell]:

---------------------------------------------------------------------------------------------

$path = "C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env"

$acl = Get-Acl $path
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Users", "FullControl", "Allow"
)
$acl.RemoveAccessRule($rule)  
Set-Acl $path $acl  

$acl = Get-Acl $path
$acl.SetAccessRuleProtection($True, $False)  # Protect the file from inheritance
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "simeo", "FullControl", "Allow"
)
$acl.AddAccessRule($rule)  
Set-Acl $path $acl  

---------------------------------------------------------------------------------------------


##### Connect to Bastion_Host (SSH Agent Forwarding) [PowerShell] #####

4) Check correct file permissions:  
Get-Acl C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env | Format-List  

5) Add key to ssh-agent with PowerShell:  
ssh-add C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env  

6) Check if key is imported correctly in PowerShell:  
ssh-add -L  

7) Connect to Bastion_Host in PowerShell:  
ssh -A -i C:\Users\simeo\Desktop\IT_General\KeyPairs\Test_env ec2-user@<BASTION_PUBLIC_IP>  

8) Check if key is correctly forwarded to the Bastion_Host:  
ssh-add -L  

9) Connect to servers in the private subnets using bastion ec2-user:  
ssh ec2-user@ip-10-0-0-42.ec2.internal  


##### Connect to Bastion_Host (SSH Agent Forwarding) [GitBash] #####

4) Check correct file permissions:  
ls -l /c/Users/simeo/Desktop/IT_General/KeyPairs/Test_env

5) Add key to ssh-agent with PowerShell:  
eval "$(ssh-agent -s)"
ssh-add /c/Users/simeo/Desktop/IT_General/KeyPairs/Test_env

6) Check if key is imported correctly in PowerShell:  
ssh-add -L

7) Connect to Bastion_Host in PowerShell:  
ssh -A -i /c/Users/simeo/Desktop/IT_General/KeyPairs/Test_env ec2-user@<BASTION_PUBLIC_IP>

8) Check if key is correctly forwarded to the Bastion_Host:  
 ssh-add -L

9) Connect to servers in the private subnets using bastion ec2-user:  
ssh ec2-user@ip-10-0-0-42.ec2.internal


##### Tailscale VPN - private access into the VPC (Grafana, etc.) #####

The bastion joins the tailnet automatically on first boot (userdata) as a
subnet router advertising 10.0.0.0/16 - nothing to generate or copy off the
box, unlike the raw WireGuard version this replaced.

1) Approve the advertised route (one-time per new/recreated bastion, since
   the auth key is ephemeral and each fresh instance is a "new" node):  
   https://login.tailscale.com/admin/machines -> bastion-vpn -> Edit route settings -> enable 10.0.0.0/16

2) Install Tailscale on your PC and log in with the same account:  
   https://tailscale.com/download/windows

3) Verify the tunnel is up [PowerShell]:  
   tailscale status
   (bastion-vpn should show up, "idle" or with a recent handshake)

4) Verify VPC access through the tunnel, e.g. the private Route53 zone:  
   ping bastion.internal.xxsapxx.local

Note: internal.xxsapxx.local won't resolve until Split DNS is configured
once in the admin console (Settings -> DNS -> Add nameserver, restrict to
that domain, pointed at 10.0.0.2 - the VPC's AmazonProvidedDNS resolver).
Until then, reach services by private IP instead of hostname.
