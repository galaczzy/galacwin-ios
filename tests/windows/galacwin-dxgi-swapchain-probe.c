/* SPDX-License-Identifier: GPL-3.0-or-later
 * See LICENSE-GALACWIN-EXCEPTION.md for the additional permission.
 *
 * Isolated DXGI/D3D12 presentation check. Loads only the Wine system D3D12
 * and DXGI DLLs, creates a 640x480 window, clears one swapchain buffer to
 * cyan and presents it. No network, game, account or file access.
 */
#define COBJMACROS
#define INITGUID
#include <initguid.h>
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <stdio.h>

typedef HRESULT (WINAPI *create_device_fn)(IUnknown *, D3D_FEATURE_LEVEL, REFIID, void **);
typedef HRESULT (WINAPI *create_factory_fn)(REFIID, void **);

static int fail(const char *stage, HRESULT hr)
{
    char message[256];
    snprintf(message, sizeof message, "%s: 0x%08lx", stage, (unsigned long)(unsigned int)hr);
    printf("dxgi-probe: FAIL %s\n", message);
    fflush(stdout);
    MessageBoxA(NULL, message, "GalacWin DXGI probe", MB_OK | MB_ICONERROR);
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
    HMODULE d3d12_dll = LoadLibraryA("C:\\windows\\system32\\d3d12.dll");
    if (!d3d12_dll) return fail("Load d3d12.dll", HRESULT_FROM_WIN32(GetLastError()));
    HMODULE dxgi_dll = LoadLibraryA("C:\\windows\\system32\\dxgi.dll");
    if (!dxgi_dll) return fail("Load dxgi.dll", HRESULT_FROM_WIN32(GetLastError()));
    create_device_fn create_device = (create_device_fn)GetProcAddress(d3d12_dll, "D3D12CreateDevice");
    create_factory_fn create_factory = (create_factory_fn)GetProcAddress(dxgi_dll, "CreateDXGIFactory1");
    if (!create_device || !create_factory) return fail("Required DLL export", E_NOTIMPL);

    WNDCLASSA window_class = {0};
    window_class.lpfnWndProc = window_proc;
    window_class.hInstance = instance;
    window_class.lpszClassName = "GalacWinDXGIProbe";
    if (!RegisterClassA(&window_class))
        return fail("RegisterClass", HRESULT_FROM_WIN32(GetLastError()));
    HWND hwnd = CreateWindowExA(0, window_class.lpszClassName, "GalacWin DXGI test: CYAN",
                                WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                                660, 520, NULL, NULL, instance, NULL);
    if (!hwnd) return fail("CreateWindow", HRESULT_FROM_WIN32(GetLastError()));
    ShowWindow(hwnd, show ? show : SW_SHOW);
    UpdateWindow(hwnd);

    ID3D12Device *device = NULL;
    HRESULT hr = create_device(NULL, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device,
                               (void **)&device);
    if (FAILED(hr) || !device) return fail("D3D12CreateDevice", hr);
    IDXGIFactory2 *factory = NULL;
    hr = create_factory(&IID_IDXGIFactory2, (void **)&factory);
    if (FAILED(hr) || !factory) return fail("CreateDXGIFactory1", hr);

    D3D12_COMMAND_QUEUE_DESC queue_desc = {0};
    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    ID3D12CommandQueue *queue = NULL;
    hr = ID3D12Device_CreateCommandQueue(device, &queue_desc, &IID_ID3D12CommandQueue,
                                          (void **)&queue);
    if (FAILED(hr) || !queue) return fail("CreateCommandQueue", hr);

    DXGI_SWAP_CHAIN_DESC1 swap_desc = {0};
    swap_desc.Width = 640;
    swap_desc.Height = 480;
    swap_desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    swap_desc.Stereo = FALSE;
    swap_desc.SampleDesc.Count = 1;
    swap_desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swap_desc.BufferCount = 2;
    swap_desc.Scaling = DXGI_SCALING_STRETCH;
    swap_desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swap_desc.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
    IDXGISwapChain1 *swap1 = NULL;
    hr = IDXGIFactory2_CreateSwapChainForHwnd(factory, (IUnknown *)queue, hwnd,
                                               &swap_desc, NULL, NULL, &swap1);
    if (FAILED(hr) || !swap1) return fail("CreateSwapChainForHwnd", hr);
    IDXGISwapChain3 *swap3 = NULL;
    hr = IDXGISwapChain1_QueryInterface(swap1, &IID_IDXGISwapChain3, (void **)&swap3);
    if (FAILED(hr) || !swap3) return fail("QueryInterface SwapChain3", hr);

    UINT back_index = IDXGISwapChain3_GetCurrentBackBufferIndex(swap3);
    ID3D12Resource *back = NULL;
    hr = IDXGISwapChain3_GetBuffer(swap3, back_index, &IID_ID3D12Resource, (void **)&back);
    if (FAILED(hr) || !back) return fail("GetBuffer", hr);
    D3D12_DESCRIPTOR_HEAP_DESC heap_desc = {0};
    heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    heap_desc.NumDescriptors = 1;
    ID3D12DescriptorHeap *heap = NULL;
    hr = ID3D12Device_CreateDescriptorHeap(device, &heap_desc, &IID_ID3D12DescriptorHeap,
                                            (void **)&heap);
    if (FAILED(hr) || !heap) return fail("CreateDescriptorHeap", hr);
    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap, &rtv);
    ID3D12Device_CreateRenderTargetView(device, back, NULL, rtv);

    ID3D12CommandAllocator *allocator = NULL;
    hr = ID3D12Device_CreateCommandAllocator(device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                              &IID_ID3D12CommandAllocator, (void **)&allocator);
    if (FAILED(hr) || !allocator) return fail("CreateCommandAllocator", hr);
    ID3D12GraphicsCommandList *list = NULL;
    hr = ID3D12Device_CreateCommandList(device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator,
                                        NULL, &IID_ID3D12GraphicsCommandList, (void **)&list);
    if (FAILED(hr) || !list) return fail("CreateCommandList", hr);

    D3D12_RESOURCE_BARRIER barrier = {0};
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = back;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
    ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    ID3D12GraphicsCommandList_OMSetRenderTargets(list, 1, &rtv, FALSE, NULL);
    const FLOAT cyan[4] = {0.0f, 0.85f, 1.0f, 1.0f};
    ID3D12GraphicsCommandList_ClearRenderTargetView(list, rtv, cyan, 0, NULL);
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
    ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    hr = ID3D12GraphicsCommandList_Close(list);
    if (FAILED(hr)) return fail("CloseCommandList", hr);
    ID3D12CommandList *lists[] = {(ID3D12CommandList *)list};
    ID3D12CommandQueue_ExecuteCommandLists(queue, 1, lists);
    hr = IDXGISwapChain3_Present(swap3, 1, 0);
    if (FAILED(hr)) return fail("Present", hr);
    printf("dxgi-probe: PASS DXGI Present returned S_OK\n");
    fflush(stdout);

    ULONGLONG until = GetTickCount64() + 12000;
    while (GetTickCount64() < until) {
        MSG message;
        while (PeekMessageA(&message, NULL, 0, 0, PM_REMOVE)) {
            if (message.message == WM_QUIT) goto finished;
            TranslateMessage(&message);
            DispatchMessageA(&message);
        }
        Sleep(16);
    }
finished:
    ID3D12GraphicsCommandList_Release(list);
    ID3D12CommandAllocator_Release(allocator);
    ID3D12DescriptorHeap_Release(heap);
    ID3D12Resource_Release(back);
    IDXGISwapChain3_Release(swap3);
    IDXGISwapChain1_Release(swap1);
    ID3D12CommandQueue_Release(queue);
    IDXGIFactory2_Release(factory);
    ID3D12Device_Release(device);
    DestroyWindow(hwnd);
    FreeLibrary(dxgi_dll);
    FreeLibrary(d3d12_dll);
    return 0;
}
