# Windows Build instructions
Follow this guide to build a windows installer of ShockAlarmApp


## Dependencies 
[Git](https://git-scm.com/downloads/win) or [Github Desktop](https://docs.github.com/en/desktop/installing-and-authenticating-to-github-desktop/installing-github-desktop?platform=windows) As long as you can run the command `git` in Powershell

[Visual Studio Community](https://visualstudio.microsoft.com/vs/community/)And install Desktop Development with C++

[InnoSetup](https://jrsoftware.org/isdl.php#stable)

[NuGet](https://dist.nuget.org/win-x86-commandline/latest/nuget.exe)

Flutter (will use git from before to install from this repo)

## Download targeted version

Open powershell and run
```Powershell
git clone https://github.com/ComputerElite/ShockAlarmApp.git --branch=<Tag (eg: 0.0.19)or main>
```
## Install NuGet
Save the exe from the above link somewhere it wont be deleted
then add it to your path in powershell
```Powershell
$env:Path +=";Drive:\path\to\nuget\folder" #this path change is temporay it will unset on exit of powershell
```

## Install Flutter
```Powershell
cd ShockAlarmApp\Flutter
git submodule update --init --recursive
$env:Path +=";$pwd\bin;$pwd\cache\dart-sdk\bin" #this path change is temporay it will unset on exit of powershell
flutter doctor
```
## Build ShockAlarmApp
```Powershell
cd ..
flutter pub get
flutter build windows
```

## Make the installer
```Powershell
'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' .\ShockAlarmSetup.iss 
```

There will be an OutPut folder with a ready to install exe waiting for you
