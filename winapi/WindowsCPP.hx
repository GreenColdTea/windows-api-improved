package winapi;

/**
 * More than 500 lines of almost pure C++ code :3 
 * 
 * Author: Slushi
 * Rewritten by JustX
 */

#if (cpp && windows)
@:buildXml('
<compilerflag value="/DelayLoad:ComCtl32.dll"/>
<target id="haxe">
    <lib name="dwmapi.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
    <lib name="gdi32.lib" if="windows" />
    <lib name="wbemuuid.lib" if="windows" />
    <lib name="ole32.lib" if="windows" />
    <lib name="oleaut32.lib" if="windows" />
    <lib name="kernel32.lib" if="windows" />
	<lib name="advapi32.lib" if="windows" />
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
#include <wbemidl.h>
#include <comdef.h>
#include <string>
#include <chrono>
#include <thread>

#pragma comment(lib, "wbemuuid.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "Dwmapi.lib")
#pragma comment(lib, "ntdll.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "Shell32.lib")
#pragma comment(lib, "gdi32.lib")

static inline std::wstring UTF8ToWide(const char* utf8Str) {
    if (!utf8Str || !*utf8Str) return L"";
    int reqSize = MultiByteToWideChar(CP_UTF8, 0, utf8Str, -1, NULL, 0);
    std::wstring wstr(reqSize - 1, 0); 
    MultiByteToWideChar(CP_UTF8, 0, utf8Str, -1, &wstr[0], reqSize);
    return wstr;
}

struct WindowSearch { HWND hwnd; DWORD pid; };

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    WindowSearch* search = (WindowSearch*)lParam;
    DWORD pid;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == search->pid && GetWindow(hwnd, GW_OWNER) == NULL && IsWindowVisible(hwnd)) {
        search->hwnd = hwnd;
        return FALSE;
    }
    return TRUE;
}

HWND GET_MAIN_WINDOW() {
    WindowSearch search = { NULL, GetCurrentProcessId() };
    EnumWindows(&EnumWindowsProc, (LPARAM)&search);
    if (search.hwnd != NULL) return search.hwnd;
    return GetActiveWindow();
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

BOOL SaveToFile(HBITMAP hBitmap3, const char* lpszFileName)
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
    
	hDC = CreateDCA("DISPLAY", NULL, NULL, NULL);
	iBits = GetDeviceCaps(hDC, BITSPIXEL) * GetDeviceCaps(hDC, PLANES);
	DeleteDC(hDC);
	if (iBits <= 1) wBitCount = 1;
	else if (iBits <= 4) wBitCount = 4;
	else if (iBits <= 8) wBitCount = 8;
	else wBitCount = 24; 
    
	GetObject(hBitmap3, sizeof(Bitmap0), (LPSTR)&Bitmap0);
	bi.biSize = sizeof(BITMAPINFOHEADER);
	bi.biWidth = Bitmap0.bmWidth;
	bi.biHeight = -Bitmap0.bmHeight;
	bi.biPlanes = 1;
	bi.biBitCount = wBitCount;
	bi.biCompression = BI_RGB;
	bi.biSizeImage = 0;
	bi.biXPelsPerMeter = 0;
	bi.biYPelsPerMeter = 0;
	bi.biClrImportant = 0;
	bi.biClrUsed = 256;
	dwBmBitsSize = ((Bitmap0.bmWidth * wBitCount +31) & ~31) /8 * Bitmap0.bmHeight; 
    
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

	GetDIBits(hDC, hBitmap3, 0, (UINT) Bitmap0.bmHeight, (LPSTR)lpbi + sizeof(BITMAPINFOHEADER) +dwPaletteSize, (BITMAPINFO *)lpbi, DIB_RGB_COLORS);

	if (hOldPal2)
	{
		SelectPalette(hDC, (HPALETTE)hOldPal2, TRUE);
		RealizePalette(hDC);
		ReleaseDC(NULL, hDC);
	}

	fh = CreateFileA(lpszFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL); 

	if (fh == INVALID_HANDLE_VALUE) return FALSE; 

	bmfHdr.bfType = 0x4D42; 
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

int screenCapture(int x, int y, int w, int h, const char* fname)
{
    HDC hdcSource = GetDC(NULL);
    HDC hdcMemory = CreateCompatibleDC(hdcSource);

    HBITMAP hBitmap = CreateCompatibleBitmap(hdcSource, w, h);
    HBITMAP hBitmapOld = (HBITMAP)SelectObject(hdcMemory, hBitmap);

    BitBlt(hdcMemory, 0, 0, w, h, hdcSource, x, y, SRCCOPY);
    hBitmap = (HBITMAP)SelectObject(hdcMemory, hBitmapOld);

    DeleteDC(hdcSource);
    DeleteDC(hdcMemory);

    if(SaveToFile(hBitmap, fname)) return 1;
    return 0;
}

typedef struct {
    BYTE Type;
    BYTE Length;
    WORD Handle;
} SMBIOS_HEADER;
')
class WindowsCPP
{
	@:functionCode('
		MessageBoxW(GET_MAIN_WINDOW(), UTF8ToWide(message.c_str()).c_str(), UTF8ToWide(caption.c_str()).c_str(), icon | type);
	')
	public static function showMessageBox(caption:String, message:String, icon:WindowsAPI.MessageBoxIcon = MSG_WARNING, type:WindowsAPI.MessageBoxType = MSG_OK) {}

    @:functionCode('
        std::wstring wCaption = UTF8ToWide(caption.c_str());
        std::wstring wMessage = UTF8ToWide(message.c_str());
        std::wstring formattedMessage;
        
        for (size_t i = 0; i < wMessage.length(); i++) {
            if (wMessage[i] == L\'\\n\' && (i == 0 || wMessage[i-1] != L\'\\r\')) {
                formattedMessage += L"\\r\\n";
            } else {
                formattedMessage += wMessage[i];
            }
        }

		HWND hwnd = GET_MAIN_WINDOW();
		const wchar_t* className = L"ScrollableMessageClass";
		
		WNDPROC windowProc = [](HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) -> LRESULT {
			switch (uMsg) {
				case WM_CLOSE: DestroyWindow(hwnd); return 0;
				case WM_DESTROY: PostQuitMessage(0); return 0;
				case WM_COMMAND: if (LOWORD(wParam) == 1) { DestroyWindow(hwnd); return 0; } break;
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
		wc.hCursor = LoadCursor(NULL, IDC_ARROW);
		wc.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);
		wc.lpszClassName = className;

		RegisterClassExW(&wc);

		HWND hDialog = CreateWindowExW(WS_EX_DLGMODALFRAME, className, wCaption.c_str(),
			WS_POPUP | WS_CAPTION | WS_SYSMENU, CW_USEDEFAULT, CW_USEDEFAULT, 800, 800,
			hwnd, NULL, GetModuleHandle(NULL), NULL);

		if (hDialog == NULL) return;

		HWND hEdit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", formattedMessage.c_str(),
			WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_READONLY | ES_WANTRETURN,
			10, 10, 780, 700, hDialog, (HMENU)100, GetModuleHandle(NULL), NULL);

		int buttonX = (800 - 100) / 2;
		HWND hButton = CreateWindowW(L"BUTTON", L"Close", WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
			buttonX, 720, 100, 40, hDialog, (HMENU)1, GetModuleHandle(NULL), NULL);

		if (hEdit == NULL || hButton == NULL) { DestroyWindow(hDialog); return; }

		HFONT hFont = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE, L"Consolas");
		if (hFont == NULL) hFont = (HFONT)GetStockObject(SYSTEM_FIXED_FONT);
		
		SendMessageW(hEdit, WM_SETFONT, (WPARAM)hFont, TRUE);
		SendMessageW(hButton, WM_SETFONT, (WPARAM)hFont, TRUE);

		RECT rc; GetWindowRect(hDialog, &rc);
		int screenWidth = GetSystemMetrics(SM_CXSCREEN);
		int screenHeight = GetSystemMetrics(SM_CYSCREEN);
		SetWindowPos(hDialog, NULL, (screenWidth - (rc.right - rc.left)) / 2, (screenHeight - (rc.bottom - rc.top)) / 2, 0, 0, SWP_NOSIZE | SWP_NOZORDER);

		ShowWindow(hDialog, SW_SHOW); UpdateWindow(hDialog);

		MSG msg;
		while (GetMessage(&msg, NULL, 0, 0)) {
			TranslateMessage(&msg); DispatchMessage(&msg);
		}

		if (hFont != NULL && hFont != GetStockObject(SYSTEM_FIXED_FONT)) DeleteObject(hFont);
	')
	public static function showScrollableMessage(caption:String, message:String) {}

	@:functionCode('
		HWND hwnd = GET_MAIN_WINDOW();
		ShowWindow(hwnd, show ? SW_SHOW : SW_HIDE);
    ')
	static public function setWindowVisible(show:Bool) {}

	@:functionCode('
        HWND hWnd = GET_MAIN_WINDOW();
        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) | WS_EX_LAYERED);
        if (res) SetLayeredWindowAttributes(hWnd, RGB(25, 25, 25), 0, LWA_COLORKEY);
    ')
	static public function getWindowsTransparent(res:Int = 0) return res;

	@:functionCode('
        HWND hWnd = GET_MAIN_WINDOW();
        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) ^ WS_EX_LAYERED);
        if (res) SetLayeredWindowAttributes(hWnd, RGB(0, 0, 0), 1, LWA_COLORKEY);
    ')
	static public function disableWindowTransparent(res:Int = 0) return res;

	@:functionCode('
        HWND window = GET_MAIN_WINDOW();
		auto color = RGB(r, g, b);
        DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF));
        DwmSetWindowAttribute(window, 34, &color, sizeof(COLORREF));
        UpdateWindow(window);
    ')
	public static function setWindowBorderColor(r:Int, g:Int, b:Int) {}

	@:functionCode('
		HWND window = GET_MAIN_WINDOW();
		SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
	')
	public static function _setWindowLayered() {}

	@:functionCode('
        HWND window = GET_MAIN_WINDOW();
		float a = alpha;
		if (a > 1) a = 1; 
		if (a < 0) a = 0;
       	SetLayeredWindowAttributes(window, 0, (BYTE)(255 * a), LWA_ALPHA);
    ')
	public static function setWindowAlpha(alpha:Float) return alpha;

	@:functionCode('
		HWND hwnd = GET_MAIN_WINDOW();
		DWORD exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
		BYTE alpha = 255;
		if (exStyle & WS_EX_LAYERED) {
			DWORD flags;
			GetLayeredWindowAttributes(hwnd, NULL, &alpha, &flags);
		}
		return static_cast<float>(alpha) / 255.0f;
	')
	public static function getWindowAlpha():Float return 1.0;

	@:functionCode('
        HWND hwnd = GET_MAIN_WINDOW();
        int screenWidth = GetSystemMetrics(SM_CXSCREEN);
        int screenHeight = GetSystemMetrics(SM_CYSCREEN);
        RECT windowRect;
        GetWindowRect(hwnd, &windowRect);
        int centerX = (screenWidth - (windowRect.right - windowRect.left)) / 2;
        int centerY = (screenHeight - (windowRect.bottom - windowRect.top)) / 2;
        SetWindowPos(hwnd, NULL, centerX, centerY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	@:noCompletion
	public static function centerWindow() {}

	@:functionCode('POINT MousePoint; GetCursorPos(&MousePoint); return MousePoint.x;')
	static public function getCursorPositionX() return 0;

	@:functionCode('POINT MousePoint; GetCursorPos(&MousePoint); return MousePoint.y;')
	static public function getCursorPositionY() return 0;

	@:functionCode('
		BOOL isAdmin = FALSE;
		SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
		PSID adminGroup = nullptr;
		if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup)) {
			if (!CheckTokenMembership(nullptr, adminGroup, &isAdmin)) isAdmin = FALSE;
			FreeSid(adminGroup);
		}
		return isAdmin == TRUE;
	')
	public static function isRunningAsAdmin():Bool return false;

	@:functionCode('
		int screenWidth = GetSystemMetrics(SM_CXSCREEN);
		int screenHeight = GetSystemMetrics(SM_CYSCREEN);
		screenCapture(0, 0, screenWidth, screenHeight, path.c_str());
	')
	@:noCompletion
	public static function windowsScreenShot(path:String) {}

	/**
	 * @see https://stackoverflow.com/questions/14227171/how-to-get-memory-information-ram-type-e-g-ddr-ddr2-ddr3-with-wmi-c
	 */
	@:functionCode("
		unsigned long long allocatedRAM = 0;
		GetPhysicallyInstalledSystemMemory(&allocatedRAM);
		int ramSizeMB = (int)(allocatedRAM / 1024);

		if (!showType) {
			char result[64];
			sprintf_s(result, sizeof(result), \"%d MB\", ramSizeMB);
			return ::String(result);
		}

		std::string ramType = \"\";
		DWORD bufferSize = GetSystemFirmwareTable('RSMB', 0, NULL, 0);
		
		if (bufferSize > 0) {
			BYTE* pBuffer = new BYTE[bufferSize];
			if (GetSystemFirmwareTable('RSMB', 0, pBuffer, bufferSize) == bufferSize) {
				const SMBIOS_HEADER* pHeader = (const SMBIOS_HEADER*)pBuffer;
				const BYTE* pData = pBuffer;
				
				pData += pHeader->Length;
				while (pData + sizeof(SMBIOS_HEADER) < pBuffer + bufferSize) {
					const SMBIOS_HEADER* pStructHeader = (const SMBIOS_HEADER*)pData;
					
					// Type 17 - Memory Device
					if (pStructHeader->Type == 17 && pStructHeader->Length >= 0x15) {
						BYTE memoryType = pData[0x12];
						
						switch (memoryType) {
							case 0x12: ramType = \"DDR\"; break;      // 18
							case 0x13: ramType = \"DDR2\"; break;     // 19
							case 0x14: ramType = \"DDR2 FB-DIMM\"; break; // 20
							case 0x18: ramType = \"DDR3\"; break;     // 24
							case 0x1A: ramType = \"DDR4\"; break;     // 26
							case 0x1B: ramType = \"LPDDR4\"; break;   // 27 (sometimes LPDDR)
							case 0x1C: ramType = \"LPDDR4X\"; break;  // 28
							case 0x1D: ramType = \"DDR5\"; break;     // 29
							case 0x1E: ramType = \"LPDDR5\"; break;   // 30
							case 0x1F: ramType = \"LVM\"; break;      // 31 (Logical non-volatile device)
							case 0x20: ramType = \"HBM\"; break;      // 32
							case 0x21: ramType = \"HBM2\"; break;     // 33
							case 0x22: ramType = \"DDR5\"; break;     // 34
							case 0x23: ramType = \"LPDDR5\"; break;   // 35
							case 0x24: ramType = \"HBM3\"; break;     // 36
							case 0x25: ramType = \"LPDDR5X\"; break;  // 37
							default: break;
						}
						
						if (!ramType.empty()) break;
					}
					
					pData += pStructHeader->Length;
					while (pData < pBuffer + bufferSize && !(pData[0] == 0 && pData[1] == 0)) pData++;
					pData += 2;
				}
			}
			delete[] pBuffer;
		}
		
		char result[256];
		if (!ramType.empty()) {
			sprintf_s(result, sizeof(result), \"%d MB (%s)\", ramSizeMB, ramType.c_str());
		} else {
			sprintf_s(result, sizeof(result), \"%d MB\", ramSizeMB);
		}
		return ::String(result);
	")
	public static function obtainRAM(showType:Bool = true):String return "";

	@:functionCode('
		HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
		HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
		ShowWindow(hwnd, hide ? SW_HIDE : SW_SHOW);
		ShowWindow(hwnd2, hide ? SW_HIDE : SW_SHOW);
    ')
	public static function hideTaskbar(hide:Bool) {}

	@:functionCode('
		SystemParametersInfoA(SPI_SETDESKWALLPAPER, 0, (PVOID)path.c_str(), SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);	
    ')
	public static function setWallpaper(path:String) {}

	@:functionCode('
		HWND hProgman = FindWindowW(L"Progman", L"Program Manager");
		HWND hChild = GetWindow(hProgman, GW_CHILD);
		ShowWindow(hChild, hide ? SW_HIDE : SW_SHOW);
    ')
	public static function hideDesktopIcons(hide:Bool) {}

	@:functionCode('
		HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
		SetWindowPos(hd, NULL, x, NULL, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function moveDesktopWindowsInX(x:Int) {}

	@:functionCode('
		HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
		SetWindowPos(hd, NULL, NULL, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function moveDesktopWindowsInY(y:Int) {}

	@:functionCode('
		HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
		SetWindowPos(hd, NULL, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function moveDesktopWindowsInXY(x:Int, y:Int) {}

	@:functionCode('
		HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
		RECT rect; GetWindowRect(hd, &rect);
		return rect.left;
	')
	public static function returnDesktopWindowsX() return 0;

	@:functionCode('
		HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
		RECT rect; GetWindowRect(hd, &rect);
		return rect.top;
	')
	public static function returnDesktopWindowsY() return 0;

	@:functionCode('
		HWND hProgman = FindWindowW(L"Progman", L"Program Manager");
		HWND hChild = GetWindow(hProgman, GW_CHILD);
		float a = alpha > 1 ? 1 : (alpha < 0 ? 0 : alpha);
       	SetLayeredWindowAttributes(hChild, 0, (BYTE)(255 * a), LWA_ALPHA);
    ')
	public static function _setDesktopWindowsAlpha(alpha:Float) return alpha;

	@:functionCode('
		HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
		HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
		float a = alpha > 1 ? 1 : (alpha < 0 ? 0 : alpha);
       	SetLayeredWindowAttributes(hwnd, 0, (BYTE)(255 * a), LWA_ALPHA);
		SetLayeredWindowAttributes(hwnd2, 0, (BYTE)(255 * a), LWA_ALPHA);
    ')
	public static function _setTaskBarAlpha(alpha:Float) return alpha;

	@:functionCode('
		HWND window;
		HWND window2;
		switch (numberMode) {
			case 0:
				window = GetWindow(FindWindowW(L"Progman", L"Program Manager"), GW_CHILD);
				break;
			case 1:
				window = FindWindowA("Shell_traywnd", nullptr);
				window2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
				break;
		}
		SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
		if (numberMode == 1) SetWindowLong(window2, GWL_EXSTYLE, GetWindowLong(window2, GWL_EXSTYLE) ^ WS_EX_LAYERED);
	')
	public static function _setWindowLayeredMode(numberMode:Int) {}

	public static function disableWindowsGhosting():Void untyped __cpp__('DisableProcessWindowsGhosting()');
	public static function disableWindowsReport():Void untyped __cpp__('SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);');
	public static function setConsoleOutputToUTF8():Void untyped __cpp__('SetConsoleOutputCP(CP_UTF8);');
}
#elseif (hl && windows)
class WindowsCPP {
	@:hlNative("winapi", "show_message_box") public static function showMessageBox(caption:String, message:String, icon:Int, type:Int):Void {}
	@:hlNative("winapi", "show_scrollable_message") public static function showScrollableMessage(caption:String, message:String):Void {}
	@:hlNative("winapi", "set_window_visible") public static function setWindowVisible(show:Bool):Void {}
	@:hlNative("winapi", "get_windows_transparent") public static function getWindowsTransparent(res:Int = 0):Int return res;
	@:hlNative("winapi", "disable_window_transparent") public static function disableWindowTransparent(res:Int = 0):Int return res;
	@:hlNative("winapi", "set_window_border_color") public static function setWindowBorderColor(r:Int, g:Int, b:Int):Void {}
	@:hlNative("winapi", "set_window_layered") public static function _setWindowLayered():Void {}
	@:hlNative("winapi", "set_window_alpha") public static function setWindowAlpha(alpha:Float):Float return alpha;
	@:hlNative("winapi", "get_window_alpha") public static function getWindowAlpha():Float return 1.0;
	@:hlNative("winapi", "center_window") public static function centerWindow():Void {}
	@:hlNative("winapi", "get_cursor_x") public static function getCursorPositionX():Int return 0;
	@:hlNative("winapi", "get_cursor_y") public static function getCursorPositionY():Int return 0;
	@:hlNative("winapi", "is_admin") public static function isRunningAsAdmin():Bool return false;
	@:hlNative("winapi", "screen_shot") public static function windowsScreenShot(path:String):Void {}
	@:hlNative("winapi", "obtain_ram") public static function obtainRAM(showType:Bool = true):String return "";
	@:hlNative("winapi", "hide_taskbar") public static function hideTaskbar(hide:Bool):Void {}
	@:hlNative("winapi", "set_wallpaper") public static function setWallpaper(path:String):Void {}
	@:hlNative("winapi", "hide_desktop_icons") public static function hideDesktopIcons(hide:Bool):Void {}
	@:hlNative("winapi", "move_desktop_x") public static function moveDesktopWindowsInX(x:Int):Void {}
	@:hlNative("winapi", "move_desktop_y") public static function moveDesktopWindowsInY(y:Int):Void {}
	@:hlNative("winapi", "move_desktop_xy") public static function moveDesktopWindowsInXY(x:Int, y:Int):Void {}
	@:hlNative("winapi", "get_desktop_x") public static function returnDesktopWindowsX():Int return 0;
	@:hlNative("winapi", "get_desktop_y") public static function returnDesktopWindowsY():Int return 0;
	@:hlNative("winapi", "set_desktop_alpha") public static function _setDesktopWindowsAlpha(alpha:Float):Float return alpha;
	@:hlNative("winapi", "set_taskbar_alpha") public static function _setTaskBarAlpha(alpha:Float):Float return alpha;
	@:hlNative("winapi", "set_layered_mode") public static function _setWindowLayeredMode(mode:Int):Void {}
	@:hlNative("winapi", "disable_ghosting") public static function disableWindowsGhosting():Void {}
	@:hlNative("winapi", "disable_report") public static function disableWindowsReport():Void {}
	@:hlNative("winapi", "set_console_output_to_utf8") public static function setConsoleOutputToUTF8():Void {}
}
#else
#error "SL-Windows-API supports only Windows platform (C++ or HashLink)"
#end