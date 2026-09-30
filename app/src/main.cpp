#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi1_2.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>

#include "core/poi_evidence.h"
#include "core/locator_model.h"
#include "core/monitor_registry.h"
#include "core/topology_reconciler.h"
#include "core/viewport_policy.h"
#include "core/view_controller.h"
#include "core/view_state.h"
#include "core/view_update_step.h"
#include "core/workspace_coordinator.h"
#include "core/workspace_runtime_graph.h"
#include "core/settings_model.h"
#include "settings_store.h"
#include "settings_window.h"
#include "context_overlay.h"
#include "help_window.h"
#include "hint_window.h"
#include "core/help_catalog.h"
#include "tracking/win32_evidence_provider.h"
#include "tracking/uia_evidence_provider.h"
#include "tracking/evidence_sampler.h"
#include "tracking/evidence_hub.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

using winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool;
using winrt::Windows::Graphics::Capture::GraphicsCaptureItem;
using winrt::Windows::Graphics::Capture::GraphicsCaptureSession;
using winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DDevice;
using winrt::Windows::Graphics::DirectX::DirectXPixelFormat;
using AbiDxgiInterfaceAccess = Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess;

namespace {

constexpr wchar_t kWindowClass[] = L"VisualDetailWindow";
constexpr UINT kCaptureErrorMessage = WM_APP + 1;
constexpr UINT kCaptureSourceClosedMessage = WM_APP + 2;
constexpr UINT kContextViewChangedMessage = WM_APP + 3;
constexpr DWORD kExcludeFromCapture = 0x00000011;

enum class ShutdownReason : int {
    User = 0,
    CaptureFailure = 1,
    CaptureSourceClosed = 2,
    DisplayTopologyChanged = 3,
};

std::atomic<int> g_shutdownReason{static_cast<int>(ShutdownReason::User)};
std::atomic<double> g_zoom{2.0};
std::atomic<double> g_previousMagnifiedZoom{2.0};
std::atomic<bool> g_trackingEnabled{true};
std::atomic<bool> g_followPointer{true};
std::atomic<bool> g_followCaret{true};
std::atomic<bool> g_followFocus{true};
std::atomic<bool> g_showPointerLocator{true};
std::atomic<bool> g_showCaretLocator{true};
std::atomic<bool> g_showFocusLocator{true};
std::atomic<bool> g_showContextIndicator{true};
std::atomic<bool> g_shadeContextIndicator{true};
std::atomic<int> g_visualMode{static_cast<int>(visual::core::VisualMode::Normal)};
std::atomic<bool> g_captureFailed{false};
std::atomic<bool> g_healthCheckMode{false};
std::mutex g_settingsMutex;
std::atomic<std::uint64_t> g_selectedViewId{visual::core::kCurrentDetailViewId.value};
visual::core::VisualSettings g_settings{};
std::filesystem::path g_settingsPath{};
visual::ui::SettingsWindow* g_settingsWindow{};
visual::ui::ContextOverlay* g_contextOverlay{};
visual::ui::HelpWindow* g_helpWindow{};
visual::ui::HintWindow* g_hintWindow{};
std::mutex g_assistanceMutex;
visual::settings::AssistanceState g_assistanceState{};

struct PendingContextView {
    visual::core::ScreenRect viewport{};
    double zoom{1.0};
};
std::mutex g_contextViewMutex;
PendingContextView g_pendingContextView{};
std::atomic<bool> g_contextViewMessagePending{false};

struct MonitorRecord {
    HMONITOR handle{};
    RECT rect{};
    bool primary{};
    std::wstring deviceName;
    DEVMODEW mode{};
    UINT dpiX{96};
    UINT dpiY{96};
};

struct Options {
    int sourceIndex{-1};
    int destIndex{-1};
    double zoom{2.0};
    bool zoomSpecified{false};
    bool forceSingleMonitor{false};
    bool healthCheck{false};
    bool topologyReconcileSelfTest{false};
    bool fanoutSelfTest{false};
    bool multiSourceSelfTest{false};
    int healthTimeoutMs{7000};
    int reconstructionMode{0}; // engineering-only: 0 bilinear, 1 Catmull-Rom, 2 Lanczos2, 3 adaptive sharpen
    std::filesystem::path logPath{L"visual_app_telemetry.csv"};
};

struct WindowPlacement {
    HWND hwnd{};
    UINT width{};
    UINT height{};
    bool singleMonitor{};
    bool excludedFromCapture{};
};

struct Vertex { float x, y, u, v; };
struct RenderConstants {
    float uvScale[2];
    float uvOffset[2];
    float locatorRect[4];
    float outputSize[2];
    float locatorVisible;
    float locatorKind;
    float visualMode;
    float reconstructionMode;
    float padding[2];
};
static_assert((sizeof(RenderConstants) % 16) == 0);

LARGE_INTEGER qpc_now() { LARGE_INTEGER v{}; QueryPerformanceCounter(&v); return v; }
LARGE_INTEGER qpc_frequency() { LARGE_INTEGER v{}; QueryPerformanceFrequency(&v); return v; }

std::wstring format_hr(HRESULT hr) {
    wchar_t buffer[32]{};
    swprintf_s(buffer, L"0x%08X", static_cast<unsigned>(hr));
    return buffer;
}

BOOL CALLBACK monitor_enum_proc(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
    auto* monitors = reinterpret_cast<std::vector<MonitorRecord>*>(data);
    MONITORINFOEXW info{};
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(monitor, &info)) return TRUE;

    MonitorRecord record{};
    record.handle = monitor;
    record.rect = info.rcMonitor;
    record.primary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
    record.deviceName = info.szDevice;
    record.mode.dmSize = sizeof(record.mode);
    EnumDisplaySettingsExW(record.deviceName.c_str(), ENUM_CURRENT_SETTINGS, &record.mode, 0);
    if (HMODULE shcore = LoadLibraryW(L"shcore.dll")) {
        using GetDpiForMonitorFn = HRESULT(WINAPI*)(HMONITOR, int, UINT*, UINT*);
        if (auto getDpi = reinterpret_cast<GetDpiForMonitorFn>(GetProcAddress(shcore, "GetDpiForMonitor"))) {
            (void)getDpi(monitor, 0, &record.dpiX, &record.dpiY);
        }
        FreeLibrary(shcore);
    }
    monitors->push_back(std::move(record));
    return TRUE;
}

std::vector<MonitorRecord> enumerate_monitors() {
    std::vector<MonitorRecord> monitors;
    EnumDisplayMonitors(nullptr, nullptr, monitor_enum_proc, reinterpret_cast<LPARAM>(&monitors));
    return monitors;
}

Options parse_options() {
    Options options{};
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv) return options;
    for (int i = 1; i < argc; ++i) {
        const std::wstring arg = argv[i];
        auto next_value = [&]() -> std::wstring {
            if (i + 1 >= argc) throw std::runtime_error("Missing command-line value");
            return argv[++i];
        };
        if (arg == L"--source") options.sourceIndex = std::stoi(next_value());
        else if (arg == L"--dest") options.destIndex = std::stoi(next_value());
        else if (arg == L"--zoom") { options.zoom = std::stod(next_value()); options.zoomSpecified = true; }
        else if (arg == L"--log") options.logPath = next_value();
        else if (arg == L"--single-monitor") options.forceSingleMonitor = true;
        else if (arg == L"--health-check") options.healthCheck = true;
        else if (arg == L"--topology-reconcile-self-test") { options.healthCheck = true; options.topologyReconcileSelfTest = true; }
        else if (arg == L"--fanout-self-test") { options.healthCheck = true; options.fanoutSelfTest = true; }
        else if (arg == L"--multisource-self-test") { options.healthCheck = true; options.multiSourceSelfTest = true; }
        else if (arg == L"--health-timeout-ms") options.healthTimeoutMs = std::stoi(next_value());
        else if (arg == L"--reconstruction") options.reconstructionMode = std::clamp(std::stoi(next_value()), 0, 3);
    }
    LocalFree(argv);
    options.zoom = visual::core::sanitize_zoom(options.zoom);
    options.healthTimeoutMs = std::clamp(options.healthTimeoutMs, 1000, 30000);
    return options;
}

[[nodiscard]] visual::core::ViewId selected_view_id() noexcept {
    return {g_selectedViewId.load(std::memory_order_relaxed)};
}

[[nodiscard]] visual::core::ViewState current_detail_view_snapshot(
    const visual::core::VisualSettings& legacy) noexcept {
    auto view = visual::core::detail_view_from_legacy_settings(legacy);
    view.id = selected_view_id();
    view.zoom = g_zoom.load(std::memory_order_relaxed);
    view.tracking_enabled = g_trackingEnabled.load(std::memory_order_relaxed);
    view.follow_pointer = g_followPointer.load(std::memory_order_relaxed);
    view.follow_caret = g_followCaret.load(std::memory_order_relaxed);
    view.follow_focus = g_followFocus.load(std::memory_order_relaxed);
    view.show_pointer_locator = g_showPointerLocator.load(std::memory_order_relaxed);
    view.show_caret_locator = g_showCaretLocator.load(std::memory_order_relaxed);
    view.show_focus_locator = g_showFocusLocator.load(std::memory_order_relaxed);
    view.visual_mode = visual::core::sanitize_visual_mode(g_visualMode.load(std::memory_order_relaxed));
    return view;
}

visual::core::VisualSettings runtime_settings_snapshot() noexcept {
    visual::core::VisualSettings settings{};
    {
        std::scoped_lock lock(g_settingsMutex);
        settings = g_settings;
    }
    settings = visual::core::apply_detail_view_to_legacy_settings(current_detail_view_snapshot(settings), settings);
    settings.show_context_indicator = g_showContextIndicator.load(std::memory_order_relaxed);
    settings.shade_context_indicator = g_shadeContextIndicator.load(std::memory_order_relaxed);
    return settings;
}

void apply_runtime_settings(const visual::core::VisualSettings& settings) noexcept {
    const double zoom = visual::core::sanitize_zoom(settings.zoom);
    g_zoom.store(zoom, std::memory_order_relaxed);
    if (zoom > 1.0) g_previousMagnifiedZoom.store(zoom, std::memory_order_relaxed);
    g_trackingEnabled.store(settings.tracking_enabled, std::memory_order_relaxed);
    g_followPointer.store(settings.follow_pointer, std::memory_order_relaxed);
    g_followCaret.store(settings.follow_caret, std::memory_order_relaxed);
    g_followFocus.store(settings.follow_focus, std::memory_order_relaxed);
    g_showPointerLocator.store(settings.show_pointer_locator, std::memory_order_relaxed);
    g_showCaretLocator.store(settings.show_caret_locator, std::memory_order_relaxed);
    g_showFocusLocator.store(settings.show_focus_locator, std::memory_order_relaxed);
    g_showContextIndicator.store(settings.show_context_indicator, std::memory_order_relaxed);
    g_shadeContextIndicator.store(settings.shade_context_indicator, std::memory_order_relaxed);
    g_visualMode.store(static_cast<int>(settings.visual_mode), std::memory_order_relaxed);
}

void persist_current_settings() noexcept {
    try {
        visual::core::VisualSettings copy{};
        std::filesystem::path path;
        {
            std::scoped_lock lock(g_settingsMutex);
            copy = g_settings;
            path = g_settingsPath;
        }
        if (!path.empty()) (void)visual::settings::save_settings(path, copy);
    } catch (...) {}
}

enum class AssistanceHint {
    ScreenRoles,
    OneXReturn,
};

void persist_assistance_state() noexcept {
    try {
        visual::settings::AssistanceState copy{};
        std::filesystem::path path;
        {
            std::scoped_lock lock(g_assistanceMutex);
            copy = g_assistanceState;
            path = g_settingsPath;
        }
        if (!path.empty()) (void)visual::settings::save_assistance_state(path, copy);
    } catch (...) {}
}

bool claim_assistance_hint(AssistanceHint hint) noexcept {
    bool claimed = false;
    {
        std::scoped_lock lock(g_assistanceMutex);
        switch (hint) {
        case AssistanceHint::ScreenRoles:
            if (!g_assistanceState.screen_roles_explained || !g_assistanceState.view_locator_explained) {
                g_assistanceState.screen_roles_explained = true;
                g_assistanceState.view_locator_explained = true;
                claimed = true;
            }
            break;
        case AssistanceHint::OneXReturn:
            if (!g_assistanceState.one_x_return_explained) {
                g_assistanceState.one_x_return_explained = true;
                claimed = true;
            }
            break;
        }
    }
    if (claimed) persist_assistance_state();
    return claimed;
}

void adopt_settings(const visual::core::VisualSettings& settings, bool persist) noexcept {
    {
        std::scoped_lock lock(g_settingsMutex);
        g_settings = settings;
        g_settings.zoom = visual::core::sanitize_zoom(g_settings.zoom);
    }
    apply_runtime_settings(settings);
    if (persist) persist_current_settings();
    if (g_settingsWindow) g_settingsWindow->set_settings(settings);
}

void publish_context_view(HWND notify_window, const visual::core::ScreenRect& viewport, double zoom) noexcept {
    {
        std::scoped_lock lock(g_contextViewMutex);
        g_pendingContextView.viewport = viewport;
        g_pendingContextView.zoom = zoom;
    }
    bool expected = false;
    if (g_contextViewMessagePending.compare_exchange_strong(expected, true, std::memory_order_relaxed)) {
        PostMessageW(notify_window, kContextViewChangedMessage, 0, 0);
    }
}

class Telemetry {
public:
    explicit Telemetry(const std::filesystem::path& path, bool append = false)
        : stream_(path, std::ios::out | (append ? std::ios::app : std::ios::trunc)) {
        if (!stream_) throw std::runtime_error("Unable to create Vision telemetry file");
        if (!append) {
        stream_ << "frame,qpc,zoom,tracking,poi_present,poi_source,locator_visible,viewport_action,view_left,view_top,view_right,view_bottom,present_hr,pointer_age_ms,uia_snapshot_age_ms,uia_caret_present,uia_focus_present,selected_poi_age_ms,selected_left,selected_top,selected_right,selected_bottom,view_id,source_generation,visual_mode\n";
        }
        stream_.flush();
    }

    void frame(std::uint64_t sequence, LARGE_INTEGER qpc, double zoom, bool tracking, bool poiPresent,
               visual::core::PoiSource source, bool locatorVisible, visual::core::ViewportAction action,
               const visual::core::ScreenRect& viewport, HRESULT presentHr,
               double pointerAgeMs, double uiaSnapshotAgeMs, bool uiaCaretPresent, bool uiaFocusPresent,
               double selectedPoiAgeMs, const visual::core::ScreenRect& selectedRect,
               std::uint64_t viewId, std::uint64_t sourceGeneration, visual::core::VisualMode visualMode) {
        std::scoped_lock lock(mutex_);
        stream_ << sequence << ',' << qpc.QuadPart << ',' << zoom << ',' << (tracking ? 1 : 0) << ','
                << (poiPresent ? 1 : 0) << ',' << static_cast<int>(source) << ',' << (locatorVisible ? 1 : 0) << ','
                << static_cast<int>(action) << ','
                << viewport.left << ',' << viewport.top << ',' << viewport.right << ',' << viewport.bottom << ','
                << static_cast<unsigned>(presentHr) << ','
                << pointerAgeMs << ',' << uiaSnapshotAgeMs << ',' << (uiaCaretPresent ? 1 : 0) << ','
                << (uiaFocusPresent ? 1 : 0) << ',' << selectedPoiAgeMs << ','
                << selectedRect.left << ',' << selectedRect.top << ',' << selectedRect.right << ',' << selectedRect.bottom << ','
                << viewId << ',' << sourceGeneration << ',' << static_cast<int>(visualMode) << '\n';
        if (sequence == 1 || (sequence % 120) == 0) stream_.flush();
    }

    void event(const std::string& name) {
        std::scoped_lock lock(mutex_);
        stream_ << "# event=" << name << '\n';
        stream_.flush();
    }

private:
    std::ofstream stream_;
    std::mutex mutex_;
};

class GpuDeviceDomain {
public:
    void initialize() {
        UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        D3D_FEATURE_LEVEL requested[] = {
            D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0,
            D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0
        };
        D3D_FEATURE_LEVEL actual{};
        winrt::check_hresult(D3D11CreateDevice(
            nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags, requested, ARRAYSIZE(requested),
            D3D11_SDK_VERSION, device_.put(), &actual, context_.put()));

        auto dxgiDevice = device_.as<IDXGIDevice>();
        winrt::com_ptr<IInspectable> inspectable;
        winrt::check_hresult(CreateDirect3D11DeviceFromDXGIDevice(dxgiDevice.get(), inspectable.put()));
        winrtDevice_ = inspectable.as<IDirect3DDevice>();
    }

    [[nodiscard]] ID3D11Device* device() const noexcept { return device_.get(); }
    [[nodiscard]] ID3D11DeviceContext* context() const noexcept { return context_.get(); }
    [[nodiscard]] IDirect3DDevice winrt_device() const { return winrtDevice_; }
    [[nodiscard]] std::mutex& context_mutex() noexcept { return contextMutex_; }

private:
    winrt::com_ptr<ID3D11Device> device_;
    winrt::com_ptr<ID3D11DeviceContext> context_;
    IDirect3DDevice winrtDevice_{nullptr};
    std::mutex contextMutex_;
};

struct CaptureFrameSnapshot {
    winrt::com_ptr<ID3D11Texture2D> texture{};
    std::uint64_t generation{};
};

class CaptureSource {
public:
    explicit CaptureSource(GpuDeviceDomain& gpu) noexcept : gpu_(gpu) {}

    void publish(ID3D11Texture2D* source) {
        if (!source) return;
        std::scoped_lock lock(mutex_);
        D3D11_TEXTURE2D_DESC sourceDesc{};
        source->GetDesc(&sourceDesc);
        ensure_owned_texture(sourceDesc);
        {
            std::scoped_lock contextLock(gpu_.context_mutex());
            gpu_.context()->CopyResource(ownedTexture_.get(), source);
        }
        ++generation_;
    }

    [[nodiscard]] CaptureFrameSnapshot snapshot() const noexcept {
        std::scoped_lock lock(mutex_);
        return {ownedTexture_, generation_};
    }

private:
    void ensure_owned_texture(const D3D11_TEXTURE2D_DESC& sourceDesc) {
        bool recreate = !ownedTexture_;
        if (ownedTexture_) {
            D3D11_TEXTURE2D_DESC existing{};
            ownedTexture_->GetDesc(&existing);
            recreate = existing.Width != sourceDesc.Width || existing.Height != sourceDesc.Height
                || existing.Format != sourceDesc.Format;
        }
        if (!recreate) return;

        D3D11_TEXTURE2D_DESC desc = sourceDesc;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Usage = D3D11_USAGE_DEFAULT;
        desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
        desc.CPUAccessFlags = 0;
        desc.MiscFlags = 0;
        winrt::check_hresult(gpu_.device()->CreateTexture2D(&desc, nullptr, ownedTexture_.put()));
    }

    GpuDeviceDomain& gpu_;
    mutable std::mutex mutex_;
    winrt::com_ptr<ID3D11Texture2D> ownedTexture_;
    std::uint64_t generation_{};
};

class OutputPresenter {
public:
    explicit OutputPresenter(GpuDeviceDomain& gpu, std::uint32_t presentDelayMs = 0) noexcept
        : gpu_(gpu), presentDelayMs_(presentDelayMs) {}

    void initialize(HWND hwnd, UINT width, UINT height) {
        winrt::com_ptr<IDXGIDevice> dxgiDevice;
        winrt::check_hresult(gpu_.device()->QueryInterface(__uuidof(IDXGIDevice), dxgiDevice.put_void()));
        winrt::com_ptr<IDXGIAdapter> adapter;
        winrt::check_hresult(dxgiDevice->GetAdapter(adapter.put()));
        winrt::com_ptr<IDXGIFactory2> factory;
        winrt::check_hresult(adapter->GetParent(__uuidof(IDXGIFactory2), factory.put_void()));

        DXGI_SWAP_CHAIN_DESC1 desc{};
        desc.Width = width;
        desc.Height = height;
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 2;
        desc.Scaling = DXGI_SCALING_STRETCH;
        desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        desc.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
        winrt::check_hresult(factory->CreateSwapChainForHwnd(
            gpu_.device(), hwnd, &desc, nullptr, nullptr, swapChain_.put()));
        factory->MakeWindowAssociation(hwnd, DXGI_MWA_NO_ALT_ENTER);

        winrt::com_ptr<ID3D11Texture2D> backBuffer;
        winrt::check_hresult(swapChain_->GetBuffer(
            0, __uuidof(ID3D11Texture2D), backBuffer.put_void()));
        winrt::check_hresult(gpu_.device()->CreateRenderTargetView(
            backBuffer.get(), nullptr, renderTarget_.put()));
    }

    [[nodiscard]] ID3D11RenderTargetView* render_target() const noexcept {
        return renderTarget_.get();
    }

    [[nodiscard]] HRESULT present() noexcept {
        if (presentDelayMs_ > 0) std::this_thread::sleep_for(std::chrono::milliseconds(presentDelayMs_));
        return swapChain_ ? swapChain_->Present(1, 0) : E_UNEXPECTED;
    }

private:
    GpuDeviceDomain& gpu_;
    winrt::com_ptr<IDXGISwapChain1> swapChain_;
    winrt::com_ptr<ID3D11RenderTargetView> renderTarget_;
    std::uint32_t presentDelayMs_{};
};

class Renderer {
public:
    explicit Renderer(GpuDeviceDomain& gpu, OutputPresenter& output, int reconstructionMode = 0) noexcept
        : gpu_(gpu), output_(output), reconstructionMode_(std::clamp(reconstructionMode, 0, 3)) {}

    void initialize(HWND hwnd, UINT width, UINT height) {
        width_ = width;
        height_ = height;

        output_.initialize(hwnd, width_, height_);
        create_pipeline();
    }

    HRESULT render(const CaptureFrameSnapshot& frame,
                   const RECT& sourceMonitorRect,
                   const visual::core::ScreenRect& viewportRect,
                   const visual::core::LocatorTarget& locator,
                   visual::core::VisualMode visualMode) {
        ID3D11Texture2D* source = frame.texture.get();
        if (!source) return S_FALSE;
        if (!viewportRect.valid()) return E_INVALIDARG;

        std::unique_lock d3dLock(gpu_.context_mutex());
        D3D11_TEXTURE2D_DESC sourceDesc{};
        source->GetDesc(&sourceDesc);
        ID3D11Texture2D* sampleTexture = source;
        if ((sourceDesc.BindFlags & D3D11_BIND_SHADER_RESOURCE) == 0) {
            ensure_scratch(sourceDesc);
            gpu_.context()->CopyResource(scratchTexture_.get(), source);
            sampleTexture = scratchTexture_.get();
        }

        winrt::com_ptr<ID3D11ShaderResourceView> srv;
        HRESULT hr = gpu_.device()->CreateShaderResourceView(sampleTexture, nullptr, srv.put());
        if (FAILED(hr)) return hr;

        const visual::core::ScreenRect sourceRect{
            static_cast<double>(sourceMonitorRect.left), static_cast<double>(sourceMonitorRect.top),
            static_cast<double>(sourceMonitorRect.right), static_cast<double>(sourceMonitorRect.bottom)
        };
        if (!sourceRect.valid()) return E_INVALIDARG;

        const float cropLeft = static_cast<float>((viewportRect.left - sourceRect.left) / sourceRect.width() * sourceDesc.Width);
        const float cropTop = static_cast<float>((viewportRect.top - sourceRect.top) / sourceRect.height() * sourceDesc.Height);
        const float cropWidth = static_cast<float>(viewportRect.width() / sourceRect.width() * sourceDesc.Width);
        const float cropHeight = static_cast<float>(viewportRect.height() / sourceRect.height() * sourceDesc.Height);

        RenderConstants constants{
            {cropWidth / static_cast<float>(sourceDesc.Width), cropHeight / static_cast<float>(sourceDesc.Height)},
            {cropLeft / static_cast<float>(sourceDesc.Width), cropTop / static_cast<float>(sourceDesc.Height)},
            {static_cast<float>(locator.left), static_cast<float>(locator.top),
             static_cast<float>(locator.right), static_cast<float>(locator.bottom)},
            {static_cast<float>(width_), static_cast<float>(height_)},
            locator.visible ? 1.0f : 0.0f,
            static_cast<float>(locator.kind),
            static_cast<float>(visualMode),
            static_cast<float>(reconstructionMode_),
            {0.0f, 0.0f}
        };
        D3D11_MAPPED_SUBRESOURCE mapped{};
        hr = gpu_.context()->Map(cropBuffer_.get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped);
        if (FAILED(hr)) return hr;
        *reinterpret_cast<RenderConstants*>(mapped.pData) = constants;
        gpu_.context()->Unmap(cropBuffer_.get(), 0);

        FLOAT clear[4] = {0, 0, 0, 1};
        gpu_.context()->ClearRenderTargetView(output_.render_target(), clear);
        UINT stride = sizeof(Vertex), offset = 0;
        ID3D11Buffer* vertexBuffers[] = {vertexBuffer_.get()};
        gpu_.context()->IASetInputLayout(inputLayout_.get());
        gpu_.context()->IASetVertexBuffers(0, 1, vertexBuffers, &stride, &offset);
        gpu_.context()->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        D3D11_VIEWPORT viewport{0, 0, static_cast<float>(width_), static_cast<float>(height_), 0.0f, 1.0f};
        gpu_.context()->RSSetViewports(1, &viewport);
        ID3D11RenderTargetView* renderTargets[] = {output_.render_target()};
        gpu_.context()->OMSetRenderTargets(1, renderTargets, nullptr);
        gpu_.context()->VSSetShader(vertexShader_.get(), nullptr, 0);
        gpu_.context()->PSSetShader(pixelShader_.get(), nullptr, 0);
        ID3D11ShaderResourceView* srvs[] = {srv.get()};
        ID3D11SamplerState* samplers[] = {sampler_.get()};
        ID3D11Buffer* constantBuffers[] = {cropBuffer_.get()};
        gpu_.context()->PSSetShaderResources(0, 1, srvs);
        gpu_.context()->PSSetSamplers(0, 1, samplers);
        gpu_.context()->PSSetConstantBuffers(0, 1, constantBuffers);
        gpu_.context()->Draw(6, 0);
        ID3D11ShaderResourceView* nullSrv[] = {nullptr};
        gpu_.context()->PSSetShaderResources(0, 1, nullSrv);
        gpu_.context()->Flush();
        d3dLock.unlock();
        return output_.present();
    }

private:
    winrt::com_ptr<ID3DBlob> compile_shader(const char* source, const char* entry, const char* target) {
        winrt::com_ptr<ID3DBlob> shader, errors;
        const HRESULT hr = D3DCompile(source, strlen(source), nullptr, nullptr, nullptr, entry, target,
            D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, shader.put(), errors.put());
        if (FAILED(hr)) {
            if (errors) OutputDebugStringA(static_cast<const char*>(errors->GetBufferPointer()));
            winrt::check_hresult(hr);
        }
        return shader;
    }

    void create_pipeline() {
        static constexpr char shaderSource[] = R"(
cbuffer RenderConstants : register(b0) {
    float2 uvScale;
    float2 uvOffset;
    float4 locatorRect;
    float2 outputSize;
    float locatorVisible;
    float locatorKind;
    float visualMode;
    float reconstructionMode;
    float2 padding;
};
struct VSInput { float2 pos : POSITION; float2 uv : TEXCOORD0; };
struct VSOutput { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };
VSOutput VSMain(VSInput input) { VSOutput o; o.pos=float4(input.pos,0,1); o.uv=input.uv; return o; }
Texture2D SourceTexture : register(t0);
SamplerState LinearSampler : register(s0);

float cubic(float x) {
    x = abs(x);
    if (x <= 1.0) return 1.5*x*x*x - 2.5*x*x + 1.0;
    if (x < 2.0) return -0.5*x*x*x + 2.5*x*x - 4.0*x + 2.0;
    return 0.0;
}
float sinc1(float x) {
    x = abs(x);
    if (x < 0.0001) return 1.0;
    float p = 3.14159265359 * x;
    return sin(p) / p;
}
float lanczos2w(float x) { x=abs(x); return x < 2.0 ? sinc1(x)*sinc1(x/2.0) : 0.0; }

float4 reconstruct(float2 uv) {
    uint tw, th; SourceTexture.GetDimensions(tw, th);
    float2 texSize=float2(tw,th), pos=uv*texSize-0.5;
    if (reconstructionMode < 0.5) return SourceTexture.SampleLevel(LinearSampler,uv,0);

    if (reconstructionMode > 2.5) {
        float2 d=1.0/texSize;
        float4 c=SourceTexture.SampleLevel(LinearSampler,uv,0);
        float4 n=SourceTexture.SampleLevel(LinearSampler,uv+float2(0,-d.y),0);
        float4 so=SourceTexture.SampleLevel(LinearSampler,uv+float2(0,d.y),0);
        float4 e=SourceTexture.SampleLevel(LinearSampler,uv+float2(d.x,0),0);
        float4 w=SourceTexture.SampleLevel(LinearSampler,uv+float2(-d.x,0),0);
        float4 blur=0.25*(n+so+e+w);
        float edge=saturate(length(c.rgb-blur.rgb)*2.0);
        return saturate(c + (0.30 + 0.20*edge)*(c-blur));
    }

    float2 base=floor(pos), fracp=pos-base;
    float4 sum=0; float total=0;
    [unroll] for(int j=-1;j<=2;++j) {
        [unroll] for(int i=-1;i<=2;++i) {
            float wx = reconstructionMode < 1.5 ? cubic(i-fracp.x) : lanczos2w(i-fracp.x);
            float wy = reconstructionMode < 1.5 ? cubic(j-fracp.y) : lanczos2w(j-fracp.y);
            float wt=wx*wy;
            float2 suv=(base+float2(i,j)+0.5)/texSize;
            sum += SourceTexture.SampleLevel(LinearSampler,suv,0)*wt; total += wt;
        }
    }
    return saturate(sum / max(abs(total),0.0001));
}
float4 PSMain(VSOutput input) : SV_TARGET {
    float4 base = reconstruct(uvOffset + input.uv * uvScale);
    if (visualMode > 0.5 && visualMode < 1.5) {
        base.rgb = saturate((base.rgb - 0.5) * 1.65 + 0.5);
    } else if (visualMode > 1.5 && visualMode < 2.5) {
        base.rgb = 1.0 - base.rgb;
    } else if (visualMode > 2.5) {
        float gray = dot(base.rgb, float3(0.2126, 0.7152, 0.0722));
        base.rgb = float3(gray, gray, gray);
    }
    if (locatorVisible < 0.5) return base;

    float2 p = input.uv * outputSize;
    float2 r0 = locatorRect.xy * outputSize;
    float2 r1 = locatorRect.zw * outputSize;
    float2 c = 0.5 * (r0 + r1);
    float outer = 0.0;
    float inner = 0.0;

    if (locatorKind < 0.5) {
        // Pointer: fixed-size crosshair with a small central gap.
        float2 d = abs(p - c);
        float verticalOuter = (d.x <= 3.5 && d.y >= 5.0 && d.y <= 20.0) ? 1.0 : 0.0;
        float horizontalOuter = (d.y <= 3.5 && d.x >= 5.0 && d.x <= 20.0) ? 1.0 : 0.0;
        float verticalInner = (d.x <= 1.5 && d.y >= 6.0 && d.y <= 19.0) ? 1.0 : 0.0;
        float horizontalInner = (d.y <= 1.5 && d.x >= 6.0 && d.x <= 19.0) ? 1.0 : 0.0;
        outer = max(verticalOuter, horizontalOuter);
        inner = max(verticalInner, horizontalInner);
    } else {
        // Caret/focus: expand very small targets to a visible minimum and outline them.
        float2 minimumSize = locatorKind < 1.5 ? float2(12.0, 28.0) : float2(28.0, 28.0);
        float2 halfSize = max(0.5 * (r1 - r0), 0.5 * minimumSize);
        r0 = c - halfSize;
        r1 = c + halfSize;
        float inside = (p.x >= r0.x && p.x <= r1.x && p.y >= r0.y && p.y <= r1.y) ? 1.0 : 0.0;
        float edge = min(min(p.x - r0.x, r1.x - p.x), min(p.y - r0.y, r1.y - p.y));
        outer = inside * ((edge <= 5.0) ? 1.0 : 0.0);
        inner = inside * ((edge <= 2.0) ? 1.0 : 0.0);
    }

    if (inner > 0.5) return float4(1.0, 1.0, 1.0, 1.0);
    if (outer > 0.5) return float4(0.0, 0.0, 0.0, 1.0);
    return base;
}
)";
        auto vsBlob = compile_shader(shaderSource, "VSMain", "vs_5_0");
        auto psBlob = compile_shader(shaderSource, "PSMain", "ps_5_0");
        winrt::check_hresult(gpu_.device()->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, vertexShader_.put()));
        winrt::check_hresult(gpu_.device()->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, pixelShader_.put()));
        D3D11_INPUT_ELEMENT_DESC inputDesc[] = {
            {"POSITION",0,DXGI_FORMAT_R32G32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,8,D3D11_INPUT_PER_VERTEX_DATA,0},
        };
        winrt::check_hresult(gpu_.device()->CreateInputLayout(inputDesc, ARRAYSIZE(inputDesc), vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), inputLayout_.put()));
        const Vertex vertices[] = {{-1,1,0,0},{1,1,1,0},{1,-1,1,1},{-1,1,0,0},{1,-1,1,1},{-1,-1,0,1}};
        D3D11_BUFFER_DESC vbDesc{};
        vbDesc.ByteWidth = sizeof(vertices);
        vbDesc.Usage = D3D11_USAGE_IMMUTABLE;
        vbDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
        D3D11_SUBRESOURCE_DATA vbData{};
        vbData.pSysMem = vertices;
        winrt::check_hresult(gpu_.device()->CreateBuffer(&vbDesc, &vbData, vertexBuffer_.put()));
        D3D11_BUFFER_DESC cbDesc{};
        cbDesc.ByteWidth = sizeof(RenderConstants);
        cbDesc.Usage = D3D11_USAGE_DYNAMIC;
        cbDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
        cbDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
        winrt::check_hresult(gpu_.device()->CreateBuffer(&cbDesc, nullptr, cropBuffer_.put()));
        D3D11_SAMPLER_DESC samplerDesc{};
        samplerDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
        samplerDesc.AddressU = samplerDesc.AddressV = samplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
        samplerDesc.MaxLOD = D3D11_FLOAT32_MAX;
        winrt::check_hresult(gpu_.device()->CreateSamplerState(&samplerDesc, sampler_.put()));
    }

    void ensure_scratch(const D3D11_TEXTURE2D_DESC& sourceDesc) {
        bool recreate = !scratchTexture_;
        if (scratchTexture_) {
            D3D11_TEXTURE2D_DESC existing{};
            scratchTexture_->GetDesc(&existing);
            recreate = existing.Width != sourceDesc.Width || existing.Height != sourceDesc.Height || existing.Format != sourceDesc.Format;
        }
        if (!recreate) return;
        D3D11_TEXTURE2D_DESC desc = sourceDesc;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Usage = D3D11_USAGE_DEFAULT;
        desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
        desc.CPUAccessFlags = 0;
        desc.MiscFlags = 0;
        winrt::check_hresult(gpu_.device()->CreateTexture2D(&desc, nullptr, scratchTexture_.put()));
    }

    UINT width_{};
    UINT height_{};
    int reconstructionMode_{};
    GpuDeviceDomain& gpu_;
    OutputPresenter& output_;
    winrt::com_ptr<ID3D11VertexShader> vertexShader_;
    winrt::com_ptr<ID3D11PixelShader> pixelShader_;
    winrt::com_ptr<ID3D11InputLayout> inputLayout_;
    winrt::com_ptr<ID3D11Buffer> vertexBuffer_;
    winrt::com_ptr<ID3D11Buffer> cropBuffer_;
    winrt::com_ptr<ID3D11SamplerState> sampler_;
    winrt::com_ptr<ID3D11Texture2D> scratchTexture_;
};

class CaptureRunner {
public:
    CaptureRunner(GpuDeviceDomain& gpu, CaptureSource& captureSource, Renderer& renderer,
                  Telemetry& telemetry, visual::core::WorkspaceCoordinator& workspace,
                  visual::tracking::EvidenceHub& evidenceHub, visual::core::ViewId viewId,
                  const MonitorRecord& sourceMonitor, HWND notifyWindow)
        : gpu_(gpu), captureSource_(captureSource), renderer_(renderer), telemetry_(telemetry),
          workspace_(workspace), evidenceHub_(evidenceHub), viewId_(viewId),
          sourceMonitor_(sourceMonitor), notifyWindow_(notifyWindow),
          qpcFreq_(qpc_frequency()) {}

    void start() {
        if (!GraphicsCaptureSession::IsSupported()) throw winrt::hresult_error(E_NOTIMPL, L"Windows Graphics Capture is not supported.");
        auto factory = winrt::get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
        winrt::check_hresult(factory->CreateForMonitor(sourceMonitor_.handle, winrt::guid_of<GraphicsCaptureItem>(), winrt::put_abi(item_)));
        itemClosedToken_ = item_.Closed([this](const GraphicsCaptureItem&, const winrt::Windows::Foundation::IInspectable&) {
            telemetry_.event("capture_item_closed");
            PostMessageW(notifyWindow_, kCaptureSourceClosedMessage, 0, 0);
        });
        itemClosedSubscribed_ = true;
        captureSize_ = item_.Size();
        framePool_ = Direct3D11CaptureFramePool::CreateFreeThreaded(gpu_.winrt_device(), DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, captureSize_);
        session_ = framePool_.CreateCaptureSession(item_);
        session_.IsCursorCaptureEnabled(false);
        token_ = framePool_.FrameArrived([this](const Direct3D11CaptureFramePool& sender, const winrt::Windows::Foundation::IInspectable&) { on_frame(sender); });
        session_.StartCapture();
        renderThread_ = std::jthread([this](std::stop_token stop) { render_loop(stop); });
        telemetry_.event("capture_started");
    }

    void stop() noexcept {
        if (renderThread_.joinable()) {
            renderThread_.request_stop();
            renderThread_.join();
        }
        try { if (framePool_) framePool_.FrameArrived(token_); } catch (...) {}
        try { if (item_ && itemClosedSubscribed_) item_.Closed(itemClosedToken_); } catch (...) {}
        itemClosedSubscribed_ = false;
        try { if (session_) session_.Close(); } catch (...) {}
        try { if (framePool_) framePool_.Close(); } catch (...) {}
        session_ = nullptr;
        framePool_ = nullptr;
        item_ = nullptr;
    }

    [[nodiscard]] bool source_frame_observed() const noexcept { return firstSourceFrameObserved_.load(std::memory_order_relaxed); }
    [[nodiscard]] bool render_observed() const noexcept { return firstRenderObserved_.load(std::memory_order_relaxed); }
    [[nodiscard]] bool health_ready() const noexcept { return source_frame_observed() && render_observed(); }
    [[nodiscard]] std::uint64_t render_frames() const noexcept { return sequence_.load(std::memory_order_relaxed); }

    ~CaptureRunner() { stop(); }

private:
    [[nodiscard]] double age_ms(std::uint64_t timestamp, std::uint64_t now) const noexcept {
        if (timestamp == 0 || now < timestamp || qpcFreq_.QuadPart <= 0) return -1.0;
        return 1000.0 * static_cast<double>(now - timestamp) / static_cast<double>(qpcFreq_.QuadPart);
    }

    void on_frame(const Direct3D11CaptureFramePool& sender) noexcept {
        try {
            auto frame = sender.TryGetNextFrame();
            if (!frame) return;
            const auto size = frame.ContentSize();
            if (size.Width <= 0 || size.Height <= 0) return;
            if (size.Width != captureSize_.Width || size.Height != captureSize_.Height) {
                frame.Close();
                captureSize_ = size;
                framePool_.Recreate(gpu_.winrt_device(), DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, captureSize_);
                telemetry_.event("content_size_changed");
                return;
            }

            auto access = frame.Surface().as<AbiDxgiInterfaceAccess>();
            winrt::com_ptr<ID3D11Texture2D> texture;
            winrt::check_hresult(access->GetInterface(__uuidof(ID3D11Texture2D), texture.put_void()));
            captureSource_.publish(texture.get());
            bool expected = false;
            if (firstSourceFrameObserved_.compare_exchange_strong(expected, true, std::memory_order_relaxed)) {
                telemetry_.event("first_source_frame");
            }
        } catch (const winrt::hresult_error&) {
            fail_capture();
        } catch (...) {
            fail_capture();
        }
    }

    void render_loop(std::stop_token stop) noexcept {
        try {
            const visual::core::ScreenRect sourceRect{
                static_cast<double>(sourceMonitor_.rect.left), static_cast<double>(sourceMonitor_.rect.top),
                static_cast<double>(sourceMonitor_.rect.right), static_cast<double>(sourceMonitor_.rect.bottom)
            };
            auto next = std::chrono::steady_clock::now();
            constexpr auto interval = std::chrono::milliseconds(16);

            while (!stop.stop_requested()) {
                next += interval;
                const auto now = qpc_now();
                const auto nowQpc = static_cast<std::uint64_t>(now.QuadPart);

                const auto evidenceSnapshot = evidenceSampler_.sample(sourceRect, nowQpc);
                evidenceHub_.publish(evidenceSnapshot);
                const auto frameSettings = runtime_settings_snapshot();
                const auto& routedCandidates = workspace_.movement_permitted(viewId_)
                    ? evidenceSnapshot.candidates
                    : noMovementCandidates_;
                const auto stepped = viewUpdateStep_.update({
                    sourceRect,
                    frameSettings,
                    routedCandidates,
                    nowQpc,
                    static_cast<std::uint64_t>(qpcFreq_.QuadPart),
                    evidenceSnapshot.pointer_movement_qpc});
                const auto& view = stepped.view;
                const auto& locator = stepped.locator;
                const double zoom = frameSettings.zoom;
                const bool tracking = frameSettings.tracking_enabled;
                const auto selectedSource = view.selected_poi ? view.selected_poi->source : visual::core::PoiSource::Pointer;
                publish_context_view(notifyWindow_, view.viewport, zoom);

                const auto captureFrame = captureSource_.snapshot();
                if (captureFrame.generation < lastRenderedFrameGeneration_) {
                    telemetry_.event("capture_frame_generation_regressed");
                    throw winrt::hresult_error(E_UNEXPECTED);
                }
                if (captureFrame.generation > 0 && lastRenderedFrameGeneration_ == 0) {
                    telemetry_.event("first_render_source_generation");
                }
                lastRenderedFrameGeneration_ = captureFrame.generation;
                const HRESULT presentHr = renderer_.render(
                    captureFrame, sourceMonitor_.rect, view.viewport, locator, frameSettings.visual_mode);
                if (presentHr != S_FALSE) {
                    if (SUCCEEDED(presentHr)) {
                        bool expected = false;
                        if (firstRenderObserved_.compare_exchange_strong(expected, true, std::memory_order_relaxed)) {
                            telemetry_.event("first_render_frame");
                        }
                    }
                    const double pointerAgeMs = age_ms(evidenceSnapshot.pointer_movement_qpc, nowQpc);
                    const double uiaSnapshotAgeMs = age_ms(evidenceSnapshot.uia_sampled_qpc, nowQpc);
                    const double selectedAgeMs = view.selected_poi ? age_ms(view.selected_poi->timestamp_qpc, nowQpc) : -1.0;
                    const auto selectedRect = view.selected_poi ? view.selected_poi->screen_rect : visual::core::ScreenRect{};
                    telemetry_.frame(++sequence_, now, zoom, tracking, view.selected_poi.has_value(), selectedSource,
                                     locator.visible, view.action, view.viewport, presentHr,
                                     pointerAgeMs, uiaSnapshotAgeMs, evidenceSnapshot.uia_current_caret_present,
                                     evidenceSnapshot.uia_current_focus_present, selectedAgeMs, selectedRect,
                                     viewId_.value, captureFrame.generation, frameSettings.visual_mode);
                    if (FAILED(presentHr)) throw winrt::hresult_error(presentHr);
                }

                std::this_thread::sleep_until(next);
                const auto afterSleep = std::chrono::steady_clock::now();
                if (afterSleep > next + interval * 4) next = afterSleep;
            }
        } catch (const winrt::hresult_error&) {
            fail_capture();
        } catch (...) {
            fail_capture();
        }
    }

    void fail_capture() noexcept {
        bool expected = false;
        if (failurePosted_.compare_exchange_strong(expected, true, std::memory_order_relaxed)) {
            try { telemetry_.event("capture_failure"); } catch (...) {}
            g_captureFailed.store(true, std::memory_order_relaxed);
            PostMessageW(notifyWindow_, kCaptureErrorMessage, static_cast<WPARAM>(E_FAIL), 0);
        }
    }

    GpuDeviceDomain& gpu_;
    CaptureSource& captureSource_;
    Renderer& renderer_;
    Telemetry& telemetry_;
    visual::core::WorkspaceCoordinator& workspace_;
    visual::tracking::EvidenceHub& evidenceHub_;
    visual::core::ViewId viewId_{};
    std::vector<visual::core::PoiCandidate> noMovementCandidates_{};
    MonitorRecord sourceMonitor_;
    HWND notifyWindow_{};
    LARGE_INTEGER qpcFreq_{};
    visual::tracking::EvidenceSampler evidenceSampler_{};
    visual::core::ViewUpdateStep viewUpdateStep_{};
    GraphicsCaptureItem item_{nullptr};
    Direct3D11CaptureFramePool framePool_{nullptr};
    GraphicsCaptureSession session_{nullptr};
    winrt::event_token token_{};
    winrt::event_token itemClosedToken_{};
    bool itemClosedSubscribed_{};
    winrt::Windows::Graphics::SizeInt32 captureSize_{};
    std::jthread renderThread_{};
    std::atomic<bool> failurePosted_{false};
    std::atomic<bool> firstSourceFrameObserved_{false};
    std::atomic<bool> firstRenderObserved_{false};
    std::atomic<std::uint64_t> sequence_{0};
    std::uint64_t lastRenderedFrameGeneration_{};
};



class CaptureOnlyPump {
public:
    CaptureOnlyPump(GpuDeviceDomain& gpu, CaptureSource& source, Telemetry& telemetry,
                    const MonitorRecord& monitor, std::uint64_t sourceId)
        : gpu_(gpu), source_(source), telemetry_(telemetry), monitor_(monitor), sourceId_(sourceId) {}
    void start() {
        auto factory=winrt::get_activation_factory<GraphicsCaptureItem,IGraphicsCaptureItemInterop>();
        winrt::check_hresult(factory->CreateForMonitor(monitor_.handle,winrt::guid_of<GraphicsCaptureItem>(),winrt::put_abi(item_)));
        size_=item_.Size();
        pool_=Direct3D11CaptureFramePool::CreateFreeThreaded(gpu_.winrt_device(),DirectXPixelFormat::B8G8R8A8UIntNormalized,2,size_);
        session_=pool_.CreateCaptureSession(item_); session_.IsCursorCaptureEnabled(false);
        token_=pool_.FrameArrived([this](const Direct3D11CaptureFramePool& sender,const winrt::Windows::Foundation::IInspectable&){on_frame(sender);});
        session_.StartCapture(); telemetry_.event("capture_source_"+std::to_string(sourceId_)+"_started");
    }
    void stop() noexcept {
        try{if(pool_)pool_.FrameArrived(token_);}catch(...){}
        try{if(session_)session_.Close();}catch(...){}
        try{if(pool_)pool_.Close();}catch(...){}
        session_=nullptr;pool_=nullptr;item_=nullptr;
    }
    ~CaptureOnlyPump(){stop();}
    [[nodiscard]] bool frame_observed()const noexcept{return observed_.load(std::memory_order_relaxed);}
private:
    void on_frame(const Direct3D11CaptureFramePool& sender) noexcept {
        try{
            auto frame=sender.TryGetNextFrame(); if(!frame)return;
            auto size=frame.ContentSize(); if(size.Width<=0||size.Height<=0)return;
            if(size.Width!=size_.Width||size.Height!=size_.Height){frame.Close();size_=size;pool_.Recreate(gpu_.winrt_device(),DirectXPixelFormat::B8G8R8A8UIntNormalized,2,size_);return;}
            auto access=frame.Surface().as<AbiDxgiInterfaceAccess>();winrt::com_ptr<ID3D11Texture2D> texture;
            winrt::check_hresult(access->GetInterface(__uuidof(ID3D11Texture2D),texture.put_void()));
            source_.publish(texture.get());
            bool expected=false;if(observed_.compare_exchange_strong(expected,true,std::memory_order_relaxed))
                telemetry_.event("capture_source_"+std::to_string(sourceId_)+"_first_frame");
        }catch(...){telemetry_.event("capture_source_"+std::to_string(sourceId_)+"_failure");}
    }
    GpuDeviceDomain& gpu_; CaptureSource& source_; Telemetry& telemetry_; MonitorRecord monitor_; std::uint64_t sourceId_{};
    GraphicsCaptureItem item_{nullptr}; Direct3D11CaptureFramePool pool_{nullptr}; GraphicsCaptureSession session_{nullptr};
    winrt::event_token token_{}; winrt::Windows::Graphics::SizeInt32 size_{}; std::atomic<bool> observed_{false};
};

class SecondaryViewRunner {
public:
    SecondaryViewRunner(CaptureSource& source, Renderer& renderer, Telemetry& telemetry,
                        const MonitorRecord& sourceMonitor, visual::core::ViewId viewId,
                        double zoom, visual::core::VisualMode mode,
                        visual::core::WorkspaceRuntimeGraph* graph = nullptr)
        : source_(source), renderer_(renderer), telemetry_(telemetry), sourceMonitor_(sourceMonitor),
          viewId_(viewId), zoom_(zoom), mode_(mode), graph_(graph) {}

    void start() {
        thread_ = std::jthread([this](std::stop_token stop) { loop(stop); });
        telemetry_.event("secondary_view_started");
    }
    void stop() noexcept {
        if (thread_.joinable()) { thread_.request_stop(); thread_.join(); }
    }
    ~SecondaryViewRunner() { stop(); }
    [[nodiscard]] bool render_observed() const noexcept { return rendered_.load(std::memory_order_relaxed); }
    [[nodiscard]] std::uint64_t frames() const noexcept { return frames_.load(std::memory_order_relaxed); }

private:
    void loop(std::stop_token stop) noexcept {
        try {
            const visual::core::ScreenRect sourceRect{
                static_cast<double>(sourceMonitor_.rect.left), static_cast<double>(sourceMonitor_.rect.top),
                static_cast<double>(sourceMonitor_.rect.right), static_cast<double>(sourceMonitor_.rect.bottom)};
            visual::core::VisualSettings settings{};
            settings.zoom = zoom_;
            settings.tracking_enabled = false;
            settings.visual_mode = mode_;
            const std::vector<visual::core::PoiCandidate> noEvidence;
            auto next = std::chrono::steady_clock::now();
            while (!stop.stop_requested()) {
                next += std::chrono::milliseconds(16);
                if (graph_ && !graph_->view_active(viewId_)) {
                    std::this_thread::sleep_until(next);
                    continue;
                }
                const auto qpc = qpc_now();
                const auto stepped = step_.update({
                    sourceRect, settings, noEvidence, static_cast<std::uint64_t>(qpc.QuadPart),
                    static_cast<std::uint64_t>(qpc_frequency().QuadPart)});
                const auto frame = source_.snapshot();
                if (frame.generation > 0) {
                    const HRESULT hr = renderer_.render(
                        frame, sourceMonitor_.rect, stepped.view.viewport, stepped.locator, settings.visual_mode);
                    if (hr != S_FALSE) {
                        const auto seq = frames_.fetch_add(1, std::memory_order_relaxed) + 1;
                        rendered_.store(SUCCEEDED(hr), std::memory_order_relaxed);
                        telemetry_.frame(seq, qpc, settings.zoom, false, false, visual::core::PoiSource::Pointer,
                            stepped.locator.visible, stepped.view.action, stepped.view.viewport, hr,
                            -1.0, -1.0, false, false, -1.0, {}, viewId_.value, frame.generation, settings.visual_mode);
                        if (FAILED(hr)) throw winrt::hresult_error(hr);
                    }
                }
                std::this_thread::sleep_until(next);
                if (std::chrono::steady_clock::now() > next + std::chrono::milliseconds(64))
                    next = std::chrono::steady_clock::now();
            }
        } catch (...) {
            telemetry_.event("secondary_view_failure");
        }
    }

    CaptureSource& source_;
    Renderer& renderer_;
    Telemetry& telemetry_;
    MonitorRecord sourceMonitor_;
    visual::core::ViewId viewId_{};
    double zoom_{4.0};
    visual::core::VisualMode mode_{visual::core::VisualMode::Inverted};
    visual::core::ViewUpdateStep step_{};
    visual::core::WorkspaceRuntimeGraph* graph_{};
    std::jthread thread_{};
    std::atomic<bool> rendered_{false};
    std::atomic<std::uint64_t> frames_{0};
};


constexpr int kHotkeyZoom1 = 101;
constexpr int kHotkeyZoom2 = 102;
constexpr int kHotkeyZoom3 = 103;
constexpr int kHotkeyZoom4 = 104;
constexpr int kHotkeyTracking = 110;
constexpr int kHotkeySettings = 111;
constexpr int kHotkeyHelp = 112;
constexpr int kHotkeyNormalReturn = 120;
constexpr int kHotkeyExit = 199;

void refresh_settings_window() noexcept {
    if (!g_settingsWindow) return;
    try {
        visual::core::VisualSettings copy{};
        {
            std::scoped_lock lock(g_settingsMutex);
            copy = g_settings;
        }
        g_settingsWindow->set_settings(copy);
    } catch (...) {}
}

void set_zoom(double zoom) noexcept {
    zoom = visual::core::sanitize_zoom(zoom, g_zoom.load(std::memory_order_relaxed));
    if (zoom > 1.0) g_previousMagnifiedZoom.store(zoom, std::memory_order_relaxed);
    g_zoom.store(zoom, std::memory_order_relaxed);
    {
        std::scoped_lock lock(g_settingsMutex);
        g_settings.zoom = zoom;
    }
    persist_current_settings();
    refresh_settings_window();
}

void toggle_normal_return() noexcept {
    const double current = g_zoom.load(std::memory_order_relaxed);
    if (visual::core::near_zoom(current, 1.0)) {
        double restore = g_previousMagnifiedZoom.load(std::memory_order_relaxed);
        if (!visual::core::supported_zoom(restore) || restore <= 1.0) restore = 2.0;
        g_zoom.store(restore, std::memory_order_relaxed);
    } else {
        g_previousMagnifiedZoom.store(current, std::memory_order_relaxed);
        g_zoom.store(1.0, std::memory_order_relaxed);
        if (g_hintWindow && claim_assistance_hint(AssistanceHint::OneXReturn)) {
            g_hintWindow->show(L"1x View / Return",
                L"You are at 1x. Press Ctrl+Alt+0 again to return to your previous zoom and exact position.");
        }
    }
}

void toggle_tracking() noexcept {
    const bool enabled = !g_trackingEnabled.load(std::memory_order_relaxed);
    g_trackingEnabled.store(enabled, std::memory_order_relaxed);
    {
        std::scoped_lock lock(g_settingsMutex);
        g_settings.tracking_enabled = enabled;
    }
    persist_current_settings();
    refresh_settings_window();
}

void show_settings() noexcept {
    if (g_settingsWindow) g_settingsWindow->show();
}

void show_help() noexcept {
    if (g_helpWindow) g_helpWindow->show();
}

bool register_hotkeys(HWND hwnd) noexcept {
    constexpr UINT modifiers = MOD_CONTROL | MOD_ALT | MOD_NOREPEAT;
    struct Binding { int id; UINT key; };
    constexpr Binding bindings[] = {
        {kHotkeyZoom1, '1'},
        {kHotkeyZoom2, '2'},
        {kHotkeyZoom3, '3'},
        {kHotkeyZoom4, '4'},
        {kHotkeyTracking, 'T'},
        {kHotkeySettings, 'S'},
        {kHotkeyHelp, 'H'},
        {kHotkeyNormalReturn, '0'},
        {kHotkeyExit, 'Q'},
    };

    std::size_t registered = 0;
    for (; registered < std::size(bindings); ++registered) {
        if (!RegisterHotKey(hwnd, bindings[registered].id, modifiers, bindings[registered].key)) {
            for (std::size_t i = 0; i < registered; ++i) {
                UnregisterHotKey(hwnd, bindings[i].id);
            }
            return false;
        }
    }
    return true;
}

void unregister_hotkeys(HWND hwnd) noexcept {
    UnregisterHotKey(hwnd, kHotkeyZoom1);
    UnregisterHotKey(hwnd, kHotkeyZoom2);
    UnregisterHotKey(hwnd, kHotkeyZoom3);
    UnregisterHotKey(hwnd, kHotkeyZoom4);
    UnregisterHotKey(hwnd, kHotkeyTracking);
    UnregisterHotKey(hwnd, kHotkeySettings);
    UnregisterHotKey(hwnd, kHotkeyHelp);
    UnregisterHotKey(hwnd, kHotkeyNormalReturn);
    UnregisterHotKey(hwnd, kHotkeyExit);
}

void show_detail_context_menu(HWND hwnd, LPARAM l_param) noexcept {
    POINT point{GET_X_LPARAM(l_param), GET_Y_LPARAM(l_param)};
    if (point.x == -1 && point.y == -1) {
        RECT rect{};
        GetWindowRect(hwnd, &rect);
        point = {rect.left + 40, rect.top + 40};
    }
    HMENU menu = CreatePopupMenu();
    if (!menu) return;
    AppendMenuW(menu, MF_STRING, 1, L"Vision Settings...\tCtrl+Alt+S");
    AppendMenuW(menu, MF_STRING, 2, L"1x View / Return\tCtrl+Alt+0");
    AppendMenuW(menu, MF_STRING | (g_trackingEnabled.load(std::memory_order_relaxed) ? MF_CHECKED : 0), 3, L"Tracking\tCtrl+Alt+T");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, 4, L"Help / Ask Vision\tCtrl+Alt+H");
    AppendMenuW(menu, MF_STRING, 5, L"Exit Vision\tCtrl+Alt+Q");
    SetForegroundWindow(hwnd);
    const UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, hwnd, nullptr);
    DestroyMenu(menu);
    if (command == 1) show_settings();
    else if (command == 2) toggle_normal_return();
    else if (command == 3) toggle_tracking();
    else if (command == 4) show_help();
    else if (command == 5) DestroyWindow(hwnd);
}

LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) { DestroyWindow(hwnd); return 0; }
        if (wParam == '1') { set_zoom(1); return 0; }
        if (wParam == '2') { set_zoom(2); return 0; }
        if (wParam == '3') { set_zoom(3); return 0; }
        if (wParam == '4') { set_zoom(4); return 0; }
        if (wParam == 'T') { toggle_tracking(); return 0; }
        if (wParam == 'S') { show_settings(); return 0; }
        if (wParam == 'H') { show_help(); return 0; }
        if (wParam == '0') { toggle_normal_return(); return 0; }
        break;
    case WM_HOTKEY:
        if (wParam == kHotkeyZoom1) { set_zoom(1); return 0; }
        if (wParam == kHotkeyZoom2) { set_zoom(2); return 0; }
        if (wParam == kHotkeyZoom3) { set_zoom(3); return 0; }
        if (wParam == kHotkeyZoom4) { set_zoom(4); return 0; }
        if (wParam == kHotkeyTracking) { toggle_tracking(); return 0; }
        if (wParam == kHotkeySettings) { show_settings(); return 0; }
        if (wParam == kHotkeyHelp) { show_help(); return 0; }
        if (wParam == kHotkeyNormalReturn) { toggle_normal_return(); return 0; }
        if (wParam == kHotkeyExit) { DestroyWindow(hwnd); return 0; }
        break;
    case kContextViewChangedMessage: {
        PendingContextView pending{};
        {
            std::scoped_lock lock(g_contextViewMutex);
            pending = g_pendingContextView;
        }
        g_contextViewMessagePending.store(false, std::memory_order_relaxed);
        if (g_contextOverlay) {
            g_contextOverlay->update(pending.viewport, pending.zoom,
                                     g_showContextIndicator.load(std::memory_order_relaxed),
                                     g_shadeContextIndicator.load(std::memory_order_relaxed));
        }
        return 0;
    }
    case WM_CONTEXTMENU:
        show_detail_context_menu(hwnd, lParam);
        return 0;
    case kCaptureErrorMessage:
        g_shutdownReason.store(static_cast<int>(ShutdownReason::CaptureFailure), std::memory_order_relaxed);
        if (!g_healthCheckMode.load(std::memory_order_relaxed)) {
            MessageBoxW(hwnd, L"Capture/render loop failed. See visual_app_telemetry.csv.", L"Vision", MB_OK | MB_ICONERROR);
        }
        DestroyWindow(hwnd);
        return 0;
    case kCaptureSourceClosedMessage:
        g_shutdownReason.store(static_cast<int>(ShutdownReason::CaptureSourceClosed), std::memory_order_relaxed);
        DestroyWindow(hwnd);
        return 0;
    case WM_DISPLAYCHANGE:
        g_shutdownReason.store(static_cast<int>(ShutdownReason::DisplayTopologyChanged), std::memory_order_relaxed);
        DestroyWindow(hwnd);
        return 0;
    case WM_DESTROY:
        unregister_hotkeys(hwnd);
        PostQuitMessage(0);
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd, message, wParam, lParam);
}

WindowPlacement create_detail_window(HINSTANCE instance, const MonitorRecord& destination, bool singleMonitor) {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = window_proc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.lpszClassName = kWindowClass;
    wc.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) winrt::throw_last_error();

    const int monitorWidth = destination.rect.right - destination.rect.left;
    const int monitorHeight = destination.rect.bottom - destination.rect.top;
    int x = destination.rect.left;
    int y = destination.rect.top;
    int width = monitorWidth;
    int height = monitorHeight;
    DWORD style = WS_POPUP;
    DWORD exStyle = WS_EX_APPWINDOW | WS_EX_NOACTIVATE;

    if (singleMonitor) {
        width = std::min(std::max(640, monitorWidth * 45 / 100), monitorWidth - 40);
        height = std::min(std::max(360, monitorHeight * 45 / 100), monitorHeight - 80);
        x = destination.rect.right - width - 20;
        y = destination.rect.top + 40;
        style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
        exStyle |= WS_EX_TOPMOST;
    }

    HWND hwnd = CreateWindowExW(exStyle, kWindowClass, L"Vision - Detail", style, x, y, width, height,
                                nullptr, nullptr, instance, nullptr);
    if (!hwnd) winrt::throw_last_error();
    if (!g_healthCheckMode.load(std::memory_order_relaxed) && !register_hotkeys(hwnd)) {
        DestroyWindow(hwnd);
        throw std::runtime_error("Vision could not register its Ctrl+Alt shortcuts. Another application may already be using one of them.");
    }
    SetWindowPos(hwnd, singleMonitor ? HWND_TOPMOST : HWND_TOP, x, y, width, height, SWP_SHOWWINDOW | SWP_NOACTIVATE);
    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
    UpdateWindow(hwnd);

    WindowPlacement result{};
    result.hwnd = hwnd;
    result.width = static_cast<UINT>(width);
    result.height = static_cast<UINT>(height);
    result.singleMonitor = singleMonitor;
    if (singleMonitor) result.excludedFromCapture = SetWindowDisplayAffinity(hwnd, kExcludeFromCapture) != FALSE;
    return result;
}

int find_monitor_by_device(const std::vector<MonitorRecord>& monitors, const std::wstring& device_name) {
    if (device_name.empty()) return -1;
    for (std::size_t i = 0; i < monitors.size(); ++i) {
        if (_wcsicmp(monitors[i].deviceName.c_str(), device_name.c_str()) == 0) return static_cast<int>(i);
    }
    return -1;
}

class WorkspaceRuntimeCollection {
public:
    struct SourceWorker {
        visual::core::SourceId id{};
        std::unique_ptr<CaptureSource> source;
        std::unique_ptr<CaptureOnlyPump> pump;
    };
    struct ViewWorker {
        visual::core::ViewId id{};
        std::unique_ptr<OutputPresenter> output;
        std::unique_ptr<Renderer> renderer;
        std::unique_ptr<SecondaryViewRunner> runner;
        WindowPlacement window{};
    };

    CaptureSource& add_source(GpuDeviceDomain& gpu, Telemetry& telemetry,
                              const MonitorRecord& monitor, visual::core::SourceId id) {
        auto worker = std::make_unique<SourceWorker>();
        worker->id = id;
        worker->source = std::make_unique<CaptureSource>(gpu);
        worker->pump = std::make_unique<CaptureOnlyPump>(gpu, *worker->source, telemetry, monitor, id.value);
        auto& source = *worker->source;
        sources_.push_back(std::move(worker));
        return source;
    }

    SecondaryViewRunner& add_view(HINSTANCE instance, GpuDeviceDomain& gpu, Telemetry& telemetry,
                                  visual::core::WorkspaceRuntimeGraph& graph, CaptureSource& source,
                                  const MonitorRecord& sourceMonitor, const MonitorRecord& destinationMonitor,
                                  visual::core::ViewId id, double zoom, visual::core::VisualMode mode,
                                  std::uint32_t presentDelayMs = 0) {
        auto worker = std::make_unique<ViewWorker>();
        worker->id = id;
        worker->window = create_detail_window(instance, destinationMonitor, true);
        worker->output = std::make_unique<OutputPresenter>(gpu, presentDelayMs);
        worker->renderer = std::make_unique<Renderer>(gpu, *worker->output);
        worker->renderer->initialize(worker->window.hwnd, worker->window.width, worker->window.height);
        worker->runner = std::make_unique<SecondaryViewRunner>(
            source, *worker->renderer, telemetry, sourceMonitor, id, zoom, mode, &graph);
        auto& runner = *worker->runner;
        views_.push_back(std::move(worker));
        return runner;
    }

    void start() {
        for (auto& source : sources_) source->pump->start();
        for (auto& view : views_) view->runner->start();
    }
    void stop() noexcept {
        for (auto& view : views_) view->runner->stop();
        for (auto& source : sources_) source->pump->stop();
        for (auto& view : views_) if (IsWindow(view->window.hwnd)) DestroyWindow(view->window.hwnd);
    }
    [[nodiscard]] CaptureOnlyPump* source_worker(visual::core::SourceId id) noexcept {
        for (auto& source : sources_) if (source->id == id) return source->pump.get();
        return nullptr;
    }
    [[nodiscard]] SecondaryViewRunner* view_worker(visual::core::ViewId id) noexcept {
        for (auto& view : views_) if (view->id == id) return view->runner.get();
        return nullptr;
    }
    void stop_source(visual::core::SourceId id) noexcept {
        if (auto* worker = source_worker(id)) worker->stop();
    }
    ~WorkspaceRuntimeCollection() { stop(); }

private:
    std::vector<std::unique_ptr<SourceWorker>> sources_;
    std::vector<std::unique_ptr<ViewWorker>> views_;
};


int choose_source(const std::vector<MonitorRecord>& monitors, int requested, const std::wstring& persisted_device) {
    if (requested >= 0) return requested;
    const int persisted = find_monitor_by_device(monitors, persisted_device);
    if (persisted >= 0) return persisted;
    for (std::size_t i = 0; i < monitors.size(); ++i) if (monitors[i].primary) return static_cast<int>(i);
    return 0;
}

int choose_destination(const std::vector<MonitorRecord>& monitors, int source, int requested, bool single_monitor,
                       const std::wstring& persisted_device) {
    if (single_monitor) return source;
    if (requested >= 0) return requested;
    const int persisted = find_monitor_by_device(monitors, persisted_device);
    if (persisted >= 0 && persisted != source) return persisted;
    for (std::size_t i = 0; i < monitors.size(); ++i) if (static_cast<int>(i) != source) return static_cast<int>(i);
    return -1;
}

std::vector<visual::ui::MonitorOption> make_monitor_options(const std::vector<MonitorRecord>& monitors) {
    std::vector<visual::ui::MonitorOption> result;
    result.reserve(monitors.size());
    for (std::size_t i = 0; i < monitors.size(); ++i) {
        const auto& monitor = monitors[i];
        std::wstringstream label;
        label << L"Screen " << (i + 1) << L" - "
              << monitor.mode.dmPelsWidth << L" x " << monitor.mode.dmPelsHeight;
        if (monitor.primary) label << L" (Primary)";
        result.push_back({monitor.deviceName, label.str()});
    }
    return result;
}

} // namespace

int run_workspace_generation(HINSTANCE instance, const Options& options, std::uint64_t processGeneration) {
    try {
        g_shutdownReason.store(static_cast<int>(ShutdownReason::User), std::memory_order_relaxed);
        g_captureFailed.store(false, std::memory_order_relaxed);
        g_contextViewMessagePending.store(false, std::memory_order_relaxed);
        g_healthCheckMode.store(options.healthCheck, std::memory_order_relaxed);

        g_settingsPath = visual::settings::default_settings_path();
        auto persistedSettings = visual::settings::load_settings(g_settingsPath);
        auto persistedAssistance = visual::settings::load_assistance_state(g_settingsPath);
        {
            std::scoped_lock lock(g_settingsMutex);
            g_settings = persistedSettings;
        }
        {
            std::scoped_lock lock(g_assistanceMutex);
            g_assistanceState = persistedAssistance;
        }
        g_selectedViewId.store(visual::core::kCurrentDetailViewId.value, std::memory_order_relaxed);
        apply_runtime_settings(persistedSettings);
        if (options.zoomSpecified) {
            g_zoom.store(options.zoom, std::memory_order_relaxed);
            if (options.zoom > 1.0) g_previousMagnifiedZoom.store(options.zoom, std::memory_order_relaxed);
        }

        const auto monitors = enumerate_monitors();
        if (monitors.empty()) {
            if (!options.healthCheck) MessageBoxW(nullptr, L"No active display was detected.", L"Vision", MB_OK | MB_ICONERROR);
            return 2;
        }

        visual::core::MonitorRegistry monitorRegistry;
        std::vector<visual::core::MonitorSnapshot> monitorSnapshots;
        monitorSnapshots.reserve(monitors.size());
        for (const auto& monitor : monitors) {
            visual::core::MonitorSnapshot snapshot{};
            snapshot.bounds = {static_cast<double>(monitor.rect.left), static_cast<double>(monitor.rect.top),
                               static_cast<double>(monitor.rect.right), static_cast<double>(monitor.rect.bottom)};
            snapshot.primary = monitor.primary;
            snapshot.dpi_x = monitor.dpiX;
            snapshot.dpi_y = monitor.dpiY;
            snapshot.orientation = monitor.mode.dmDisplayOrientation;
            snapshot.identity.gdi_device_name = monitor.deviceName;
            monitorSnapshots.push_back(std::move(snapshot));
        }
        (void)monitorRegistry.update(std::move(monitorSnapshots));

        const bool singleMonitor = options.forceSingleMonitor || monitors.size() == 1;
        const int sourceIndex = choose_source(monitors, options.sourceIndex, persistedSettings.context_monitor_device);
        const int destIndex = choose_destination(monitors, sourceIndex, options.destIndex, singleMonitor,
                                                 persistedSettings.detail_monitor_device);
        if (sourceIndex < 0 || sourceIndex >= static_cast<int>(monitors.size())
            || destIndex < 0 || destIndex >= static_cast<int>(monitors.size())
            || (!singleMonitor && sourceIndex == destIndex)) {
            if (!options.healthCheck) MessageBoxW(nullptr, L"Invalid Context/Detail screen selection.", L"Vision", MB_OK | MB_ICONERROR);
            return 3;
        }

        // Persisted display roles are user intent. Runtime resolution is transient and must not
        // rewrite intent merely because a display is temporarily absent or a fallback was selected.
        const visual::core::WorkspaceIntent workspaceIntent{
            persistedSettings.context_monitor_device,
            persistedSettings.detail_monitor_device,
            persistedSettings.reference_monitor_device
        };
        visual::core::ResolvedWorkspace resolvedWorkspace{};
        resolvedWorkspace.detail_binding.source_monitor_device =
            monitors[static_cast<std::size_t>(sourceIndex)].deviceName;
        resolvedWorkspace.detail_binding.destination_monitor_device =
            monitors[static_cast<std::size_t>(destIndex)].deviceName;
        resolvedWorkspace.single_monitor_fallback = singleMonitor;
        resolvedWorkspace.context_intent_resolved = workspaceIntent.context_monitor_device.empty()
            || find_monitor_by_device(monitors, workspaceIntent.context_monitor_device) >= 0;
        resolvedWorkspace.detail_intent_resolved = workspaceIntent.detail_monitor_device.empty()
            || find_monitor_by_device(monitors, workspaceIntent.detail_monitor_device) >= 0;
        resolvedWorkspace.reference_intent_resolved = workspaceIntent.reference_monitor_device.empty()
            || find_monitor_by_device(monitors, workspaceIntent.reference_monitor_device) >= 0;

        visual::core::ViewSessionState detailSession{};
        detailSession.id = visual::core::kCurrentDetailViewId;
        detailSession.binding = resolvedWorkspace.detail_binding;
        visual::core::WorkspaceCoordinator workspace(detailSession);
        workspace.set_topology_generation(monitorRegistry.snapshot().generation);
        visual::core::WorkspaceRuntimeGraph runtimeGraph;
        (void)runtimeGraph.add_source(visual::core::SourceId{1});
        (void)runtimeGraph.add_view(detailSession.id, visual::core::SourceId{1});
        (void)runtimeGraph.select(detailSession.id);
        g_selectedViewId.store(workspace.snapshot().selected_view.value, std::memory_order_relaxed);

        Telemetry telemetry(options.logPath, processGeneration > 1);
        telemetry.event("workspace_generation_" + std::to_string(processGeneration));
        telemetry.event("workspace_1_topology_generation_2");
        telemetry.event(resolvedWorkspace.context_intent_resolved ? "context_binding_resolved" : "context_binding_fallback_unresolved_intent");
        telemetry.event(resolvedWorkspace.detail_intent_resolved ? "detail_binding_resolved" : "detail_binding_fallback_unresolved_intent");
        telemetry.event(resolvedWorkspace.reference_intent_resolved ? "reference_binding_resolved_or_unused" : "reference_binding_unresolved_intent");
        telemetry.event("view_selected_detail_1");
        telemetry.event("movement_owner_detail_1");
        telemetry.event("telemetry_started");
        auto window = create_detail_window(instance, monitors[static_cast<std::size_t>(destIndex)], singleMonitor);
        GpuDeviceDomain gpu;
        gpu.initialize();
        CaptureSource captureSource(gpu);
        OutputPresenter output(gpu);
        Renderer renderer(gpu, output, options.reconstructionMode);
        renderer.initialize(window.hwnd, window.width, window.height);

        WindowPlacement secondaryWindow{};
        std::unique_ptr<OutputPresenter> secondaryOutput;
        std::unique_ptr<Renderer> secondaryRenderer;
        std::unique_ptr<SecondaryViewRunner> secondaryRunner;
        if (options.fanoutSelfTest) {
            visual::core::ViewSessionState secondarySession{};
            secondarySession.id = visual::core::ViewId{2};
            secondarySession.binding = resolvedWorkspace.detail_binding;
            if (!workspace.add_session(secondarySession)) throw std::runtime_error("Unable to add secondary fan-out ViewSession");
            (void)runtimeGraph.add_view(secondarySession.id, visual::core::SourceId{1});
            secondaryWindow = create_detail_window(instance, monitors[static_cast<std::size_t>(destIndex)], true);
            telemetry.event("fanout_secondary_window_created");
            secondaryOutput = std::make_unique<OutputPresenter>(gpu, 120);
            telemetry.event("fanout_secondary_output_allocated");
            secondaryRenderer = std::make_unique<Renderer>(gpu, *secondaryOutput);
            try {
                secondaryRenderer->initialize(secondaryWindow.hwnd, secondaryWindow.width, secondaryWindow.height);
            } catch (const winrt::hresult_error& e) {
                telemetry.event("fanout_secondary_renderer_hresult_" + std::to_string(static_cast<unsigned>(e.code().value)));
                throw;
            }
            telemetry.event("fanout_secondary_renderer_created");
            secondaryRunner = std::make_unique<SecondaryViewRunner>(
                captureSource, *secondaryRenderer, telemetry, monitors[static_cast<std::size_t>(sourceIndex)],
                secondarySession.id, 4.0, visual::core::VisualMode::Inverted, &runtimeGraph);
            telemetry.event("fanout_source_one_views_two");
        }

        WorkspaceRuntimeCollection extraRuntime;
        if (options.multiSourceSelfTest) {
            if (monitors.size() < 2) throw std::runtime_error("Multi-source self-test requires two displays");
            SetWindowDisplayAffinity(window.hwnd, kExcludeFromCapture);
            const visual::core::SourceId source2{2};
            const visual::core::ViewId view3{3};
            (void)runtimeGraph.add_source(source2);
            (void)runtimeGraph.add_view(view3, source2);
            auto& source = extraRuntime.add_source(
                gpu, telemetry, monitors[static_cast<std::size_t>(destIndex)], source2);
            (void)extraRuntime.add_view(
                instance, gpu, telemetry, runtimeGraph, source,
                monitors[static_cast<std::size_t>(destIndex)],
                monitors[static_cast<std::size_t>(sourceIndex)],
                view3, 3.0, visual::core::VisualMode::Grayscale);
            telemetry.event("multisource_two_sources_two_views_ready");
        }

        visual::ui::ContextOverlay contextOverlay;
        if (!options.healthCheck && !singleMonitor) {
            if (contextOverlay.create(instance, monitors[static_cast<std::size_t>(sourceIndex)].rect)) {
                g_contextOverlay = &contextOverlay;
                telemetry.event("context_indicator_ready");
            } else {
                telemetry.event("context_indicator_unavailable");
            }
        }

        visual::ui::HintWindow hintWindow;
        visual::ui::HelpWindow helpWindow;
        visual::ui::SettingsWindow settingsWindow;
        if (!options.healthCheck) {
            const RECT contextRect = monitors[static_cast<std::size_t>(sourceIndex)].rect;
            if (hintWindow.create(instance, contextRect)) {
                g_hintWindow = &hintWindow;
                telemetry.event("assistance_hint_ui_ready");
            } else {
                telemetry.event("assistance_hint_ui_unavailable");
            }

            const int monitorCount = static_cast<int>(monitors.size());
            if (helpWindow.create(instance, window.hwnd, contextRect,
                                  [monitorCount, singleMonitor]() {
                                      visual::core::VisualSettings current{};
                                      {
                                          std::scoped_lock lock(g_settingsMutex);
                                          current = g_settings;
                                      }
                                      current.zoom = g_zoom.load(std::memory_order_relaxed);
                                      current.tracking_enabled = g_trackingEnabled.load(std::memory_order_relaxed);
                                      current.follow_pointer = g_followPointer.load(std::memory_order_relaxed);
                                      current.follow_caret = g_followCaret.load(std::memory_order_relaxed);
                                      current.follow_focus = g_followFocus.load(std::memory_order_relaxed);
                                      current.show_pointer_locator = g_showPointerLocator.load(std::memory_order_relaxed);
                                      current.show_caret_locator = g_showCaretLocator.load(std::memory_order_relaxed);
                                      current.show_focus_locator = g_showFocusLocator.load(std::memory_order_relaxed);
                                      current.show_context_indicator = g_showContextIndicator.load(std::memory_order_relaxed);
                                      current.shade_context_indicator = g_shadeContextIndicator.load(std::memory_order_relaxed);
                                      current.visual_mode = visual::core::sanitize_visual_mode(g_visualMode.load(std::memory_order_relaxed));
                                      return visual::core::build_assistant_context_json(current, monitorCount, singleMonitor);
                                  })) {
                g_helpWindow = &helpWindow;
                telemetry.event("help_ui_ready");
            } else {
                telemetry.event("help_ui_unavailable");
            }

            visual::core::VisualSettings uiSettings{};
            {
                std::scoped_lock lock(g_settingsMutex);
                uiSettings = g_settings;
            }
            const auto monitorOptions = make_monitor_options(monitors);
            if (settingsWindow.create(instance, window.hwnd, contextRect,
                                      monitorOptions, uiSettings,
                                      [&](const visual::core::VisualSettings& next, bool displayRolesChanged) {
                                          adopt_settings(next, true);
                                          telemetry.event(displayRolesChanged ? "settings_saved_display_restart_required" : "settings_applied");
                                      },
                                      []() { show_help(); })) {
                g_settingsWindow = &settingsWindow;
                telemetry.event("settings_ui_ready");
            } else {
                telemetry.event("settings_ui_unavailable");
            }
        }

        visual::tracking::EvidenceHub evidenceHub;
        CaptureRunner capture(gpu, captureSource, renderer, telemetry, workspace, evidenceHub,
                              detailSession.id, monitors[static_cast<std::size_t>(sourceIndex)], window.hwnd);
        capture.start();
        if (secondaryRunner) secondaryRunner->start();
        extraRuntime.start();
        if (options.topologyReconcileSelfTest && processGeneration == 1) {
            telemetry.event("topology_reconcile_self_test_signal");
            PostMessageW(window.hwnd, WM_DISPLAYCHANGE, 0, 0);
        }
        if (!options.healthCheck && !singleMonitor && g_hintWindow
            && claim_assistance_hint(AssistanceHint::ScreenRoles)) {
            g_hintWindow->show(L"Context and Detail",
                L"Context keeps the full 1x workspace visible. Detail is magnified. The View Locator frame on Context shows exactly what Detail is displaying.",
                8500);
            telemetry.event("assistance_hint_screen_roles");
        }
        if (options.healthCheck) {
            bool multiFailureInjected = false;
            std::uint64_t primaryFramesAtSource2Stop = 0;
            std::uint64_t source2ViewFramesAtStop = 0;
            const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(options.healthTimeoutMs);
            while (std::chrono::steady_clock::now() < deadline) {
                MSG healthMsg{};
                while (PeekMessageW(&healthMsg, nullptr, 0, 0, PM_REMOVE)) {
                    if (healthMsg.message != WM_QUIT) {
                        TranslateMessage(&healthMsg);
                        DispatchMessageW(&healthMsg);
                    }
                }
                const bool fanoutReady = !options.fanoutSelfTest
                    || (secondaryRunner && secondaryRunner->render_observed()
                        && secondaryRunner->frames() >= 5 && capture.render_frames() >= 30);
                if (options.multiSourceSelfTest && !multiFailureInjected
                    && extraRuntime.source_worker(visual::core::SourceId{2})
                    && extraRuntime.source_worker(visual::core::SourceId{2})->frame_observed()
                    && extraRuntime.view_worker(visual::core::ViewId{3})
                    && extraRuntime.view_worker(visual::core::ViewId{3})->frames() >= 5
                    && capture.render_frames() >= 30) {
                    primaryFramesAtSource2Stop = capture.render_frames();
                    source2ViewFramesAtStop = extraRuntime.view_worker(visual::core::ViewId{3})->frames();
                    extraRuntime.stop_source(visual::core::SourceId{2});
                    (void)runtimeGraph.set_source_state(visual::core::SourceId{2}, visual::core::RuntimeNodeState::Failed);
                    multiFailureInjected = true;
                    telemetry.event("multisource_source_2_suspended");
                }
                const bool multiSourceReady = !options.multiSourceSelfTest
                    || (multiFailureInjected
                        && capture.render_frames() >= primaryFramesAtSource2Stop + 20
                        && extraRuntime.view_worker(visual::core::ViewId{3})->frames() <= source2ViewFramesAtStop + 1);
                if (capture.health_ready() && fanoutReady && multiSourceReady) {
                    if (options.fanoutSelfTest) telemetry.event("fanout_health_pass");
                    if (options.multiSourceSelfTest) telemetry.event("multisource_health_pass");
                    telemetry.event("health_check_pass");
                    extraRuntime.stop();
                    if (secondaryRunner) secondaryRunner->stop();
                    capture.stop();
                    if (IsWindow(secondaryWindow.hwnd)) DestroyWindow(secondaryWindow.hwnd);
                    if (IsWindow(window.hwnd)) DestroyWindow(window.hwnd);
                    return 0;
                }
                const auto shutdown = static_cast<ShutdownReason>(g_shutdownReason.load(std::memory_order_relaxed));
                if (shutdown == ShutdownReason::CaptureFailure || g_captureFailed.load(std::memory_order_relaxed)) {
                    capture.stop();
                    return 10;
                }
                if (shutdown == ShutdownReason::CaptureSourceClosed) { capture.stop(); return 11; }
                if (shutdown == ShutdownReason::DisplayTopologyChanged) { capture.stop(); return 12; }
                std::this_thread::sleep_for(std::chrono::milliseconds(20));
            }
            telemetry.event("health_check_timeout");
            extraRuntime.stop();
            if (secondaryRunner) secondaryRunner->stop();
            capture.stop();
            if (IsWindow(secondaryWindow.hwnd)) DestroyWindow(secondaryWindow.hwnd);
            if (IsWindow(window.hwnd)) DestroyWindow(window.hwnd);
            return 30;
        }

        MSG msg{};
        while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
            if (helpWindow.hwnd() && IsDialogMessageW(helpWindow.hwnd(), &msg)) continue;
            if (settingsWindow.hwnd() && IsDialogMessageW(settingsWindow.hwnd(), &msg)) continue;
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        extraRuntime.stop();
        if (secondaryRunner) secondaryRunner->stop();
        capture.stop();
        if (IsWindow(secondaryWindow.hwnd)) DestroyWindow(secondaryWindow.hwnd);
        g_settingsWindow = nullptr;
        settingsWindow.destroy();
        g_helpWindow = nullptr;
        helpWindow.destroy();
        g_hintWindow = nullptr;
        hintWindow.destroy();
        g_contextOverlay = nullptr;
        contextOverlay.destroy();

        const auto shutdown = static_cast<ShutdownReason>(g_shutdownReason.load(std::memory_order_relaxed));
        switch (shutdown) {
        case ShutdownReason::CaptureFailure:
            telemetry.event("shutdown_capture_failure");
            return 10;
        case ShutdownReason::CaptureSourceClosed:
            telemetry.event("shutdown_capture_source_closed");
            return 11;
        case ShutdownReason::DisplayTopologyChanged:
            telemetry.event("shutdown_display_topology_changed");
            return 12;
        case ShutdownReason::User:
        default:
            return g_captureFailed.load(std::memory_order_relaxed) ? 10 : 0;
        }
    } catch (const winrt::hresult_error& e) {
        const std::wstring text = L"HRESULT failure: " + format_hr(e.code()) + L"\n" + std::wstring(e.message().c_str());
        if (!g_healthCheckMode.load(std::memory_order_relaxed)) MessageBoxW(nullptr, text.c_str(), L"Vision", MB_OK | MB_ICONERROR);
        return 20;
    } catch (const std::exception& e) {
        const std::string s = e.what();
        const std::wstring message(s.begin(), s.end());
        if (!g_healthCheckMode.load(std::memory_order_relaxed)) MessageBoxW(nullptr, message.c_str(), L"Vision", MB_OK | MB_ICONERROR);
        return 21;
    } catch (...) {
        if (!g_healthCheckMode.load(std::memory_order_relaxed)) MessageBoxW(nullptr, L"Unknown fatal error.", L"Vision", MB_OK | MB_ICONERROR);
        return 22;
    }
}


int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    try {
        SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        const auto options = parse_options();

        visual::core::TopologyReconciler reconciler(500);
        std::uint64_t topologyGeneration = 1;
        for (;;) {
            const int result = run_workspace_generation(instance, options, topologyGeneration);
            if (result != 12 || (options.healthCheck && !options.topologyReconcileSelfTest)) return result;

            const auto monotonic_ms = []() -> std::uint64_t {
                return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now().time_since_epoch()).count());
            };
            reconciler.signal_change(monotonic_ms());
            while (reconciler.poll(monotonic_ms()) != visual::core::TopologyReconcileState::RebuildReady) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }

            // DestroyWindow posts WM_QUIT. A new in-process workspace generation must not
            // inherit that terminal message from the previous detail window.
            MSG stale{};
            while (PeekMessageW(&stale, nullptr, WM_QUIT, WM_QUIT, PM_REMOVE)) {}
            reconciler.rebuild_completed(++topologyGeneration);
        }
    } catch (const winrt::hresult_error& e) {
        const std::wstring text = L"HRESULT failure during topology reconciliation: " + format_hr(e.code())
            + L"\n" + std::wstring(e.message().c_str());
        MessageBoxW(nullptr, text.c_str(), L"Vision", MB_OK | MB_ICONERROR);
        return 20;
    } catch (const std::exception& e) {
        const std::string text = e.what();
        MessageBoxA(nullptr, text.c_str(), "Vision", MB_OK | MB_ICONERROR);
        return 21;
    }
}
