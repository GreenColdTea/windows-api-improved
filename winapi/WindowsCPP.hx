package winapi;

/**
 * More than 600 lines of almost pure C++ code :3 
 * 
 * Author: Slushi
 * Modifier: JustX
 */

#if windows
@:buildXml('
<compilerflag value="/DelayLoad:ComCtl32.dll"/>

<target id="haxe">
    <lib name="dwmapi.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
    <lib name="gdi32.lib" if="windows" />
</target>
')
@:cppFileCode('
#include <Windows.h>
#include <windowsx.h>
#include <cstdio>
#include <iostream>
#include <tchar.h>
#include <dwmapi.h>
#include <winuser.h>
#include <winternl.h>
#include <Shlobj.h>
#include <commctrl.h>
#include <string>

#include <chrono>
#include <thread>

#define UNICODE

#pragma comment(lib, "Dwmapi")
#pragma comment(lib, "ntdll.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "Shell32.lib")
#pragma comment(lib, "gdi32.lib")

std::string globalWindowTitle = "Not Set";
HWND GET_MAIN_WINDOW() {
	HWND hwnd = GetForegroundWindow();
    char windowTitle[256];

    GetWindowTextA(hwnd, windowTitle, sizeof(windowTitle));

    if (globalWindowTitle == windowTitle) {
        return hwnd;
    }

    return FindWindowA(NULL, globalWindowTitle.c_str());
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

BOOL SaveToFile(HBITMAP hBitmap3, LPCTSTR lpszFileName)
{   
	HDC hDC;
	int iBits;
	WORD wBitCount;
	DWORD dwPaletteSize=0, dwBmBitsSize=0, dwDIBSize=0, dwWritten=0;
	BITMAP Bitmap0;
	BITMAPFILEHEADER bmfHdr;
	BITMAPINFOHEADER bi;
	LPBITMAPINFOHEADER lpbi;
	HANDLE fh, hDib, hPal,hOldPal2=NULL;
	hDC = CreateDC("DISPLAY", NULL, NULL, NULL);
	iBits = GetDeviceCaps(hDC, BITSPIXEL) * GetDeviceCaps(hDC, PLANES);
	DeleteDC(hDC);
	if (iBits <= 1)
		wBitCount = 1;
	else if (iBits <= 4)
		wBitCount = 4;
	else if (iBits <= 8)
		wBitCount = 8;
	else
		wBitCount = 24; 
	GetObject(hBitmap3, sizeof(Bitmap0), (LPSTR)&Bitmap0);
	bi.biSize = sizeof(BITMAPINFOHEADER);
	bi.biWidth = Bitmap0.bmWidth;
	bi.biHeight =-Bitmap0.bmHeight;
	bi.biPlanes = 1;
	bi.biBitCount = wBitCount;
	bi.biCompression = BI_RGB;
	bi.biSizeImage = 0;
	bi.biXPelsPerMeter = 0;
	bi.biYPelsPerMeter = 0;
	bi.biClrImportant = 0;
	bi.biClrUsed = 256;
	dwBmBitsSize = ((Bitmap0.bmWidth * wBitCount +31) & ~31) /8
													* Bitmap0.bmHeight; 
	hDib = GlobalAlloc(GHND,dwBmBitsSize + dwPaletteSize + sizeof(BITMAPINFOHEADER));
	lpbi = (LPBITMAPINFOHEADER)GlobalLock(hDib);
	*lpbi = bi;

	hPal = GetStockObject(DEFAULT_PALETTE);
	if (hPal)
	{ 
		hDC = GetDC(NULL);
		hOldPal2 = SelectPalette(hDC, (HPALETTE)hPal, FALSE);
		RealizePalette(hDC);
	}


	GetDIBits(hDC, hBitmap3, 0, (UINT) Bitmap0.bmHeight, (LPSTR)lpbi + sizeof(BITMAPINFOHEADER) 
		+dwPaletteSize, (BITMAPINFO *)lpbi, DIB_RGB_COLORS);

	if (hOldPal2)
	{
		SelectPalette(hDC, (HPALETTE)hOldPal2, TRUE);
		RealizePalette(hDC);
		ReleaseDC(NULL, hDC);
	}

	fh = CreateFile(lpszFileName, GENERIC_WRITE,0, NULL, CREATE_ALWAYS, 
		FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL); 

	if (fh == INVALID_HANDLE_VALUE)
		return FALSE; 

	bmfHdr.bfType = 0x4D42; // "BM"
	dwDIBSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + dwPaletteSize + dwBmBitsSize;
	bmfHdr.bfSize = dwDIBSize;
	bmfHdr.bfReserved1 = 0;
	bmfHdr.bfReserved2 = 0;
	bmfHdr.bfOffBits = (DWORD)sizeof(BITMAPFILEHEADER) + (DWORD)sizeof(BITMAPINFOHEADER) + dwPaletteSize;

	WriteFile(fh, (LPSTR)&bmfHdr, sizeof(BITMAPFILEHEADER), &dwWritten, NULL);

	WriteFile(fh, (LPSTR)lpbi, dwDIBSize, &dwWritten, NULL);
	GlobalUnlock(hDib);
	GlobalFree(hDib);
	CloseHandle(fh);

	return TRUE;
} 

int screenCapture(int x, int y, int w, int h, LPCSTR fname)
{
    HDC hdcSource = GetDC(NULL);
    HDC hdcMemory = CreateCompatibleDC(hdcSource);

    int capX = GetDeviceCaps(hdcSource, HORZRES);
    int capY = GetDeviceCaps(hdcSource, VERTRES);

    HBITMAP hBitmap = CreateCompatibleBitmap(hdcSource, w, h);
    HBITMAP hBitmapOld = (HBITMAP)SelectObject(hdcMemory, hBitmap);

    BitBlt(hdcMemory, 0, 0, w, h, hdcSource, x, y, SRCCOPY);
    hBitmap = (HBITMAP)SelectObject(hdcMemory, hBitmapOld);

    DeleteDC(hdcSource);
    DeleteDC(hdcMemory);

    HPALETTE hpal = NULL;
    if(SaveToFile(hBitmap, fname)) return 1;
    return 0;
}

//////////////////////////////////////////////////////////////////////////////////////
')
class WindowsCPP
{
	@:functionCode('
		MessageBox(GetActiveWindow(), message, caption, icon | type);
	')
	public static function showMessageBox(caption:String, message:String, icon:WindowsAPI.MessageBoxIcon = MSG_WARNING, type:WindowsAPI.MessageBoxType = MSG_OK)
	{
	}

    @:functionCode('
		// convert UTF-8 strings to wide strings (wchar_t)
		int captionLen = MultiByteToWideChar(CP_UTF8, 0, caption, -1, NULL, 0);
		wchar_t* wCaption = (wchar_t*)malloc(captionLen * sizeof(wchar_t));
		MultiByteToWideChar(CP_UTF8, 0, caption, -1, wCaption, captionLen);

		int messageLen = MultiByteToWideChar(CP_UTF8, 0, message, -1, NULL, 0);
		wchar_t* wMessage = (wchar_t*)malloc(messageLen * sizeof(wchar_t));
		MultiByteToWideChar(CP_UTF8, 0, message, -1, wMessage, messageLen);

		// Replace all single \\n with \\r\\n in wide string
		int newLen = messageLen * 2; // Maximum possible length after replacement
		wchar_t* formattedMessage = (wchar_t*)malloc(newLen * sizeof(wchar_t));
		int j = 0;
		
		for (int i = 0; i < messageLen && wMessage[i] != L\'\\0\'; i++) {
			if (wMessage[i] == L\'\\n\' && (i == 0 || wMessage[i-1] != L\'\\r\')) {
				formattedMessage[j++] = L\'\\r\';
				formattedMessage[j++] = L\'\\n\';
			} else {
				formattedMessage[j++] = wMessage[i];
			}
		}
		formattedMessage[j] = L\'\\0\';

		HWND hwnd = GetActiveWindow();
		
		const wchar_t* className = L"ScrollableMessageClass";
		
		// define window procedure w/ button handling
		WNDPROC windowProc = [](HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) -> LRESULT {
			switch (uMsg) {
				case WM_CLOSE:
					DestroyWindow(hwnd);
					return 0;
				case WM_DESTROY:
					PostQuitMessage(0);
					return 0;
				case WM_COMMAND:
					if (LOWORD(wParam) == 1) { // button ID
						DestroyWindow(hwnd);
						return 0;
					}
					break;
				case WM_NCHITTEST: 
				{
					LRESULT hit = DefWindowProcW(hwnd, uMsg, wParam, lParam);
					if (hit == HTCLIENT) hit = HTCAPTION;
					return hit;
				}
			}
			return DefWindowProcW(hwnd, uMsg, wParam, lParam);
		};
		
		WNDCLASSEXW wc = {0};
		wc.cbSize = sizeof(WNDCLASSEXW);
		wc.style = CS_HREDRAW | CS_VREDRAW;
		wc.lpfnWndProc = windowProc;
		wc.hInstance = GetModuleHandle(NULL);
		wc.hIcon = NULL;
		wc.hIconSm = NULL;
		wc.hCursor = LoadCursor(NULL, IDC_ARROW);
		wc.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);
		wc.lpszClassName = className;

		RegisterClassExW(&wc);

		// create window w/o minimize/maximize buttons and w/o size border
		HWND hDialog = CreateWindowExW(
			WS_EX_DLGMODALFRAME,
			className,
			wCaption,
			WS_POPUP | WS_CAPTION | WS_SYSMENU, // Removed WS_SIZEBOX and WS_MAXIMIZEBOX
			CW_USEDEFAULT, CW_USEDEFAULT, 800, 800,
			hwnd,
			NULL,
			GetModuleHandle(NULL),
			NULL
		);

		if (hDialog == NULL) {
			MessageBoxW(NULL, L"Failed to create dialog", L"Error", MB_ICONERROR);
			free(wCaption);
			free(wMessage);
			free(formattedMessage);
			return;
		}

		// Text field with scroll
		HWND hEdit = CreateWindowExW(
			WS_EX_CLIENTEDGE,
			L"EDIT",
			formattedMessage,
			WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_READONLY | ES_WANTRETURN,
			10, 10, 780, 700,
			hDialog,
			(HMENU)100,
			GetModuleHandle(NULL),
			NULL
		);

		// center the close button horizontally
		int buttonWidth = 100;
		int buttonHeight = 40;
		int buttonX = (800 - buttonWidth) / 2; // center horizontally
		int buttonY = 720; // Position vertically

		// "Close" button
		HWND hButton = CreateWindowW(
			L"BUTTON",
			L"Close",
			WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
			buttonX, buttonY, buttonWidth, buttonHeight,
			hDialog,
			(HMENU)1, // button ID
			GetModuleHandle(NULL),
			NULL
		);

		free(wCaption);
		free(wMessage);
		free(formattedMessage);

		if (hEdit == NULL || hButton == NULL) {
			MessageBoxW(NULL, L"Failed to create controls", L"Error", MB_ICONERROR);
			DestroyWindow(hDialog);
			return;
		}

		// use a fixed-width font for better readability
		HFONT hFont = CreateFontW(
			14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
			DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
			DEFAULT_QUALITY, FF_DONTCARE, L"Consolas"
		);
		
		if (hFont == NULL) {
			hFont = (HFONT)GetStockObject(SYSTEM_FIXED_FONT);
		}
		
		SendMessageW(hEdit, WM_SETFONT, (WPARAM)hFont, TRUE);
		SendMessageW(hButton, WM_SETFONT, (WPARAM)hFont, TRUE);

		// window centering
		RECT rc;
		GetWindowRect(hDialog, &rc);
		int screenWidth = GetSystemMetrics(SM_CXSCREEN);
		int screenHeight = GetSystemMetrics(SM_CYSCREEN);
		int x = (screenWidth - (rc.right - rc.left)) / 2;
		int y = (screenHeight - (rc.bottom - rc.top)) / 2;
		SetWindowPos(hDialog, NULL, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);

		ShowWindow(hDialog, SW_SHOW);
		UpdateWindow(hDialog);

		// msg loop
		MSG msg;
		while (GetMessage(&msg, NULL, 0, 0)) {
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}

		if (hFont != NULL && hFont != GetStockObject(SYSTEM_FIXED_FONT)) {
			DeleteObject(hFont);
		}
	')
	public static function showScrollableMessage(caption:String, message:String) 
	{
	}

	@:functionCode('
		globalWindowTitle = windowTitle;
	')
	public static function reDefineMainWindowTitle(windowTitle:String)
	{
	}

	@:functionCode('
		HWND hwnd = GET_MAIN_WINDOW();

		if (show) {
			ShowWindow(hwnd, SW_SHOW);
		} else {
			ShowWindow(hwnd, SW_HIDE);
		}
    ')
	static public function setWindowVisible(show:Bool)
	{
	}

	@:functionCode('
        HWND hWnd = GET_MAIN_WINDOW();
        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) | WS_EX_LAYERED);
        if (res)
        {
            SetLayeredWindowAttributes(hWnd, RGB(25, 25, 25), 0, LWA_COLORKEY);
        }
    ')
	static public function getWindowsTransparent(res:Int = 0)
	{
		return res;
	}

	@:functionCode('
        HWND hWnd = GET_MAIN_WINDOW();
        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) ^ WS_EX_LAYERED);
        if (res)
        {
            SetLayeredWindowAttributes(hWnd, RGB(0, 0, 0), 1, LWA_COLORKEY);
        }
    ')
	static public function disableWindowTransparent(res:Int = 0)
	{
		return res;
	}

	@:functionCode('
        HWND window = GET_MAIN_WINDOW();

		auto color = RGB(r, g, b);
		
        if (S_OK != DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF))) {
            DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF));
        }

		if (S_OK != DwmSetWindowAttribute(window, 34, &color, sizeof(COLORREF))) {
            DwmSetWindowAttribute(window, 34, &color, sizeof(COLORREF));
        }

        UpdateWindow(window);
    ')
	public static function setWindowBorderColor(r:Int, g:Int, b:Int)
	{
	}

	@:functionCode('
		HWND window = GET_MAIN_WINDOW();
		SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
	')
	public static function _setWindowLayered()
	{
	}

	@:functionCode('
        HWND window = GET_MAIN_WINDOW();

		float a = alpha;

		if (alpha > 1) {
			a = 1;
		} 
		if (alpha < 0) {
			a = 0;
		}

       	SetLayeredWindowAttributes(window, 0, (255 * (a * 100)) / 100, LWA_ALPHA);
    ')
	public static function setWindowAlpha(alpha:Float)
	{
		return alpha;
	}

	@:functionCode('
		HWND hwnd = GET_MAIN_WINDOW();

		DWORD exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
		BYTE alpha = 255;
		
		if (exStyle & WS_EX_LAYERED) {
			DWORD flags;
			GetLayeredWindowAttributes(hwnd, NULL, &alpha, &flags);
		}

		float alphaFloat = static_cast<float>(alpha) / 255.0f;

		return alphaFloat;
	')
	public static function getWindowAlpha():Float
	{
		return 0;
	}

	@:functionCode('
        HWND hwnd = GET_MAIN_WINDOW();
        int screenWidth = GetSystemMetrics(SM_CXSCREEN);
        int screenHeight = GetSystemMetrics(SM_CYSCREEN);
        
        RECT windowRect;
        GetWindowRect(hwnd, &windowRect);
        int windowWidth = windowRect.right - windowRect.left;
        int windowHeight = windowRect.bottom - windowRect.top;
        
        int centerX = (screenWidth - windowWidth) / 2;
        int centerY = (screenHeight - windowHeight) / 2;
        
        SetWindowPos(hwnd, NULL, centerX, centerY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	@:noCompletion
	public static function centerWindow()
	{
	}

	@:functionCode('
	POINT MousePoint;
	GetCursorPos(&MousePoint);

	return MousePoint.x;
    ')
	static public function getCursorPositionX()
	{
		return 0;
	}

	@:functionCode('
	POINT MousePoint;
	GetCursorPos(&MousePoint);

	return MousePoint.y;
    ')
	static public function getCursorPositionY()
	{
		return 0;
	}

	@:functionCode('
		BOOL isAdmin = FALSE;
		SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
		PSID adminGroup = nullptr;

		if (AllocateAndInitializeSid(&ntAuthority, 2,
			SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS,
			0, 0, 0, 0, 0, 0, &adminGroup)) {

			if (!CheckTokenMembership(nullptr, adminGroup, &isAdmin)) {
				isAdmin = FALSE;
			}

			FreeSid(adminGroup);
		}

		return isAdmin == TRUE;
	')
	public static function isRunningAsAdmin():Bool
	{
		return false;
	}

	@:functionCode('
		int screenWidth = GetSystemMetrics(SM_CXSCREEN);
		int screenHeight = GetSystemMetrics(SM_CYSCREEN);
		screenCapture(0, 0, screenWidth, screenHeight, path);
	')
	@:noCompletion
	public static function windowsScreenShot(path:String)
	{
	}

	@:functionCode("
		unsigned long long allocatedRAM = 0;
		GetPhysicallyInstalledSystemMemory(&allocatedRAM);

		return (allocatedRAM / 1024);
	")
	public static function obtainRAM()
	{
		return 0;
	}

	@:functionCode('
		bool value = hide;
		HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
		HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
	
		if (value == true) {
			ShowWindow(hwnd, SW_HIDE);
			ShowWindow(hwnd2, SW_HIDE);
		} else {
			ShowWindow(hwnd, SW_SHOW);
			ShowWindow(hwnd2, SW_SHOW);
		}
    ')
	public static function hideTaskbar(hide:Bool)
	{
	}

	@:functionCode('
		const char* filepath = path;
	
		int uiAction = SPIF_UPDATEINIFILE | SPIF_SENDCHANGE;
		char filepathBuffer[MAX_PATH];
		strcpy_s(filepathBuffer, filepath);
	
		SystemParametersInfoA(SPI_SETDESKWALLPAPER, 0, filepathBuffer, uiAction);	
    ')
	public static function setWallpaper(path:String)
	{
	}

	@:functionCode('
		bool value = hide;
		HWND hProgman = FindWindowW (L"Progman", L"Program Manager");
		HWND hChild = GetWindow (hProgman, GW_CHILD);
		
		if (value == true) {
			ShowWindow (hChild, SW_HIDE);
		} else {
			ShowWindow (hChild, SW_SHOW);
		}
    ')
	public static function hideDesktopIcons(hide:Bool)
	{
	}

	@:functionCode('
		HWND hd;

		hd = FindWindowA("Progman", NULL);
		hd = FindWindowEx(hd, 0, "SHELLDLL_DefView", NULL);
		hd = FindWindowEx(hd, 0, "SysListView32", NULL);

		SetWindowPos(hd, NULL, x, NULL, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function moveDesktopWindowsInX(x:Int)
	{
	}

	@:functionCode('
		HWND hd;

		hd = FindWindowA("Progman", NULL);
		hd = FindWindowEx(hd, 0, "SHELLDLL_DefView", NULL);
		hd = FindWindowEx(hd, 0, "SysListView32", NULL);

		SetWindowPos(hd, NULL, NULL, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function moveDesktopWindowsInY(y:Int)
	{
	}

	@:functionCode('
		HWND hd;

		hd = FindWindowA("Progman", NULL);
		hd = FindWindowEx(hd, 0, "SHELLDLL_DefView", NULL);
		hd = FindWindowEx(hd, 0, "SysListView32", NULL);

		SetWindowPos(hd, NULL, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function moveDesktopWindowsInXY(x:Int, y:Int)
	{
	}

	@:functionCode('
		HWND hd;

		hd = FindWindowA("Progman", NULL);
		hd = FindWindowEx(hd, 0, "SHELLDLL_DefView", NULL);
		hd = FindWindowEx(hd, 0, "SysListView32", NULL);
		RECT rect;

		GetWindowRect(hd, &rect);

		int x = rect.left;

		return x;
	')
	public static function returnDesktopWindowsX()
	{
		return 0;
	}

	@:functionCode('
		HWND hd;

		hd = FindWindowA("Progman", NULL);
		hd = FindWindowEx(hd, 0, "SHELLDLL_DefView", NULL);
		hd = FindWindowEx(hd, 0, "SysListView32", NULL);
		RECT rect;

		GetWindowRect(hd, &rect);

		int y = rect.top;

		return y;
	')
	public static function returnDesktopWindowsY()
	{
		return 0;
	}

	@:functionCode('
		HWND hProgman = FindWindowW(L"Progman", L"Program Manager");
		HWND hChild = GetWindow(hProgman, GW_CHILD);

		float a = alpha;

		if (alpha > 1) {
			a = 1;
		} 
		if (alpha < 0) {
			a = 0;
		}

       	SetLayeredWindowAttributes(hChild, 0, (255 * (a * 100)) / 100, LWA_ALPHA);
    ')
	public static function _setDesktopWindowsAlpha(alpha:Float)
	{
		return alpha;
	}

	@:functionCode('
		HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
		HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);

		float a = alpha;

		if (alpha > 1) {
			a = 1;
		} 
		if (alpha < 0) {
			a = 0;
		}

       	SetLayeredWindowAttributes(hwnd, 0, (255 * (a * 100)) / 100, LWA_ALPHA);
		SetLayeredWindowAttributes(hwnd2, 0, (255 * (a * 100)) / 100, LWA_ALPHA);
    ')
	public static function _setTaskBarAlpha(alpha:Float)
	{
		return alpha;
	}

	@:functionCode('
	HWND window;
	HWND window2;

	switch (numberMode) {
		case 0:
			window = FindWindowW(L"Progman", L"Program Manager");
			window = GetWindow(window, GW_CHILD);
		case 1:
			window = FindWindowA("Shell_traywnd", nullptr);
			window2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
	}

	if (numberMode != 1) {
		SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
	}
	else {
		SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
		SetWindowLong(window2, GWL_EXSTYLE, GetWindowLong(window2, GWL_EXSTYLE) ^ WS_EX_LAYERED);
	}
	')
	public static function _setWindowLayeredMode(numberMode:Int)
	{
	}
}
#else
#error "SL-Windows-API supports only Windows platform"
#end