/* SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE-EXCEPTION.md for the additional permission.
 *
 * Minimal, source-built D3D12 startup probe. It opens only the Wine system
 * D3D12 DLL, creates one device, displays the result, and releases it.
 * It does not use a network, inspect user data, create files, or run a game.
 */
#define COBJMACROS
#define INITGUID
#include <initguid.h>
#include <windows.h>
#include <d3d12.h>
#include <stdio.h>

typedef HRESULT (WINAPI *create_device_fn)(IUnknown *, D3D_FEATURE_LEVEL, REFIID, void **);

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show)
{
    (void)instance;
    (void)previous;
    (void)command_line;
    (void)show;

    char message[256];
    HMODULE module = LoadLibraryA("C:\\windows\\system32\\d3d12.dll");
    if (!module) {
        snprintf(message, sizeof message, "FAIL: d3d12.dll could not load (Windows error %lu).",
                 (unsigned long)GetLastError());
        MessageBoxA(NULL, message, "GalacWin D3D12 device probe", MB_OK | MB_ICONERROR);
        return 1;
    }

    create_device_fn create_device =
        (create_device_fn)GetProcAddress(module, "D3D12CreateDevice");
    if (!create_device) {
        MessageBoxA(NULL, "FAIL: D3D12CreateDevice is missing.",
                    "GalacWin D3D12 device probe", MB_OK | MB_ICONERROR);
        FreeLibrary(module);
        return 1;
    }

    ID3D12Device *device = NULL;
    HRESULT result = create_device(NULL, D3D_FEATURE_LEVEL_11_0,
                                   &IID_ID3D12Device, (void **)&device);
    if (FAILED(result) || !device) {
        snprintf(message, sizeof message,
                 "FAIL: D3D12CreateDevice returned 0x%08lx.",
                 (unsigned long)(unsigned int)result);
        MessageBoxA(NULL, message, "GalacWin D3D12 device probe", MB_OK | MB_ICONERROR);
        if (device) ID3D12Device_Release(device);
        FreeLibrary(module);
        return 1;
    }

    ID3D12Device_Release(device);
    FreeLibrary(module);
    MessageBoxA(NULL,
                "PASS: a Direct3D 12 device was created. Game rendering and compatibility are untested.",
                "GalacWin D3D12 device probe", MB_OK | MB_ICONINFORMATION);
    return 0;
}
