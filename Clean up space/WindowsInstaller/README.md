## Instructions

This is a couple of scripts I made because I was going to download patch cleaner but virus total said it was bad. So I decied to make my own. I've tested it and it works really nice.

Now for the C:\Windows\Installer folder, this is a bit dangerous so be careful to make sure everything the user needs is backed up to OneDrive. Also, you only want to remove **orphaned** installers.

I've made a script that will **move** them into the C:Temp folder and zip them that way you can restore if you want. 

Normally you would run the move script which would move the installers to the temp folder for a couple of days and you could see if any apps/updates break. If they don't then you can **delete** it from the temp folder.

If time is of the essence and they need space now let them know that there is a slight possibility that it could break app updates so have them report if anything acts funny and if anything breaks breaks you could do a reset since you have everything backed up to OneDrive.

Also WizTree is a good utility for finding what's taking up a bunch of space. I know the old version 4.14.0.0 works inside of backstage in ScreenConnect. Always make sure to run it through Virus total before you download anything.

https://diskanalyzer.com/wiztree-old-versions

https://www.virustotal.com/gui/home/upload
