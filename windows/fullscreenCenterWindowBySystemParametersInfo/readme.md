# Fullscreen Center Window by SystemParametersInfo

###### How to compile

-   First compile the resource file.

```
set root=%CD%
cd resources
rc.exe /V resource.rc
cd %root%
```

-   Now compile the program with resource file.

```
cl.exe /EHsc /DUNICODE /Zi fullscreenCenterWindowBySystemParametersInfo.cpp /link resources\resource.res user32.lib kernel32.lib gdi32.lib
```

###### Keyboard shortcuts

-   Press `Esc` key to quit.
-   Press `f` key to toggle fullscreen mode.

###### Preview

![fullscreenCenterWindowBySystemParametersInfo][fullscreencenterwindowbysystemparametersinfo-image]

[//]: # "Image declaration"
[fullscreencenterwindowbysystemparametersinfo-image]: ./preview/fullscreenCenterWindowBySystemParametersInfo.png "Fullscreen Center Window by SystemParametersInfo"
