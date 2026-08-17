package winapi;

/**
 * This file is in charge of providing some Windows terminal functions 
 * 
 * Author: Slushi
 * Rewritten by JustX
 */

#if (cpp && windows)
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

#pragma comment(lib, "Dwmapi")
#pragma comment(lib, "ntdll.lib")
#pragma comment(lib, "User32.lib")
#pragma comment(lib, "Shell32.lib")
#pragma comment(lib, "gdi32.lib")

static inline std::wstring UTF8ToWide(const char* utf8Str) {
    if (!utf8Str || !*utf8Str) return L"";
    int reqSize = MultiByteToWideChar(CP_UTF8, 0, utf8Str, -1, NULL, 0);
    std::wstring wstr(reqSize - 1, 0); 
    MultiByteToWideChar(CP_UTF8, 0, utf8Str, -1, &wstr[0], reqSize);
    return wstr;
}
')
class WindowsTerminalCPP
{
	@:functionCode('system("CLS"); std::cout<< "" <<std::flush;')
	public static function clearTerminal() {}

	@:functionCode('
        if (!AllocConsole()) return;
        freopen("CONIN$", "r", stdin);
        freopen("CONOUT$", "w", stdout);
        freopen("CONOUT$", "w", stderr);
        HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
        SetConsoleMode(output, ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
    ')
	public static function allocConsole() {}

	@:functionCode('ShowWindow(GetActiveWindow(), SW_HIDE);')
	public static function hideMainWindow() {}

	@:functionCode('SetConsoleTitleW(UTF8ToWide(text.c_str()).c_str());')
	public static function setConsoleTitle(text:String) {}

	@:functionCode('
        HWND window = GetConsoleWindow();
        HICON smallIcon = (HICON) LoadImageA(NULL, path.c_str(), IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
        HICON icon = (HICON) LoadImageA(NULL, path.c_str(), IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE);
        SendMessage(window, WM_SETICON, ICON_SMALL, (LPARAM)smallIcon);
        SendMessage(window, WM_SETICON, ICON_BIG, (LPARAM)icon);    
    ')
	public static function setConsoleWindowIcon(path:String) {}

	@:functionCode('
        HWND hwnd = GetConsoleWindow();
        int screenWidth = GetSystemMetrics(SM_CXSCREEN);
        int screenHeight = GetSystemMetrics(SM_CYSCREEN);
        RECT windowRect;
        GetWindowRect(hwnd, &windowRect);
        int centerX = (screenWidth - (windowRect.right - windowRect.left)) / 2;
        int centerY = (screenHeight - (windowRect.bottom - windowRect.top)) / 2;
        SetWindowPos(hwnd, NULL, centerX, centerY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
    ')
	public static function centerConsoleWindow() {}

	@:functionCode('
        HWND hwnd = GetConsoleWindow();
        LONG style = GetWindowLongPtrW(hwnd, GWL_STYLE);
        style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX); 
        SetWindowLongPtrW(hwnd, GWL_STYLE, style);    
    ')
	public static function disableResizeConsoleWindow() {}

	@:functionCode('
        HWND hwnd = GetConsoleWindow();
        HMENU hmenu = GetSystemMenu(hwnd, FALSE);
        EnableMenuItem(hmenu, SC_CLOSE, MF_GRAYED);
    ')
	public static function disableCloseConsoleWindow() {}

	@:functionCode('ShowWindow(GetConsoleWindow(), SW_MAXIMIZE);')
	public static function maximizeConsoleWindow() {}

	@:functionCode('
        COORD pos = {(SHORT)x, (SHORT)y};
        SetConsoleCursorPosition(GetStdHandle(STD_OUTPUT_HANDLE), pos);
    ')
	public static function setConsoleCursorPosition(x:Int, y:Int) {}

	@:functionCode('
        CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;
        GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &screenBufferInfo);
        return (int)screenBufferInfo.dwCursorPosition.X;
    ')
	public static function getConsoleCursorPositionInX():Int return 0;

	@:functionCode('
        CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;
        GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &screenBufferInfo);
        return (int)screenBufferInfo.dwCursorPosition.Y;
    ')
	public static function getConsoleCursorPositionInY():Int return 0;

	@:functionCode('SetWindowPos(GetConsoleWindow(), NULL, posX, NULL, 0, 0, SWP_NOSIZE | SWP_NOZORDER);')
	public static function setConsoleWindowPositionX(posX:Int) {}

	@:functionCode('SetWindowPos(GetConsoleWindow(), NULL, NULL, posY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);')
	public static function setConsoleWindowPositionY(posY:Int) {}

	@:functionCode('RECT rect; GetWindowRect(GetConsoleWindow(), &rect); return (int)(rect.right - rect.left);')
	public static function getConsoleWindowWidth():Int return 0;

	@:functionCode('RECT rect; GetWindowRect(GetConsoleWindow(), &rect); return (int)(rect.bottom - rect.top);')
	public static function getConsoleWindowHeight():Int return 0;

	@:functionCode('RECT rect; GetWindowRect(GetConsoleWindow(), &rect); return (int)rect.left;')
	public static function getConsoleWindowPositionX():Int return 0;

	@:functionCode('RECT rect; GetWindowRect(GetConsoleWindow(), &rect); return (int)rect.top;')
	public static function getConsoleWindowPositionY():Int return 0;

	@:functionCode('ShowWindow(GetConsoleWindow(), SW_HIDE);')
	public static function hideConsoleWindow() {}
}
#elseif (hl && windows)
class WindowsTerminalCPP {
	@:hlNative("winapi", "term_clear") public static function clearTerminal():Void {}
	@:hlNative("winapi", "term_alloc") public static function allocConsole():Void {}
	@:hlNative("winapi", "term_hide_main") public static function hideMainWindow():Void {}
	@:hlNative("winapi", "term_set_title") public static function setConsoleTitle(text:String):Void {}
	@:hlNative("winapi", "term_set_icon") public static function setConsoleWindowIcon(path:String):Void {}
	@:hlNative("winapi", "term_center") public static function centerConsoleWindow():Void {}
	@:hlNative("winapi", "term_disable_resize") public static function disableResizeConsoleWindow():Void {}
	@:hlNative("winapi", "term_disable_close") public static function disableCloseConsoleWindow():Void {}
	@:hlNative("winapi", "term_maximize") public static function maximizeConsoleWindow():Void {}
	@:hlNative("winapi", "term_set_cursor") public static function setConsoleCursorPosition(x:Int, y:Int):Void {}
	@:hlNative("winapi", "term_get_cursor_x") public static function getConsoleCursorPositionInX():Int return 0;
	@:hlNative("winapi", "term_get_cursor_y") public static function getConsoleCursorPositionInY():Int return 0;
	@:hlNative("winapi", "term_set_pos_x") public static function setConsoleWindowPositionX(x:Int):Void {}
	@:hlNative("winapi", "term_set_pos_y") public static function setConsoleWindowPositionY(y:Int):Void {}
	@:hlNative("winapi", "term_get_width") public static function getConsoleWindowWidth():Int return 0;
	@:hlNative("winapi", "term_get_height") public static function getConsoleWindowHeight():Int return 0;
	@:hlNative("winapi", "term_get_pos_x") public static function getConsoleWindowPositionX():Int return 0;
	@:hlNative("winapi", "term_get_pos_y") public static function getConsoleWindowPositionY():Int return 0;
	@:hlNative("winapi", "term_hide") public static function hideConsoleWindow():Void {}
}
#else
#error "SL-Windows-API supports only Windows platform (C++ or HashLink)"
#end