### Orphan Public IP Report Script.ps1

#### Script Description:
This script will generate the report of all the Orphan Public Ip's
- It'll iterate through each subscriptions and fetch the Network Interface Cards. It will check if the NIC is attached to any VM or not.
If the NIC is not attached to any VM then it will fetch the public IP and remove the Public IP from NIC configuration. Then finally it deletes the Public IP if passed parameter conatins "yes"
- Send grid has been used to send an email to the recipients with CSV report as an attachment in the mail.


#### Inputs:
For Local Execution:
- DeleteIP : This is an optional parameter default value is "no" and it only generates the report of Orphan Public Ip's. Pass value as "yes" if deletion of Orphan Public IP is also required.

#### Output:
On Completion of the script execution, Recipient will receive the Orphan Public IP report CSV file as an attachment monthly.
Output generated is csv file with set of attributes defined below. The data will be generated for all subscriptions on which the account executing has access:
- SubscriptionName
- ResourceGroupName	
- PublicIPName	
- Deleted