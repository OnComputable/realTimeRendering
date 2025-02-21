# Pyramid and Cube Rotation

###### How to compile

-   First compile the resource file.

```
set root=%CD%
cd resources
rc.exe /V resource.rc
cd %root%
```

-   Now compile the program with resource file

```
cl.exe /EHsc /DUNICODE /Zi pyramidAndCubeRotation.cpp /link resources\resource.res user32.lib kernel32.lib gdi32.lib d3d11.lib D3dcompiler.lib
```

###### Keyboard shortcuts

-   Press `Esc` key to quit.
-   Press `f` key to toggle fullscreen mode.
-   Press `1` to `9` key to increase the rotation speed.

###### Preview

-   Pyramid and Cube Rotation

    ![pyramidAndCubeRotation][pyramid-and-cube-rotation-image]

[//]: # "Image declaration"
[pyramid-and-cube-rotation-image]: ./preview/pyramidAndCubeRotation.png "Pyramid and Cube Rotation Rotation"
