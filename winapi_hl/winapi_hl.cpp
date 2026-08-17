#define _WIN32_WINNT 0x0A00 

#include <Windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <winuser.h>
#include <winternl.h>
#include <Shlobj.h>
#include <commctrl.h>

#include <cstdio>
#include <iostream>
#include <string>
#include <math.h>

#define HL_NAME(n) winapi_##n
#include <hl.h>

#pragma comment(lib, "Dwmapi.lib")
#pragma comment(lib, "ntdll.lib")
#pragma comment(lib, "User32.lib")
#pragma comment(lib, "Shell32.lib")
#pragma comment(lib, "gdi32.lib")

#define HL_WSTR(s) ((LPCWSTR)(s ? s->bytes : NULL))

vstring* hl_make_string(const wchar_t* str) {
    if (!str) return NULL;

    int len = (int)wcslen(str);
    uchar* buf = (uchar*)hl_gc_alloc_raw((len + 1) * sizeof(uchar));
    memcpy(buf, str, (len + 1) * sizeof(uchar));
    vstring* s = (vstring*)hl_gc_alloc_raw(sizeof(vstring));
    s->bytes = buf;
    s->length = len;

    return s;
}

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

// ====================================================================================
// WINDOWS CPP FUNCITONS
// ====================================================================================

HL_PRIM void HL_NAME(show_message_box)(vstring* caption, vstring* message, int icon, int type) {
    MessageBoxW(GET_MAIN_WINDOW(), HL_WSTR(message), HL_WSTR(caption), icon | type);
}

HL_PRIM void HL_NAME(show_scrollable_message)(vstring* caption, vstring* message) {
    std::wstring wCaption = HL_WSTR(caption);
    std::wstring wMessage = HL_WSTR(message);
    std::wstring formattedMessage;
    
    for (size_t i = 0; i < wMessage.length(); i++) {
        if (wMessage[i] == L'\n' && (i == 0 || wMessage[i-1] != L'\r')) {
            formattedMessage += L"\r\n";
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
            case WM_NCHITTEST: {
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
}

HL_PRIM void HL_NAME(set_window_visible)(bool show) {
    ShowWindow(GET_MAIN_WINDOW(), show ? SW_SHOW : SW_HIDE);
}

HL_PRIM int HL_NAME(get_windows_transparent)(int res) {
    HWND hWnd = GET_MAIN_WINDOW();
    res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) | WS_EX_LAYERED);
    if (res) SetLayeredWindowAttributes(hWnd, RGB(25, 25, 25), 0, LWA_COLORKEY);

    return res;
}

HL_PRIM int HL_NAME(disable_window_transparent)(int res) {
    HWND hWnd = GET_MAIN_WINDOW();
    res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) ^ WS_EX_LAYERED);
    if (res) SetLayeredWindowAttributes(hWnd, RGB(0, 0, 0), 1, LWA_COLORKEY);

    return res;
}

HL_PRIM void HL_NAME(set_window_border_color)(int r, int g, int b) {
    HWND window = GET_MAIN_WINDOW();
    COLORREF color = RGB(r, g, b);
    DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF));
    DwmSetWindowAttribute(window, 34, &color, sizeof(COLORREF));
    UpdateWindow(window);
}

HL_PRIM void HL_NAME(set_window_layered)() {
    HWND window = GET_MAIN_WINDOW();
    SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
}

HL_PRIM float HL_NAME(set_window_alpha)(float alpha) {
    HWND window = GET_MAIN_WINDOW();
    float a = alpha > 1 ? 1 : (alpha < 0 ? 0 : alpha);
    SetLayeredWindowAttributes(window, 0, (BYTE)(255 * a), LWA_ALPHA);

    return alpha;
}

HL_PRIM float HL_NAME(get_window_alpha)() {
    HWND hwnd = GET_MAIN_WINDOW();
    DWORD exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
    BYTE alpha = 255;
    if (exStyle & WS_EX_LAYERED) {
        DWORD flags;
        GetLayeredWindowAttributes(hwnd, NULL, &alpha, &flags);
    }

    return static_cast<float>(alpha) / 255.0f;
}

HL_PRIM void HL_NAME(center_window)() {
    HWND hwnd = GET_MAIN_WINDOW();
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    RECT windowRect;

    GetWindowRect(hwnd, &windowRect);

    int centerX = (screenWidth - (windowRect.right - windowRect.left)) / 2;
    int centerY = (screenHeight - (windowRect.bottom - windowRect.top)) / 2;
    SetWindowPos(hwnd, NULL, centerX, centerY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
}

HL_PRIM int HL_NAME(get_cursor_x)() { POINT MousePoint; GetCursorPos(&MousePoint); return MousePoint.x; }
HL_PRIM int HL_NAME(get_cursor_y)() { POINT MousePoint; GetCursorPos(&MousePoint); return MousePoint.y; }

HL_PRIM bool HL_NAME(is_admin)() {
    BOOL isAdmin = FALSE;
    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
    PSID adminGroup = nullptr;
    if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup)) {
        if (!CheckTokenMembership(nullptr, adminGroup, &isAdmin)) isAdmin = FALSE;
        FreeSid(adminGroup);
    }

    return isAdmin == TRUE;
}

BOOL SaveToFileW(HBITMAP hBitmap3, LPCWSTR lpszFileName) {   
    HDC hDC; int iBits; WORD wBitCount;
    DWORD dwPaletteSize=0, dwBmBitsSize=0, dwDIBSize=0, dwWritten=0;
    BITMAP Bitmap0; BITMAPFILEHEADER bmfHdr; BITMAPINFOHEADER bi;
    LPBITMAPINFOHEADER lpbi; HANDLE fh, hDib, hPal, hOldPal2=NULL;
    
    hDC = CreateDCA("DISPLAY", NULL, NULL, NULL);
    iBits = GetDeviceCaps(hDC, BITSPIXEL) * GetDeviceCaps(hDC, PLANES);
    DeleteDC(hDC);
    wBitCount = (iBits <= 1) ? 1 : (iBits <= 4) ? 4 : (iBits <= 8) ? 8 : 24; 
    
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
    if (hPal) { 
        hDC = GetDC(NULL);
        hOldPal2 = SelectPalette(hDC, (HPALETTE)hPal, FALSE);
        RealizePalette(hDC);
    }
    GetDIBits(hDC, hBitmap3, 0, (UINT) Bitmap0.bmHeight, (LPSTR)lpbi + sizeof(BITMAPINFOHEADER) +dwPaletteSize, (BITMAPINFO *)lpbi, DIB_RGB_COLORS);
    if (hOldPal2) {
        SelectPalette(hDC, (HPALETTE)hOldPal2, TRUE);
        RealizePalette(hDC);
        ReleaseDC(NULL, hDC);
    }

    fh = CreateFileW(lpszFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL); 
    if (fh == INVALID_HANDLE_VALUE) return FALSE; 

    bmfHdr.bfType = 0x4D42; 
    dwDIBSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + dwPaletteSize + dwBmBitsSize;
    bmfHdr.bfSize = dwDIBSize;
    bmfHdr.bfReserved1 = 0;
    bmfHdr.bfReserved2 = 0;
    bmfHdr.bfOffBits = (DWORD)sizeof(BITMAPFILEHEADER) + (DWORD)sizeof(BITMAPINFOHEADER) + dwPaletteSize;

    WriteFile(fh, (LPSTR)&bmfHdr, sizeof(BITMAPFILEHEADER), &dwWritten, NULL);
    WriteFile(fh, (LPSTR)lpbi, dwDIBSize, &dwWritten, NULL);
    GlobalUnlock(hDib); GlobalFree(hDib); CloseHandle(fh);
    return TRUE;
} 

HL_PRIM void HL_NAME(screen_shot)(vstring* path) {
    int w = GetSystemMetrics(SM_CXSCREEN);
    int h = GetSystemMetrics(SM_CYSCREEN);
    HDC hdcSource = GetDC(NULL);
    HDC hdcMemory = CreateCompatibleDC(hdcSource);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdcSource, w, h);
    HBITMAP hBitmapOld = (HBITMAP)SelectObject(hdcMemory, hBitmap);
    BitBlt(hdcMemory, 0, 0, w, h, hdcSource, 0, 0, SRCCOPY);
    hBitmap = (HBITMAP)SelectObject(hdcMemory, hBitmapOld);
    DeleteDC(hdcSource);
    DeleteDC(hdcMemory);
    SaveToFileW(hBitmap, HL_WSTR(path));
}

typedef struct { BYTE Type; BYTE Length; WORD Handle; } SMBIOS_HEADER;

HL_PRIM vstring* HL_NAME(obtain_ram)(bool showType) {
    unsigned long long allocatedRAM = 0;
    GetPhysicallyInstalledSystemMemory(&allocatedRAM);
    int ramSizeMB = (int)(allocatedRAM / 1024);

    if (!showType) {
        char result[64];
        sprintf_s(result, sizeof(result), "%d MB", ramSizeMB);
        return hl_make_string(UTF8ToWide(result).c_str());
    }

    std::string ramType = "";
    DWORD bufferSize = GetSystemFirmwareTable('RSMB', 0, NULL, 0);
    
    if (bufferSize > 0) {
        BYTE* pBuffer = new BYTE[bufferSize];
        if (GetSystemFirmwareTable('RSMB', 0, pBuffer, bufferSize) == bufferSize) {
            const SMBIOS_HEADER* pHeader = (const SMBIOS_HEADER*)pBuffer;
            const BYTE* pData = pBuffer;
            
            pData += pHeader->Length;
            while (pData + sizeof(SMBIOS_HEADER) < pBuffer + bufferSize) {
                const SMBIOS_HEADER* pStructHeader = (const SMBIOS_HEADER*)pData;
                if (pStructHeader->Type == 17 && pStructHeader->Length >= 0x15) {
                    BYTE memoryType = pData[0x12];
                    switch (memoryType) {
                        case 0x12: ramType = "DDR"; break;      
                        case 0x13: ramType = "DDR2"; break;     
                        case 0x14: ramType = "DDR2 FB-DIMM"; break; 
                        case 0x18: ramType = "DDR3"; break;     
                        case 0x1A: ramType = "DDR4"; break;     
                        case 0x1B: ramType = "LPDDR4"; break;   
                        case 0x1C: ramType = "LPDDR4X"; break;  
                        case 0x1D: ramType = "DDR5"; break;     
                        case 0x1E: ramType = "LPDDR5"; break;   
                        case 0x1F: ramType = "LVM"; break;      
                        case 0x20: ramType = "HBM"; break;      
                        case 0x21: ramType = "HBM2"; break;     
                        case 0x22: ramType = "DDR5"; break;     
                        case 0x23: ramType = "LPDDR5"; break;   
                        case 0x24: ramType = "HBM3"; break;     
                        case 0x25: ramType = "LPDDR5X"; break;  
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
        sprintf_s(result, sizeof(result), "%d MB (%s)", ramSizeMB, ramType.c_str());
    } else {
        sprintf_s(result, sizeof(result), "%d MB", ramSizeMB);
    }

    return hl_make_string(UTF8ToWide(result).c_str());
}

HL_PRIM void HL_NAME(hide_taskbar)(bool hide) {
    HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
    HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
    ShowWindow(hwnd, hide ? SW_HIDE : SW_SHOW);
    ShowWindow(hwnd2, hide ? SW_HIDE : SW_SHOW);
}

HL_PRIM void HL_NAME(set_wallpaper)(vstring* path) {
    SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, (PVOID)HL_WSTR(path), SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
}

HL_PRIM void HL_NAME(hide_desktop_icons)(bool hide) {
    HWND hProgman = FindWindowW(L"Progman", L"Program Manager");
    HWND hChild = GetWindow(hProgman, GW_CHILD);
    ShowWindow(hChild, hide ? SW_HIDE : SW_SHOW);
}

HL_PRIM void HL_NAME(move_desktop_x)(int x) {
    HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
    SetWindowPos(hd, NULL, x, NULL, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
}

HL_PRIM void HL_NAME(move_desktop_y)(int y) {
    HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
    SetWindowPos(hd, NULL, NULL, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
}

HL_PRIM void HL_NAME(move_desktop_xy)(int x, int y) {
    HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
    SetWindowPos(hd, NULL, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
}

HL_PRIM int HL_NAME(get_desktop_x)() {
    HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
    RECT rect; GetWindowRect(hd, &rect); return rect.left;
}

HL_PRIM int HL_NAME(get_desktop_y)() {
    HWND hd = FindWindowEx(FindWindowEx(FindWindowA("Progman", NULL), 0, "SHELLDLL_DefView", NULL), 0, "SysListView32", NULL);
    RECT rect; GetWindowRect(hd, &rect); return rect.top;
}

HL_PRIM float HL_NAME(set_desktop_alpha)(float alpha) {
    HWND hProgman = FindWindowW(L"Progman", L"Program Manager");
    HWND hChild = GetWindow(hProgman, GW_CHILD);
    float a = alpha > 1 ? 1 : (alpha < 0 ? 0 : alpha);
    SetLayeredWindowAttributes(hChild, 0, (BYTE)(255 * a), LWA_ALPHA);
    return alpha;
}

HL_PRIM float HL_NAME(set_taskbar_alpha)(float alpha) {
    HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
    HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);
    float a = alpha > 1 ? 1 : (alpha < 0 ? 0 : alpha);
    SetLayeredWindowAttributes(hwnd, 0, (BYTE)(255 * a), LWA_ALPHA);
    SetLayeredWindowAttributes(hwnd2, 0, (BYTE)(255 * a), LWA_ALPHA);
    return alpha;
}

HL_PRIM void HL_NAME(set_layered_mode)(int numberMode) {
    HWND window; HWND window2;
    switch (numberMode) {
        case 0: window = GetWindow(FindWindowW(L"Progman", L"Program Manager"), GW_CHILD); break;
        case 1: window = FindWindowA("Shell_traywnd", nullptr); window2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr); break;
    }
    SetWindowLong(window, GWL_EXSTYLE, GetWindowLong(window, GWL_EXSTYLE) ^ WS_EX_LAYERED);
    if (numberMode == 1) SetWindowLong(window2, GWL_EXSTYLE, GetWindowLong(window2, GWL_EXSTYLE) ^ WS_EX_LAYERED);
}

HL_PRIM void HL_NAME(disable_ghosting)() { DisableProcessWindowsGhosting(); }
HL_PRIM void HL_NAME(disable_report)() { SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX); }
HL_PRIM void HL_NAME(set_console_output_to_utf8)() { SetConsoleOutputCP(CP_UTF8); }

// ====================================================================================
// WINDOWS TERMINAL FUNCTIONS
// ====================================================================================

HL_PRIM void HL_NAME(term_clear)() { system("CLS"); std::cout << "" << std::flush; }

HL_PRIM void HL_NAME(term_alloc)() {
    if (!AllocConsole()) return;
    freopen("CONIN$", "r", stdin);
    freopen("CONOUT$", "w", stdout);
    freopen("CONOUT$", "w", stderr);
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    SetConsoleMode(output, ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
}

HL_PRIM void HL_NAME(term_hide_main)() { ShowWindow(GET_MAIN_WINDOW(), SW_HIDE); }
HL_PRIM void HL_NAME(term_set_title)(vstring* text) { SetConsoleTitleW(HL_WSTR(text)); }

HL_PRIM void HL_NAME(term_set_icon)(vstring* path) {
    HWND window = GetConsoleWindow();
    HICON smallIcon = (HICON) LoadImageW(NULL, HL_WSTR(path), IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
    HICON icon = (HICON) LoadImageW(NULL, HL_WSTR(path), IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE);

    SendMessage(window, WM_SETICON, ICON_SMALL, (LPARAM)smallIcon);
    SendMessage(window, WM_SETICON, ICON_BIG, (LPARAM)icon);    
}

HL_PRIM void HL_NAME(term_center)() {
    HWND hwnd = GetConsoleWindow();
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    RECT windowRect; GetWindowRect(hwnd, &windowRect);

    int centerX = (screenWidth - (windowRect.right - windowRect.left)) / 2;
    int centerY = (screenHeight - (windowRect.bottom - windowRect.top)) / 2;
    SetWindowPos(hwnd, NULL, centerX, centerY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
}

HL_PRIM void HL_NAME(term_disable_resize)() {
    HWND hwnd = GetConsoleWindow();

    LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX); 

    SetWindowLongPtrW(hwnd, GWL_STYLE, style);    
}

HL_PRIM void HL_NAME(term_disable_close)() {
    HWND hwnd = GetConsoleWindow();
    HMENU hmenu = GetSystemMenu(hwnd, FALSE);
    EnableMenuItem(hmenu, SC_CLOSE, MF_GRAYED);
}

HL_PRIM void HL_NAME(term_maximize)() { ShowWindow(GetConsoleWindow(), SW_MAXIMIZE); }
HL_PRIM void HL_NAME(term_set_cursor)(int x, int y) { COORD pos = {(SHORT)x, (SHORT)y}; SetConsoleCursorPosition(GetStdHandle(STD_OUTPUT_HANDLE), pos); }
HL_PRIM int HL_NAME(term_get_cursor_x)() { CONSOLE_SCREEN_BUFFER_INFO i; GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &i); return i.dwCursorPosition.X; }
HL_PRIM int HL_NAME(term_get_cursor_y)() { CONSOLE_SCREEN_BUFFER_INFO i; GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &i); return i.dwCursorPosition.Y; }
HL_PRIM void HL_NAME(term_set_pos_x)(int posX) { SetWindowPos(GetConsoleWindow(), NULL, posX, NULL, 0, 0, SWP_NOSIZE | SWP_NOZORDER); }
HL_PRIM void HL_NAME(term_set_pos_y)(int posY) { SetWindowPos(GetConsoleWindow(), NULL, NULL, posY, 0, 0, SWP_NOSIZE | SWP_NOZORDER); }
HL_PRIM int HL_NAME(term_get_width)() { RECT r; GetWindowRect(GetConsoleWindow(), &r); return r.right - r.left; }
HL_PRIM int HL_NAME(term_get_height)() { RECT r; GetWindowRect(GetConsoleWindow(), &r); return r.bottom - r.top; }
HL_PRIM int HL_NAME(term_get_pos_x)() { RECT r; GetWindowRect(GetConsoleWindow(), &r); return r.left; }
HL_PRIM int HL_NAME(term_get_pos_y)() { RECT r; GetWindowRect(GetConsoleWindow(), &r); return r.top; }
HL_PRIM void HL_NAME(term_hide)() { ShowWindow(GetConsoleWindow(), SW_HIDE); }

// ====================================================================================
// WINDOWS GDI FUNCTIONS
// ====================================================================================

static float elapsedTime = 0;

HL_PRIM void HL_NAME(gdi_set_time)(float elapsed) { elapsedTime = elapsed; }

HL_PRIM void HL_NAME(gdi_draw_icons)() {
	int ix = GetSystemMetrics(SM_CXICON) / 2;
	int iy = GetSystemMetrics(SM_CYICON) / 2;
	HWND hwnd = GetDesktopWindow();
	HDC hdc = GetWindowDC(hwnd);
	POINT cursor; GetCursorPos(&cursor);
	DrawIcon(hdc, cursor.x - ix, cursor.y - iy, LoadIcon(NULL, IDI_ERROR));
	if (rand() % (int)(10 / (elapsedTime / 500.0 + 1) + 1) == 0) {
		DrawIcon(hdc, rand() % GetSystemMetrics(SM_CXSCREEN), rand() % GetSystemMetrics(SM_CYSCREEN), LoadIcon(NULL, IDI_WARNING));
	}
	ReleaseDC(hwnd, hdc);
}

HL_PRIM void HL_NAME(gdi_blink)() {
	HWND hwnd = GetDesktopWindow();
	HDC hdc = GetWindowDC(hwnd);
	RECT rekt; GetWindowRect(hwnd, &rekt);
	BitBlt(hdc, 0, 0, rekt.right - rekt.left, rekt.bottom - rekt.top, hdc, 0, 0, NOTSRCCOPY);
	ReleaseDC(hwnd, hdc);
}

HL_PRIM void HL_NAME(gdi_glitch)() {
	HWND hwnd = GetDesktopWindow();
	HDC hdc = GetWindowDC(hwnd);
	RECT rekt; GetWindowRect(hwnd, &rekt);
	int x1 = rand() % (rekt.right - 100);
	int y1 = rand() % (rekt.bottom - 100);
	int x2 = rand() % (rekt.right - 100);
	int y2 = rand() % (rekt.bottom - 100);
	int width = rand() % 600;
	int height = rand() % 600;
	BitBlt(hdc, x1, y1, width, height, hdc, x2, y2, SRCCOPY);
	ReleaseDC(hwnd, hdc);
}

HL_PRIM void HL_NAME(gdi_tunnel)() {
	HWND hwnd = GetDesktopWindow();
	HDC hdc = GetWindowDC(hwnd);
	RECT rekt; GetWindowRect(hwnd, &rekt);
	StretchBlt(hdc, 50, 50, rekt.right - 100, rekt.bottom - 100, hdc, 0, 0, rekt.right, rekt.bottom, SRCCOPY);
	ReleaseDC(hwnd, hdc);
}

HL_PRIM void HL_NAME(gdi_shake)() {
	HDC hdc = GetDC(0);
	int w = GetSystemMetrics(0);
	int h = GetSystemMetrics(1);
	BitBlt(hdc, rand() % 2, rand() % 2, w, h, hdc, rand() % 2, rand() % 2, SRCCOPY);
	Sleep(10);
	ReleaseDC(0, hdc);
}

BOOL CALLBACK EnumChildProcW(HWND hwnd, LPARAM lParam) {
    SendMessageTimeoutW(hwnd, WM_SETTEXT, NULL, lParam, SMTO_ABORTIFHUNG, 0, NULL);
    return TRUE;
}

HL_PRIM void HL_NAME(gdi_set_title)(vstring* text) {
    EnumChildWindows(GetDesktopWindow(), EnumChildProcW, (LPARAM)HL_WSTR(text));
}

DEFINE_PRIM(_VOID, show_message_box, _STRING _STRING _I32 _I32);
DEFINE_PRIM(_VOID, show_scrollable_message, _STRING _STRING);
DEFINE_PRIM(_VOID, set_window_visible, _BOOL);
DEFINE_PRIM(_I32, get_windows_transparent, _I32);
DEFINE_PRIM(_I32, disable_window_transparent, _I32);
DEFINE_PRIM(_VOID, set_window_border_color, _I32 _I32 _I32);
DEFINE_PRIM(_VOID, set_window_layered, _NO_ARG);
DEFINE_PRIM(_F32, set_window_alpha, _F32);
DEFINE_PRIM(_F32, get_window_alpha, _NO_ARG);
DEFINE_PRIM(_VOID, center_window, _NO_ARG);
DEFINE_PRIM(_I32, get_cursor_x, _NO_ARG);
DEFINE_PRIM(_I32, get_cursor_y, _NO_ARG);
DEFINE_PRIM(_BOOL, is_admin, _NO_ARG);
DEFINE_PRIM(_VOID, screen_shot, _STRING);
DEFINE_PRIM(_STRING, obtain_ram, _BOOL);
DEFINE_PRIM(_VOID, hide_taskbar, _BOOL);
DEFINE_PRIM(_VOID, set_wallpaper, _STRING);
DEFINE_PRIM(_VOID, hide_desktop_icons, _BOOL);
DEFINE_PRIM(_VOID, move_desktop_x, _I32);
DEFINE_PRIM(_VOID, move_desktop_y, _I32);
DEFINE_PRIM(_VOID, move_desktop_xy, _I32 _I32);
DEFINE_PRIM(_I32, get_desktop_x, _NO_ARG);
DEFINE_PRIM(_I32, get_desktop_y, _NO_ARG);
DEFINE_PRIM(_F32, set_desktop_alpha, _F32);
DEFINE_PRIM(_F32, set_taskbar_alpha, _F32);
DEFINE_PRIM(_VOID, set_layered_mode, _I32);
DEFINE_PRIM(_VOID, disable_ghosting, _NO_ARG);
DEFINE_PRIM(_VOID, disable_report, _NO_ARG);
DEFINE_PRIM(_VOID, set_console_output_to_utf8, _NO_ARG);

DEFINE_PRIM(_VOID, term_clear, _NO_ARG);
DEFINE_PRIM(_VOID, term_alloc, _NO_ARG);
DEFINE_PRIM(_VOID, term_hide_main, _NO_ARG);
DEFINE_PRIM(_VOID, term_set_title, _STRING);
DEFINE_PRIM(_VOID, term_set_icon, _STRING);
DEFINE_PRIM(_VOID, term_center, _NO_ARG);
DEFINE_PRIM(_VOID, term_disable_resize, _NO_ARG);
DEFINE_PRIM(_VOID, term_disable_close, _NO_ARG);
DEFINE_PRIM(_VOID, term_maximize, _NO_ARG);
DEFINE_PRIM(_VOID, term_set_cursor, _I32 _I32);
DEFINE_PRIM(_I32, term_get_cursor_x, _NO_ARG);
DEFINE_PRIM(_I32, term_get_cursor_y, _NO_ARG);
DEFINE_PRIM(_VOID, term_set_pos_x, _I32);
DEFINE_PRIM(_VOID, term_set_pos_y, _I32);
DEFINE_PRIM(_I32, term_get_width, _NO_ARG);
DEFINE_PRIM(_I32, term_get_height, _NO_ARG);
DEFINE_PRIM(_I32, term_get_pos_x, _NO_ARG);
DEFINE_PRIM(_I32, term_get_pos_y, _NO_ARG);
DEFINE_PRIM(_VOID, term_hide, _NO_ARG);

DEFINE_PRIM(_VOID, gdi_set_time, _F32);
DEFINE_PRIM(_VOID, gdi_draw_icons, _NO_ARG);
DEFINE_PRIM(_VOID, gdi_blink, _NO_ARG);
DEFINE_PRIM(_VOID, gdi_glitch, _NO_ARG);
DEFINE_PRIM(_VOID, gdi_tunnel, _NO_ARG);
DEFINE_PRIM(_VOID, gdi_shake, _NO_ARG);
DEFINE_PRIM(_VOID, gdi_set_title, _STRING);