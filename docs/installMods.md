A video explanation is available at https://youtu.be/_SA1UeLwnSE

# How to install a mod

Panel Attack mods come in various shapes and forms.  
The traditional mods based on image and sound assets consist of the theme, characters, stages and panels.  
But there are other files you can "install" in effectively the same way so they become available in Panel Attack:
Puzzles, training mode files and replays.

## Step 1: Find your Panel Attack user data folder 

Panel Attack saves most of its data in (somewhat hidden) user data folder so that multiple users of the same PC don't interfere with each other.  
Depending on your operating system the location is different.  
You can always find out about the save location by going to Options -> About -> System Info 

### Windows

Press the Windows key then type "%appdata%" without quotes and hit enter.  
or  
Open the Windows explorer and change the explorer settings to show hidden files and directory (normally found under "View")  
After that you can find a directory "AppData" in your user directory (normally located at C:\Users\yourUserName).   
This folder will contain a directory called "Roaming" that holds application data for many applications.  
  
Regardless of which method you used, you should be able to find a Panel Attack directory in that location if you ever started Panel Attack before.

### MacOS

In your Finder, navigate to  
  /Users/user/Library/Application Support/Panel Attack

### Linux

Depending on whether your $XDG_DATA_HOME environment variable is set or not, the Panel Attack folder will be located in either  
  $XDG_DATA_HOME/love/  
  or  
  ~/.local/share/love/  

Note that running a panel.exe through wine and running a panel.love through a native love installation on the same machine may result in different save locations.

### Android

Navigate to  
  /Android/data/com.panelattack.android/files/save/

The exact path for Android may differ, check in Options -> About -> System Info for the exact path.  

Depending on your Android and file browser you may not be able to view these files on your phone.  
It is generally recommended to connect Android devices to PC and use the file browser access from there.

## Step 2: Unpacking your mod and understanding where it belongs

### Unpacking a package

This guide cannot know which exact mode you are trying to install but it is going to assume the "worst" case:  
You are trying to install a big package with a theme, various characters, stages, panels and maybe even puzzles.

Normally you will download such packs in a zip file and your first task is to unpack it.  
Inside you may find one or multiple folders. A good mod package will mimic the folder structure inside the Panel Attack directory, meaning you will at one point hopefully encounter a directory that contains one or multiple folders of these:
  - characters
  - panels
  - puzzles
  - replays (very uncommon but possible)
  - stages
  - themes
  - training

Inside of each of these folders you will find the mod folders that need to be in the directory with the same name inside the Panel Attack folder.  
Once you copied everything into its correct subfolder, you will have to restart Panel Attack in order for your new mods to show up!

### Unpacking a single mod

For reference, still read the part about packages above.  
The way in which single mods are different is that they may not follow the folder structure above but instead you have to know based on where you got the link from what kind of mod it is.  
For single file mods (puzzles, training files, replays), you can just directly drop them into the respective folder.  
For asset type mods (characters, panels, stages, themes), make sure the folder you're copying directly contains the files for the mod and not another subfolder.  
Once you copied the mod into its correct subfolder, you will have to restart Panel Attack in order for your new mods to show up!


# How to manage your installed mods

If you don't want to use an installed mod anymore you have two options:  
  1. You can straight up delete its folder/files.
  2. You can disable the mod.

## Disabling mods

Panel Attack uses a universal convention:  
Directories and files that start with two underscores (__) will be ignored.  

So all you need to do to disable a character or stage is to rename its folder.  
You can also hide single replay, puzzle and training files by renaming them and adding __ in front.

Alternatively, Panel Attack offers an option to disable characters or stages via an options menu.  
This will add them to a blacklist that keeps them from being loaded but you can enable them again later on.  
Directories prefixed with __ do not show up in this menu