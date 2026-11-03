/* SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE-GALACWIN-EXCEPTION.md for the additional permission.
 *
 * Isolated presentation probe: clear a 640x480 D3D12 drawable to magenta.
 * It uses the existing Madeira test presenter, with no shader or game data.
 * No network, file or account access. Close the window to stop it.
 */
#define COBJMACROS
#define INITGUID
#include <initguid.h>
#include <windows.h>
#include <d3d12.h>
#include <stdio.h>

typedef HRESULT (WINAPI *create_device_fn)(IUnknown *, D3D_FEATURE_LEVEL, REFIID, void **);
typedef void *(*presenter_create_fn)(ID3D12Device *, intptr_t, UINT, UINT);
typedef ID3D12Resource *(*presenter_acquire_fn)(void *);
typedef void (*presenter_present_fn)(void *, ID3D12CommandQueue *);
typedef void (*presenter_destroy_fn)(void *);

static int report(const char *stage, HRESULT hr)
{
    char text[256];
    snprintf(text, sizeof text, "%s: 0x%08lx", stage, (unsigned long)(unsigned int)hr);
    MessageBoxA(NULL, text, "GalacWin D3D12 clear probe", MB_OK | MB_ICONERROR);
    printf("clear-probe: %s\n", text);
    fflush(stdout);
    return 1;
}

static LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
{
    if (message == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcA(hwnd, message, wparam, lparam);
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show)
{
    (void)previous;
    (void)command_line;
    HMODULE module = LoadLibraryA("madeira_d3d12.dll");
    if (!module) return report("LoadLibrary madeira_d3d12.dll", HRESULT_FROM_WIN32(GetLastError()));
    create_device_fn create_device = (create_device_fn)GetProcAddress(module, "MadeiraD3D12CreateDevice");
    presenter_create_fn presenter_create =
        (presenter_create_fn)GetProcAddress(module, "MadeiraD3D12PresenterCreate");
    presenter_acquire_fn presenter_acquire =
        (presenter_acquire_fn)GetProcAddress(module, "MadeiraD3D12PresenterAcquire");
    presenter_present_fn presenter_present =
        (presenter_present_fn)GetProcAddress(module, "MadeiraD3D12PresenterPresent");
    presenter_destroy_fn presenter_destroy =
        (presenter_destroy_fn)GetProcAddress(module, "MadeiraD3D12PresenterDestroy");
    if (!create_device || !presenter_create || !presenter_acquire ||
        !presenter_present || !presenter_destroy)
        return report("Missing presenter export", E_NOTIMPL);

    WNDCLASSA window_class = {0};
    window_class.lpfnWndProc = window_proc;
    window_class.hInstance = instance;
    window_class.lpszClassName = "GalacWinD3D12ClearProbe";
    if (!RegisterClassA(&window_class))
        return report("RegisterClass", HRESULT_FROM_WIN32(GetLastError()));
    HWND hwnd = CreateWindowExA(0, window_class.lpszClassName,
                                "GalacWin D3D12 clear test: MAGENTA",
                                WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                                660, 520, NULL, NULL, instance, NULL);
    if (!hwnd) return report("CreateWindow", HRESULT_FROM_WIN32(GetLastError()));
    ShowWindow(hwnd, show ? show : SW_SHOW);
    UpdateWindow(hwnd);

    ID3D12Device *device = NULL;
    HRESULT hr = create_device(NULL, D3D_FEATURE_LEVEL_11_0,
                               &IID_ID3D12Device, (void **)&device);
    if (FAILED(hr) || !device) return report("CreateDevice", hr);
    D3D12_COMMAND_QUEUE_DESC queue_desc = {0};
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    ID3D12CommandQueue *queue = NULL;
    hr = ID3D12Device_CreateCommandQueue(device, &queue_desc,
                                          &IID_ID3D12CommandQueue, (void **)&queue);
    if (FAILED(hr) || !queue) return report("CreateCommandQueue", hr);
    ID3D12CommandAllocator *allocator = NULL;
    hr = ID3D12Device_CreateCommandAllocator(device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                              &IID_ID3D12CommandAllocator, (void **)&allocator);
    if (FAILED(hr) || !allocator) return report("CreateCommandAllocator", hr);
    ID3D12GraphicsCommandList *list = NULL;
    hr = ID3D12Device_CreateCommandList(device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                        allocator, NULL, &IID_ID3D12GraphicsCommandList,
                                        (void **)&list);
    if (FAILED(hr) || !list) return report("CreateCommandList", hr);
    hr = ID3D12GraphicsCommandList_Close(list);
    if (FAILED(hr)) return report("CloseCommandList", hr);
    D3D12_DESCRIPTOR_HEAP_DESC heap_desc = {0};
    heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    heap_desc.NumDescriptors = 1;
    ID3D12DescriptorHeap *heap = NULL;
    hr = ID3D12Device_CreateDescriptorHeap(device, &heap_desc,
                                            &IID_ID3D12DescriptorHeap, (void **)&heap);
    if (FAILED(hr) || !heap) return report("CreateDescriptorHeap", hr);
    ID3D12Fence *fence = NULL;
    hr = ID3D12Device_CreateFence(device, 0, D3D12_FENCE_FLAG_NONE,
                                  &IID_ID3D12Fence, (void **)&fence);
    if (FAILED(hr) || !fence) return report("CreateFence", hr);
    HANDLE event = CreateEventA(NULL, FALSE, FALSE, NULL);
    if (!event) return report("CreateEvent", HRESULT_FROM_WIN32(GetLastError()));
    void *presenter = presenter_create(device, (intptr_t)hwnd, 640, 480);
    if (!presenter) return report("PresenterCreate", E_FAIL);

    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(heap, &rtv);
    const FLOAT magenta[4] = {1.0f, 0.0f, 1.0f, 1.0f};
    UINT64 fence_value = 0;
    unsigned int frames = 0;
    ULONGLONG last_drawable = GetTickCount64();
    BOOL running = TRUE;
    while (running) {
        MSG message;
        while (PeekMessageA(&message, NULL, 0, 0, PM_REMOVE)) {
            if (message.message == WM_QUIT) {
                running = FALSE;
                break;
            }
            TranslateMessage(&message);
            DispatchMessageA(&message);
        }
        if (!running) break;
        ID3D12Resource *back = presenter_acquire(presenter);
        if (!back) {
            if (GetTickCount64() - last_drawable > 10000)
                return report("PresenterAcquire", E_FAIL);
            Sleep(16);
            continue;
        }
        last_drawable = GetTickCount64();
        ID3D12Device_CreateRenderTargetView(device, back, NULL, rtv);
        hr = ID3D12GraphicsCommandList_Reset(list, allocator, NULL);
        if (FAILED(hr)) return report("ResetCommandList", hr);
        ID3D12GraphicsCommandList_OMSetRenderTargets(list, 1, &rtv, FALSE, NULL);
        ID3D12GraphicsCommandList_ClearRenderTargetView(list, rtv, magenta, 0, NULL);
        hr = ID3D12GraphicsCommandList_Close(list);
        if (FAILED(hr)) return report("CloseCommandList", hr);
        ID3D12CommandList *lists[] = {(ID3D12CommandList *)list};
        ID3D12CommandQueue_ExecuteCommandLists(queue, 1, lists);
        presenter_present(presenter, queue);
        hr = ID3D12CommandQueue_Signal(queue, fence, ++fence_value);
        if (FAILED(hr)) return report("SignalFence", hr);
        hr = ID3D12Fence_SetEventOnCompletion(fence, fence_value, event);
        if (FAILED(hr) || WaitForSingleObject(event, 5000) != WAIT_OBJECT_0)
            return report("WaitForFence", FAILED(hr) ? hr : E_FAIL);
        hr = ID3D12CommandAllocator_Reset(allocator);
        if (FAILED(hr)) return report("ResetAllocator", hr);
        if (++frames == 1 || frames % 120 == 0) {
            printf("clear-probe: %u magenta frames submitted\n", frames);
            fflush(stdout);
        }
    }

    presenter_destroy(presenter);
    CloseHandle(event);
    ID3D12Fence_Release(fence);
    ID3D12DescriptorHeap_Release(heap);
    ID3D12GraphicsCommandList_Release(list);
    ID3D12CommandAllocator_Release(allocator);
    ID3D12CommandQueue_Release(queue);
    ID3D12Device_Release(device);
    DestroyWindow(hwnd);
    FreeLibrary(module);
    return 0;
}
