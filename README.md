# Introduction 
This is a simple tool used to display a customized notification which can be used during SCCM deployments. It displays a timer after which it will automatically continues to the next step.
This tool can be used with package, application or task sequences deployments in SCCM
For task sequences ServiceUI.exe must be used to display the GUI in interactive model as task sequences run under system content. 

# Getting Started
This tool is written in Powershell using WPF and Mahapps framework.

It allows you to do the below:
1. Windows Process Check - The script checks if there any Windows processes running that are defined in the ProcessList.txt. It allows to force close these applications or lets you close manually and proceed.
If no processes are defined in the ProcessList.txt, it just proceeds.
2. Display timer - This is the countdown timer which is shown in the GUI after which the application exits
3. Check if a user is logged in - If no user is logged, the form with the timer is not displayed and continues to the next step. 
4. Customize text and timer - All the text customization can be done within the Display-Notification.xaml without needing to make changes to the script. It allows formatting the text like Italics, Bold etc.
You can check WPF TextBlock for customizing text. 
The timer can be customized using a command line parameter. 
5. Supports themes - The script uses Mahapps which is highly cutomizable WPF framework. 
Refer to https://mahapps.com/guides/styles.html for the themes and colors supported. 

The script supports the below parameters
1. TimerDuration = In minutes
2. LogFile = If no file name is proivded, by default it is created scripts directory

Light theme           |  Dark theme (process running)
:-------------------------:|:-------------------------:
![image](https://user-images.githubusercontent.com/49522841/55958116-750cc180-5c9a-11e9-94c5-93db2a849bb2.png) | ![image](https://user-images.githubusercontent.com/49522841/55958285-d6349500-5c9a-11e9-8209-7bf88bd585ce.png)
