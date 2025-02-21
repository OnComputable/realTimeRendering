#define _USE_MATH_DEFINES

#include <windows.h>
#include <cstdlib>
#include <math.h>
#include <gl/gl.h>
#include <gl/glu.h>

#include "resources/resource.h"

HWND hWnd = NULL;
HDC hdc = NULL;
HGLRC hrc = NULL;

DWORD dwStyle;
WINDOWPLACEMENT wpPrev = { sizeof(WINDOWPLACEMENT) };
RECT windowRect = {0, 0, 800, 600};

bool isFullscreen = false;
bool isActive = false;
bool isEscapeKeyPressed = false;

GLfloat widthByHeightRatio = 1.0f;
GLfloat heightByWidthRatio = 1.0f;

LRESULT CALLBACK WndProc(HWND hWnd, UINT iMessage, WPARAM wParam, LPARAM lParam);

void initialize(void);
void cleanUp(void);
void display(void);
void drawPatterns(void);
void drawDotPattern(void);
void drawBoxPattern(void);
void drawTrianglePattern(void);
void drawBoxTrianglePattern(void);
void drawLineRayPattern(void);
void drawColoredBoxPattern(void);
void resize(int width, int height);
void toggleFullscreen(HWND hWnd, bool isFullscreen);

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInsatnce, LPSTR lpszCmdLine, int nCmdShow)
{
    WNDCLASSEX wndClassEx;
    MSG message;
    TCHAR szApplicationTitle[] = TEXT("CG - Patterns");
    TCHAR szApplicationClassName[] = TEXT("RTR_OPENGL_PATTERNS");
    bool done = false;

    wndClassEx.cbSize = sizeof(WNDCLASSEX);
    wndClassEx.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wndClassEx.cbClsExtra = 0;
    wndClassEx.cbWndExtra = 0;
    wndClassEx.lpfnWndProc = WndProc;
    wndClassEx.hInstance = hInstance;
    wndClassEx.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(CP_ICON));
    wndClassEx.hIconSm = LoadIcon(hInstance, MAKEINTRESOURCE(CP_ICON_SMALL));
    wndClassEx.hCursor = LoadCursor(NULL, IDC_ARROW);
    wndClassEx.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wndClassEx.lpszClassName = szApplicationClassName;
    wndClassEx.lpszMenuName = NULL;

    if(!RegisterClassEx(&wndClassEx))
    {
        MessageBox(NULL, TEXT("Cannot register class."), TEXT("Error"), MB_OK | MB_ICONERROR);
        exit(EXIT_FAILURE);
    }

    DWORD styleExtra = WS_EX_APPWINDOW;
    dwStyle = WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_VISIBLE;

    hWnd = CreateWindowEx(styleExtra,
        szApplicationClassName,
        szApplicationTitle,
        dwStyle,
        windowRect.left,
        windowRect.top,
        windowRect.right - windowRect.left,
        windowRect.bottom - windowRect.top,
        NULL,
        NULL,
        hInstance,
        NULL);

    if(!hWnd)
    {
        MessageBox(NULL, TEXT("Cannot create windows."), TEXT("Error"), MB_OK | MB_ICONERROR);
        exit(EXIT_FAILURE);
    }

    initialize();

    ShowWindow(hWnd, nCmdShow);
    UpdateWindow(hWnd);
    SetForegroundWindow(hWnd);
    SetFocus(hWnd);

    while(!done)
    {
        if(PeekMessage(&message, NULL, 0, 0, PM_REMOVE))
        {
            if(message.message == WM_QUIT)
            {
                done = true;
            }
            else
            {
                TranslateMessage(&message);
                DispatchMessage(&message);
            }
        }
        else
        {
            if(isActive)
            {
                if(isEscapeKeyPressed)
                {
                    done = true;
                }
                else
                {
                    display();
                }
            }
        }
    }

    cleanUp();

    return (int)message.wParam;
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT iMessage, WPARAM wParam, LPARAM lParam)
{
    HDC hdc;
    RECT rect;

    switch(iMessage)
    {
        case WM_ACTIVATE:
            isActive = (HIWORD(wParam) == 0);
        break;

        case WM_SIZE:
            resize(LOWORD(lParam), HIWORD(lParam));
        break;

        case WM_KEYDOWN:
            switch(wParam)
            {
                case VK_ESCAPE:
                    isEscapeKeyPressed = true;
                break;

                // 0x46 is hex value for key 'F' or 'f'
                case 0x46:
                    isFullscreen = !isFullscreen;
                    toggleFullscreen(hWnd, isFullscreen);
                break;

                default:
                break;
            }

        break;

        case WM_LBUTTONDOWN:
        break;

        case WM_DESTROY:
            PostQuitMessage(0);
        break;

        default:
        break;
    }

    return DefWindowProc(hWnd, iMessage, wParam, lParam);
}

void initialize(void)
{
    PIXELFORMATDESCRIPTOR pfd;
    int pixelFormatIndex = 0;

    ZeroMemory(&pfd, sizeof(PIXELFORMATDESCRIPTOR));

    pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cRedBits = 8;
    pfd.cGreenBits = 8;
    pfd.cBlueBits = 8;
    pfd.cAlphaBits = 8;
    pfd.cDepthBits = 32;

    hdc = GetDC(hWnd);

    pixelFormatIndex = ChoosePixelFormat(hdc, &pfd);

    if(pixelFormatIndex == 0)
    {
        ReleaseDC(hWnd, hdc);
        hdc = NULL;
    }

    if(!SetPixelFormat(hdc, pixelFormatIndex, &pfd))
    {
        ReleaseDC(hWnd, hdc);
        hdc = NULL;
    }

    hrc = wglCreateContext(hdc);
    if(hrc == NULL)
    {
        ReleaseDC(hWnd, hdc);
        hdc = NULL;
    }

    if(!wglMakeCurrent(hdc, hrc))
    {
        wglDeleteContext(hrc);
        hrc = NULL;

        ReleaseDC(hWnd, hdc);
        hdc = NULL;
    }

    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

    // This is required for DirectX
    resize(windowRect.right - windowRect.left, windowRect.bottom - windowRect.top);
}

void display(void)
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glMatrixMode(GL_MODELVIEW);
    drawPatterns();
    SwapBuffers(hdc);
}

void drawPatterns(void)
{
    glLoadIdentity();
    glTranslatef(-40.0f * widthByHeightRatio, 20.0f * heightByWidthRatio, -6.0f);
    drawDotPattern();

    glLoadIdentity();
    glTranslatef(-8.5f * widthByHeightRatio, 20.0f * heightByWidthRatio, -6.0f);
    drawTrianglePattern();

    glLoadIdentity();
    glTranslatef(20.0f * widthByHeightRatio, 20.0f * heightByWidthRatio, -6.0f);
    drawBoxPattern();

    glLoadIdentity();
    glTranslatef(-8.5f * widthByHeightRatio, -40.0f * heightByWidthRatio, -6.0f);
    drawLineRayPattern();

    glLoadIdentity();
    glTranslatef(20.0f * widthByHeightRatio, -40.0f * heightByWidthRatio, -6.0f);
    drawColoredBoxPattern();

    glLoadIdentity();
    glTranslatef(20.0f * widthByHeightRatio, -40.0f * heightByWidthRatio, -6.0f);
    drawBoxPattern();

    glLoadIdentity();
    glTranslatef(-40.0f * widthByHeightRatio, -40.0f * heightByWidthRatio, -6.0f);
    drawBoxTrianglePattern();
}

void drawDotPattern(void)
{
    GLfloat difference = 25.0f / 3.0f;
    glPointSize(2.0f);
    glBegin(GL_POINTS);
    glColor3f(1.0f, 1.0f, 1.0f);

    for(int rowCounter = 0; rowCounter < 4; ++rowCounter)
    {
        for(int columnCounter = 0; columnCounter < 4; ++columnCounter)
        {
            glVertex3f(difference * rowCounter, difference * columnCounter, 0.0f);
        }
    }

    glEnd();
}

void drawBoxPattern(void)
{
    GLfloat difference = 25.0f / 3.0f;
    glBegin(GL_LINES);
    glColor3f(1.0f, 1.0f, 1.0f);

    for(int verticalLineCounter = 0; verticalLineCounter < 4; ++verticalLineCounter)
    {
        glVertex3f(difference * verticalLineCounter, 0.0f, 0.0f);
        glVertex3f(difference * verticalLineCounter, difference * 3.0f, 0.0f);
    }

    for(int horizontalLineCounter = 0; horizontalLineCounter < 4; ++horizontalLineCounter)
    {
        glVertex3f(0.0f, difference * horizontalLineCounter, 0.0f);
        glVertex3f(difference * 3.0f, difference * horizontalLineCounter, 0.0f);
    }

    glEnd();
}

void drawTrianglePattern(void)
{
    GLfloat difference = 25.0f / 3.0f;

    for(int rowCounter = 0; rowCounter < 3; ++rowCounter)
    {
        for(int columnCounter = 0; columnCounter < 3; ++columnCounter)
        {
            glBegin(GL_LINE_LOOP);
            glColor3f(1.0f, 1.0f, 1.0f);
            glVertex3f(difference * (0.0f + rowCounter), difference * (0.0f + columnCounter), 0.0f);
            glVertex3f(difference * (0.0f + rowCounter), difference * (1.0f + columnCounter), 0.0f);
            glVertex3f(difference * (1.0f + rowCounter), difference * (1.0f + columnCounter), 0.0f);
            glEnd();
        }
    }
}

void drawBoxTrianglePattern(void)
{
    GLfloat difference = 25.0f / 3.0f;
    for(int rowCounter = 0; rowCounter < 3; ++rowCounter)
    {
        for(int columnCounter = 0; columnCounter < 3; ++columnCounter)
        {
            glBegin(GL_LINE_LOOP);
            glColor3f(1.0f, 1.0f, 1.0f);
            glVertex3f(difference * (0.0f + rowCounter), difference * (0.0f + columnCounter), 0.0f);
            glVertex3f(difference * (0.0f + rowCounter), difference * (1.0f + columnCounter), 0.0f);
            glVertex3f(difference * (1.0f + rowCounter), difference * (1.0f + columnCounter), 0.0f);
            glVertex3f(difference * (1.0f + rowCounter), difference * (0.0f + columnCounter), 0.0f);
            glEnd();

            glBegin(GL_LINES);
            glColor3f(1.0f, 1.0f, 1.0f);
            glVertex3f(difference * (0.0f + rowCounter), difference * (0.0f + columnCounter), 0.0f);
            glVertex3f(difference * (1.0f + rowCounter), difference * (1.0f + columnCounter), 0.0f);
            glEnd();
        }
    }
}

void drawLineRayPattern(void)
{
    GLfloat difference = 25.0f / 3.0f;

    glBegin(GL_LINE_LOOP);

    glColor3f(1.0f, 1.0f, 1.0f);
    glVertex3f(25.0f, 25.0f, 0.0f);
    glVertex3f(0.0f, 25.0f, 0.0f);
    glVertex3f(0.0f, 0.0f, 0.0f);
    glVertex3f(25.0f, 0.0f, 0.0f);

    glEnd();

    glBegin(GL_LINES);

    glVertex3f(0.0f, 25.0f, 0.0f);
    glVertex3f(difference * 1.0f, 0.0f, 0.0f);

    glVertex3f(0.0f, 25.0f, 0.0f);
    glVertex3f(difference * 2.0f, 0.0f, 0.0f);

    glVertex3f(0.0f, 25.0f, 0.0f);
    glVertex3f(difference * 3.0f, 0.0f, 0.0f);

    glVertex3f(0.0f, 25.0f, 0.0f);
    glVertex3f(difference * 3.0f, difference * 2.0f, 0.0f);

    glVertex3f(0.0f, 25.0f, 0.0f);
    glVertex3f(difference * 3.0f, difference * 1.0f, 0.0f);

    glEnd();
}

void drawColoredBoxPattern(void)
{
    GLfloat difference = 25.0f / 3.0f;

    for(int rowCounter = 0; rowCounter < 3; ++rowCounter)
    {
        for(int columnCounter = 0; columnCounter < 3; ++columnCounter)
        {
            glBegin(GL_QUADS);
            if(columnCounter == 0)
            {
                glColor3f(1.0f, 0.0f, 0.0f);
            }

            if(columnCounter == 1)
            {
                glColor3f(0.0f, 1.0f, 0.0f);
            }

            if(columnCounter == 2)
            {
                glColor3f(0.0f, 0.0f, 1.0f);
            }

            glVertex3f(difference * (0.0f + columnCounter), difference * (0.0f + rowCounter), 0.0f);
            glVertex3f(difference * (0.0f + columnCounter), difference * (1.0f + rowCounter), 0.0f);
            glVertex3f(difference * (1.0f + columnCounter), difference * (1.0f + rowCounter), 0.0f);
            glVertex3f(difference * (1.0f + columnCounter), difference * (0.0f + rowCounter), 0.0f);
            glEnd();
        }
    }
}

void resize(int width, int height)
{
    if(height == 0)
    {
        height = 1;
    }

    if(width == 0)
    {
        width = 1;
    }

    windowRect.right = windowRect.left + width;
    windowRect.bottom = windowRect.top + height;

    glViewport(0, 0, (GLsizei)width, (GLsizei)height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();

    widthByHeightRatio = 1.0f;
    heightByWidthRatio = 1.0f;

    if(width <= height)
    {
        heightByWidthRatio = (GLfloat)height / (GLfloat)width;
        glOrtho(-50.0f, 50.0f, -50.0f * heightByWidthRatio, 50.0f * heightByWidthRatio, -50.0f, 50.0f);
    }
    else
    {
        widthByHeightRatio = (GLfloat)width / (GLfloat)height;
        glOrtho(-50.0f * widthByHeightRatio, 50.0f * widthByHeightRatio, -50.0f, 50.0f, -50.0f, 50.0f);
    }
}

void toggleFullscreen(HWND hWnd, bool isFullscreen)
{
    MONITORINFO monitorInfo;
    dwStyle = GetWindowLong(hWnd, GWL_STYLE);

    if(isFullscreen)
    {
        if(dwStyle & WS_OVERLAPPEDWINDOW)
        {
            monitorInfo = { sizeof(MONITORINFO) };

            if(GetWindowPlacement(hWnd, &wpPrev) && GetMonitorInfo(MonitorFromWindow(hWnd, MONITORINFOF_PRIMARY), &monitorInfo))
            {
                SetWindowLong(hWnd, GWL_STYLE, dwStyle & ~WS_OVERLAPPEDWINDOW);
                SetWindowPos(hWnd, HWND_TOP, monitorInfo.rcMonitor.left, monitorInfo.rcMonitor.top, monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left, monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top, SWP_NOZORDER | SWP_FRAMECHANGED);
            }
        }

        ShowCursor(FALSE);
    }
    else
    {
        SetWindowLong(hWnd, GWL_STYLE, dwStyle | WS_OVERLAPPEDWINDOW);
        SetWindowPlacement(hWnd, &wpPrev);
        SetWindowPos(hWnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_FRAMECHANGED);
        ShowCursor(TRUE);
    }
}

void cleanUp(void)
{
    if(isFullscreen)
    {
        dwStyle = GetWindowLong(hWnd, GWL_STYLE);
        SetWindowLong(hWnd, GWL_STYLE, dwStyle | WS_OVERLAPPEDWINDOW);
        SetWindowPlacement(hWnd, &wpPrev);
        SetWindowPos(hWnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_FRAMECHANGED);
        ShowCursor(TRUE);
    }

    wglMakeCurrent(NULL, NULL);

    wglDeleteContext(hrc);
    hrc = NULL;

    ReleaseDC(hWnd, hdc);
    hdc = NULL;

    DestroyWindow(hWnd);
    hWnd = NULL;
}
