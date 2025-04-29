# aops-telegraf-services
Mass import services to monitor on a running Telegraf Agent.

You can use this to import a .csv that contains a list of services and their respective display names, they will be added to an Aria Operations object running 'telegraf' for service monitoring.

An example would be an infrastructure VM that contained 15 windows services of various descriptions that needed all 15 services monitoring, this code will save you having to manually add all the 15 services to AriaOps objects.

You can use the supplied scripts_to_csv.ps1 to export a .csv of the running services on any VM you choose - then in turn, use this exported csv(edited to keep what you need monitoring) on the main script that talks to the Aria Ops API described above.
