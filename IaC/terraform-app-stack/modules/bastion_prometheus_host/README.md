
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

--- How this actually works ---

Mesh, not hub-and-spoke: each tailnet device holds a direct WireGuard
tunnel to every other device it's authorized to reach (peer-to-peer where
possible, relayed through Tailscale's DERP servers otherwise). Tailscale's
coordination service (the thing behind the admin console) never sits in
the traffic path itself - it only hands each device its authorized peers'
current keys/addresses and enforces ACLs on who's allowed to try.

The auth key (--authkey) is how the bastion joins that mesh without a
browser login on a headless box. Ours is ephemeral + reusable: ephemeral
so the node auto-removes from the tailnet once it goes offline past a
grace period (no stale entries piling up every time the bastion gets
destroyed/recreated); reusable so the same key works across every fresh
instance instead of being burned after one join.

--advertise-routes=10.0.0.0/16 is what makes this a *subnet* router
instead of just another tailnet member - without it, peers could only
reach the bastion's own tailnet IP (100.x.x.x), not anything else in the
VPC. Still requires one-time approval per new node (step 1 below) unless
auto-approved via an ACL tag. --accept-routes=false is the flip side:
this box shouldn't consume routes advertised by other subnet routers
(there aren't any), only offer its own. --hostname=bastion-vpn is purely
cosmetic - without it the admin console shows the raw OS hostname instead.

No inbound security group rule is needed (unlike WireGuard's scoped
51820/udp rule) - the bastion connects outbound to Tailscale's
coordination service and NAT-traverses from there.

Routing into the VPC uses SNAT by default (Tailscale's
--snat-subnet-routes, on unless disabled) - traffic forwarded into
10.0.0.0/16 gets its source rewritten to the bastion's own private IP
before it leaves, the same way our old WireGuard MASQUERADE rule worked,
except Tailscale manages the NAT rule internally - nothing to write in
userdata. This is also why no VPC route table changes or
source_dest_check = false were needed, same reasoning as the old setup:
nothing else in the VPC ever tries to route through the bastion as a
next-hop, so AWS never needs to know the tailnet's 100.64.0.0/10 address
space exists at all.

Split-tunnel by default: your PC only routes tailnet peer IPs + approved
subnet routes through the tunnel - normal internet traffic is untouched.
Full-tunnel (route everything through the bastion) is a separate opt-in
feature (--advertise-exit-node server-side, --exit-node=bastion-vpn
client-side), not used here.

DNS is a separate concern from routing - reaching a private IP by routing
doesn't make hostnames resolve. internal.xxsapxx.local is a private
Route53 zone, only resolvable via the VPC's AmazonProvidedDNS resolver
(10.0.0.2). Split DNS (step 5 below) tells Tailscale to forward just
queries for that domain suffix to 10.0.0.2, leaving all other DNS lookups
on your normal resolver.

--- Setup ---

1) Approve the advertised route (one-time per new/recreated bastion, since
   the auth key is ephemeral and each fresh instance is a "new" node):  
   https://login.tailscale.com/admin/machines -> bastion-vpn -> Edit route settings -> enable 10.0.0.0/16

2) Install Tailscale on your PC and log in with the same account:  
   https://tailscale.com/download/windows

3) Verify the tunnel is up [PowerShell]:  
   tailscale status
   (bastion-vpn should show up, "idle" or with a recent handshake)

4) Verify VPC access through the tunnel by private IP first (internal.xxsapxx.local
   won't resolve until step 5):  
   ping <bastion-private-ip>

5) Configure Split DNS (one-time) so *.internal.xxsapxx.local resolves:  
   https://login.tailscale.com/admin/dns -> Add nameserver -> 10.0.0.2 -> Restrict to domain -> internal.xxsapxx.local  
   ping bastion.internal.xxsapxx.local
