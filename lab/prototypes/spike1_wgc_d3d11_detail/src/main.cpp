#include <windows.h>
#include <shellapi.h>
#include <shellscalingapi.h>
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

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool;
using winrt::Windows::Graphics::Capture::GraphicsCaptureItem;
using winrt::Windows::Graphics::Capture::GraphicsCaptureSession;
using winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DDevice;
using winrt::Windows::Graphics::DirectX::DirectXPixelFormat;
using AbiDxgiInterfaceAccess = Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess;

namespace {

constexpr wchar_t kWindowClass[] = L"VisualSpike1DetailWindow";
constexpr UINT kCaptureErrorMessage = WM_APP + 1;
constexpr DWORD kExcludeFromCapture = 0x00000011; // WDA_EXCLUDEFROMCAPTURE, available on modern Windows.

std::atomic<int> g_zoom{2};
std::atomic<bool> g_captureFailed{false};

struct MonitorRecord {
    HMONITOR handle{};
    RECT rect{};
    bool primary{};
    std::wstring deviceName;
    std::wstring adapterName;
    DEVMODEW mode{};
    UINT dpiX{96};
    UINT dpiY{96};
};

struct Options {
    int sourceIndex{-1};
    int destIndex{-1};
    int zoom{2};
    bool forceSingleMonitor{false};
    std::filesystem::path logPath{L"spike1_telemetry.csv"};
};

struct WindowPlacement {
    HWND hwnd{};
    UINT width{};
    UINT height{};
    bool singleMonitor{};
    bool excludedFromCapture{};
    DWORD exclusionError{};
};

struct Vertex { float x, y, u, v; };
struct CropConstants { float uvScale[2]; float uvOffset[2]; };

LARGE_INTEGER qpc_now() { LARGE_INTEGER v{}; QueryPerformanceCounter(&v); return v; }
LARGE_INTEGER qpc_frequency() { LARGE_INTEGER v{}; QueryPerformanceFrequency(&v); return v; }
double qpc_seconds(LARGE_INTEGER value, LARGE_INTEGER frequency) {
    return static_cast<double>(value.QuadPart) / static_cast<double>(frequency.QuadPart);
}

std::string narrow(std::wstring const& value) {
    if (value.empty()) return {};
    int required = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    std::string result(static_cast<size_t>(required), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), required, nullptr, nullptr);
    return result;
}

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
    GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &record.dpiX, &record.dpiY);

    DISPLAY_DEVICEW adapter{};
    adapter.cb = sizeof(adapter);
    for (DWORD i = 0; EnumDisplayDevicesW(nullptr, i, &adapter, 0); ++i) {
        if (record.deviceName == adapter.DeviceName) {
            record.adapterName = adapter.DeviceString;
            break;
        }
        adapter = {};
        adapter.cb = sizeof(adapter);
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
        std::wstring arg = argv[i];
        auto next_value = [&]() -> std::wstring {
            if (i + 1 >= argc) throw std::runtime_error("Missing command line value");
            return argv[++i];
        };
        if (arg == L"--source") options.sourceIndex = std::stoi(next_value());
        else if (arg == L"--dest") options.destIndex = std::stoi(next_value());
        else if (arg == L"--zoom") options.zoom = std::stoi(next_value());
        else if (arg == L"--log") options.logPath = next_value();
        else if (arg == L"--single-monitor") options.forceSingleMonitor = true;
    }
    LocalFree(argv);
    if (options.zoom != 2 && options.zoom != 4) options.zoom = 2;
    return options;
}

class Telemetry {
public:
    explicit Telemetry(std::filesystem::path const& path)
        : stream_(path, std::ios::out | std::ios::trunc), qpcFreq_(qpc_frequency()) {
        if (!stream_) throw std::runtime_error("Unable to create telemetry file");
    }

    void comment(std::string const& key, std::string const& value) {
        std::scoped_lock lock(mutex_);
        stream_ << "# " << key << '=' << value << '\n';
        stream_.flush();
    }

    void begin_frames() {
        std::scoped_lock lock(mutex_);
        stream_ << "frame,frame_time_100ns,arrival_qpc,arrival_minus_frame_timestamp_us,render_start_qpc,render_start_minus_frame_timestamp_us,present_call_qpc,present_return_qpc,present_call_duration_us,present_hr,content_w,content_h,zoom,gpu_copy\n";
        stream_.flush();
    }

    void frame(uint64_t sequence, int64_t frameTime100ns, LARGE_INTEGER arrivalQpc, LARGE_INTEGER renderStartQpc,
               LARGE_INTEGER presentCallQpc, LARGE_INTEGER presentReturnQpc,
               HRESULT presentHr, int width, int height, int zoom, bool gpuCopy) {
        const double frameSeconds = static_cast<double>(frameTime100ns) / 10'000'000.0;
        const double arrivalDeltaUs = (qpc_seconds(arrivalQpc, qpcFreq_) - frameSeconds) * 1'000'000.0;
        const double renderStartDeltaUs = (qpc_seconds(renderStartQpc, qpcFreq_) - frameSeconds) * 1'000'000.0;
        const double presentDurationUs = (qpc_seconds(presentReturnQpc, qpcFreq_) - qpc_seconds(presentCallQpc, qpcFreq_)) * 1'000'000.0;

        std::scoped_lock lock(mutex_);
        stream_ << sequence << ',' << frameTime100ns << ',' << arrivalQpc.QuadPart << ','
                << std::fixed << std::setprecision(3) << arrivalDeltaUs << ',' << renderStartQpc.QuadPart << ','
                << renderStartDeltaUs << ',' << presentCallQpc.QuadPart << ',' << presentReturnQpc.QuadPart << ','
                << presentDurationUs << ',' << static_cast<unsigned>(presentHr) << ',' << width << ',' << height
                << ',' << zoom << ',' << (gpuCopy ? 1 : 0) << '\n';
        if ((sequence % 120) == 0) stream_.flush();
    }

    void event(std::string const& name, std::string const& detail) {
        std::scoped_lock lock(mutex_);
        stream_ << "# event=" << name << ",detail=" << detail << '\n';
        stream_.flush();
    }

    LARGE_INTEGER qpc_frequency_value() const { return qpcFreq_; }

private:
    std::ofstream stream_;
    std::mutex mutex_;
    LARGE_INTEGER qpcFreq_{};
};

class Renderer {
public:
    void initialize(HWND hwnd, UINT width, UINT height) {
        hwnd_ = hwnd;
        width_ = width;
        height_ = height;

        UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        D3D_FEATURE_LEVEL requested[] = {D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0};
        D3D_FEATURE_LEVEL actual{};
        winrt::check_hresult(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags, requested,
            ARRAYSIZE(requested), D3D11_SDK_VERSION, device_.put(), &actual, context_.put()));

        auto dxgiDevice = device_.as<IDXGIDevice>();
        winrt::com_ptr<IDXGIAdapter> adapter;
        winrt::check_hresult(dxgiDevice->GetAdapter(adapter.put()));
        DXGI_ADAPTER_DESC adapterDesc{};
        adapter->GetDesc(&adapterDesc);
        adapterDescription_ = adapterDesc.Description;

        winrt::com_ptr<IDXGIFactory2> factory;
        winrt::check_hresult(adapter->GetParent(__uuidof(IDXGIFactory2), factory.put_void()));

        DXGI_SWAP_CHAIN_DESC1 desc{};
        desc.Width = width_;
        desc.Height = height_;
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 2;
        desc.Scaling = DXGI_SCALING_STRETCH;
        desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        desc.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
        winrt::check_hresult(factory->CreateSwapChainForHwnd(device_.get(), hwnd_, &desc, nullptr, nullptr, swapChain_.put()));
        factory->MakeWindowAssociation(hwnd_, DXGI_MWA_NO_ALT_ENTER);

        create_render_target();
        create_pipeline();
        create_winrt_device();
    }

    IDirect3DDevice winrt_device() const { return winrtDevice_; }
    std::wstring const& adapter_description() const { return adapterDescription_; }

    HRESULT render(ID3D11Texture2D* source, RECT const& sourceMonitorRect, int zoom, bool& gpuCopy, LARGE_INTEGER& presentCallQpc, LARGE_INTEGER& presentReturnQpc) {
        gpuCopy = false;
        if (!source) return E_POINTER;

        D3D11_TEXTURE2D_DESC sourceDesc{};
        source->GetDesc(&sourceDesc);
        ID3D11Texture2D* sampleTexture = source;
        if ((sourceDesc.BindFlags & D3D11_BIND_SHADER_RESOURCE) == 0) {
            ensure_scratch(sourceDesc);
            context_->CopyResource(scratchTexture_.get(), source);
            sampleTexture = scratchTexture_.get();
            gpuCopy = true;
        }

        winrt::com_ptr<ID3D11ShaderResourceView> srv;
        HRESULT hr = device_->CreateShaderResourceView(sampleTexture, nullptr, srv.put());
        if (FAILED(hr)) return hr;

        POINT cursor{};
        GetCursorPos(&cursor);
        const float monitorWidth = static_cast<float>(std::max<LONG>(1, sourceMonitorRect.right - sourceMonitorRect.left));
        const float monitorHeight = static_cast<float>(std::max<LONG>(1, sourceMonitorRect.bottom - sourceMonitorRect.top));
        const float normalizedX = std::clamp(static_cast<float>(cursor.x - sourceMonitorRect.left) / monitorWidth, 0.0f, 1.0f);
        const float normalizedY = std::clamp(static_cast<float>(cursor.y - sourceMonitorRect.top) / monitorHeight, 0.0f, 1.0f);

        const float cropWidth = static_cast<float>(sourceDesc.Width) / static_cast<float>(zoom);
        const float cropHeight = static_cast<float>(sourceDesc.Height) / static_cast<float>(zoom);
        float cropLeft = normalizedX * static_cast<float>(sourceDesc.Width) - cropWidth * 0.5f;
        float cropTop = normalizedY * static_cast<float>(sourceDesc.Height) - cropHeight * 0.5f;
        cropLeft = std::clamp(cropLeft, 0.0f, static_cast<float>(sourceDesc.Width) - cropWidth);
        cropTop = std::clamp(cropTop, 0.0f, static_cast<float>(sourceDesc.Height) - cropHeight);

        CropConstants constants{{cropWidth / static_cast<float>(sourceDesc.Width), cropHeight / static_cast<float>(sourceDesc.Height)},
                                {cropLeft / static_cast<float>(sourceDesc.Width), cropTop / static_cast<float>(sourceDesc.Height)}};
        D3D11_MAPPED_SUBRESOURCE mapped{};
        hr = context_->Map(cropBuffer_.get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped);
        if (FAILED(hr)) return hr;
        *reinterpret_cast<CropConstants*>(mapped.pData) = constants;
        context_->Unmap(cropBuffer_.get(), 0);

        FLOAT clear[4] = {0, 0, 0, 1};
        context_->ClearRenderTargetView(renderTarget_.get(), clear);
        UINT stride = sizeof(Vertex), offset = 0;
        ID3D11Buffer* vertexBuffers[] = {vertexBuffer_.get()};
        context_->IASetInputLayout(inputLayout_.get());
        context_->IASetVertexBuffers(0, 1, vertexBuffers, &stride, &offset);
        context_->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        D3D11_VIEWPORT viewport{0, 0, static_cast<float>(width_), static_cast<float>(height_), 0.0f, 1.0f};
        context_->RSSetViewports(1, &viewport);
        ID3D11RenderTargetView* renderTargets[] = {renderTarget_.get()};
        context_->OMSetRenderTargets(1, renderTargets, nullptr);
        context_->VSSetShader(vertexShader_.get(), nullptr, 0);
        context_->PSSetShader(pixelShader_.get(), nullptr, 0);
        ID3D11ShaderResourceView* srvs[] = {srv.get()};
        ID3D11SamplerState* samplers[] = {sampler_.get()};
        ID3D11Buffer* constantBuffers[] = {cropBuffer_.get()};
        context_->PSSetShaderResources(0, 1, srvs);
        context_->PSSetSamplers(0, 1, samplers);
        context_->PSSetConstantBuffers(0, 1, constantBuffers);
        context_->Draw(6, 0);
        ID3D11ShaderResourceView* nullSrv[] = {nullptr};
        context_->PSSetShaderResources(0, 1, nullSrv);
        presentCallQpc = qpc_now();
        HRESULT presentHr = swapChain_->Present(1, 0);
        presentReturnQpc = qpc_now();
        return presentHr;
    }

private:
    void create_winrt_device() {
        auto dxgiDevice = device_.as<IDXGIDevice>();
        winrt::com_ptr<IInspectable> inspectable;
        winrt::check_hresult(CreateDirect3D11DeviceFromDXGIDevice(dxgiDevice.get(), inspectable.put()));
        winrtDevice_ = inspectable.as<IDirect3DDevice>();
    }

    void create_render_target() {
        winrt::com_ptr<ID3D11Texture2D> backBuffer;
        winrt::check_hresult(swapChain_->GetBuffer(0, __uuidof(ID3D11Texture2D), backBuffer.put_void()));
        winrt::check_hresult(device_->CreateRenderTargetView(backBuffer.get(), nullptr, renderTarget_.put()));
    }

    winrt::com_ptr<ID3DBlob> compile_shader(char const* source, char const* entry, char const* target) {
        winrt::com_ptr<ID3DBlob> shader, errors;
        HRESULT hr = D3DCompile(source, strlen(source), nullptr, nullptr, nullptr, entry, target,
            D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, shader.put(), errors.put());
        if (FAILED(hr)) {
            if (errors) OutputDebugStringA(static_cast<char const*>(errors->GetBufferPointer()));
            winrt::check_hresult(hr);
        }
        return shader;
    }

    void create_pipeline() {
        static constexpr char shaderSource[] = R"(
cbuffer CropConstants : register(b0) { float2 uvScale; float2 uvOffset; };
struct VSInput { float2 pos : POSITION; float2 uv : TEXCOORD0; };
struct VSOutput { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };
VSOutput VSMain(VSInput input) { VSOutput o; o.pos=float4(input.pos,0,1); o.uv=input.uv; return o; }
Texture2D SourceTexture : register(t0);
SamplerState LinearSampler : register(s0);
float4 PSMain(VSOutput input) : SV_TARGET { return SourceTexture.Sample(LinearSampler, uvOffset + input.uv * uvScale); }
)";
        auto vsBlob = compile_shader(shaderSource, "VSMain", "vs_5_0");
        auto psBlob = compile_shader(shaderSource, "PSMain", "ps_5_0");
        winrt::check_hresult(device_->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, vertexShader_.put()));
        winrt::check_hresult(device_->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, pixelShader_.put()));
        D3D11_INPUT_ELEMENT_DESC inputDesc[] = {
            {"POSITION",0,DXGI_FORMAT_R32G32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,8,D3D11_INPUT_PER_VERTEX_DATA,0},
        };
        winrt::check_hresult(device_->CreateInputLayout(inputDesc, ARRAYSIZE(inputDesc), vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), inputLayout_.put()));
        const Vertex vertices[] = {{-1,1,0,0},{1,1,1,0},{1,-1,1,1},{-1,1,0,0},{1,-1,1,1},{-1,-1,0,1}};
        D3D11_BUFFER_DESC vbDesc{}; vbDesc.ByteWidth=sizeof(vertices); vbDesc.Usage=D3D11_USAGE_IMMUTABLE; vbDesc.BindFlags=D3D11_BIND_VERTEX_BUFFER;
        D3D11_SUBRESOURCE_DATA vbData{}; vbData.pSysMem=vertices;
        winrt::check_hresult(device_->CreateBuffer(&vbDesc, &vbData, vertexBuffer_.put()));
        D3D11_BUFFER_DESC cbDesc{}; cbDesc.ByteWidth=sizeof(CropConstants); cbDesc.Usage=D3D11_USAGE_DYNAMIC; cbDesc.BindFlags=D3D11_BIND_CONSTANT_BUFFER; cbDesc.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;
        winrt::check_hresult(device_->CreateBuffer(&cbDesc, nullptr, cropBuffer_.put()));
        D3D11_SAMPLER_DESC samplerDesc{}; samplerDesc.Filter=D3D11_FILTER_MIN_MAG_MIP_LINEAR; samplerDesc.AddressU=samplerDesc.AddressV=samplerDesc.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP; samplerDesc.MaxLOD=D3D11_FLOAT32_MAX;
        winrt::check_hresult(device_->CreateSamplerState(&samplerDesc, sampler_.put()));
    }

    void ensure_scratch(D3D11_TEXTURE2D_DESC const& sourceDesc) {
        bool recreate = !scratchTexture_;
        if (scratchTexture_) {
            D3D11_TEXTURE2D_DESC existing{}; scratchTexture_->GetDesc(&existing);
            recreate = existing.Width != sourceDesc.Width || existing.Height != sourceDesc.Height || existing.Format != sourceDesc.Format;
        }
        if (!recreate) return;
        D3D11_TEXTURE2D_DESC desc = sourceDesc;
        desc.MipLevels=1; desc.ArraySize=1; desc.Usage=D3D11_USAGE_DEFAULT; desc.BindFlags=D3D11_BIND_SHADER_RESOURCE; desc.CPUAccessFlags=0; desc.MiscFlags=0;
        winrt::check_hresult(device_->CreateTexture2D(&desc, nullptr, scratchTexture_.put()));
    }

    HWND hwnd_{}; UINT width_{}; UINT height_{}; std::wstring adapterDescription_;
    winrt::com_ptr<ID3D11Device> device_; winrt::com_ptr<ID3D11DeviceContext> context_; winrt::com_ptr<IDXGISwapChain1> swapChain_;
    winrt::com_ptr<ID3D11RenderTargetView> renderTarget_; winrt::com_ptr<ID3D11VertexShader> vertexShader_; winrt::com_ptr<ID3D11PixelShader> pixelShader_;
    winrt::com_ptr<ID3D11InputLayout> inputLayout_; winrt::com_ptr<ID3D11Buffer> vertexBuffer_; winrt::com_ptr<ID3D11Buffer> cropBuffer_;
    winrt::com_ptr<ID3D11SamplerState> sampler_; winrt::com_ptr<ID3D11Texture2D> scratchTexture_; IDirect3DDevice winrtDevice_{nullptr};
};

class CaptureRunner {
public:
    CaptureRunner(Renderer& renderer, Telemetry& telemetry, MonitorRecord const& sourceMonitor, HWND notifyWindow)
        : renderer_(renderer), telemetry_(telemetry), sourceMonitor_(sourceMonitor), notifyWindow_(notifyWindow) {}

    void start() {
        if (!GraphicsCaptureSession::IsSupported()) throw winrt::hresult_error(E_NOTIMPL, L"Windows Graphics Capture is not supported on this system.");
        auto factory = winrt::get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
        winrt::check_hresult(factory->CreateForMonitor(sourceMonitor_.handle, winrt::guid_of<GraphicsCaptureItem>(), winrt::put_abi(item_)));
        captureSize_ = item_.Size();
        framePool_ = Direct3D11CaptureFramePool::CreateFreeThreaded(renderer_.winrt_device(), DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, captureSize_);
        session_ = framePool_.CreateCaptureSession(item_);
        session_.IsCursorCaptureEnabled(false);
        token_ = framePool_.FrameArrived([this](Direct3D11CaptureFramePool const& sender, winrt::Windows::Foundation::IInspectable const&) { on_frame(sender); });
        session_.StartCapture();
    }

    void stop() noexcept {
        try { if (framePool_) framePool_.FrameArrived(token_); } catch (...) {}
        try { if (session_) session_.Close(); } catch (...) {}
        try { if (framePool_) framePool_.Close(); } catch (...) {}
        session_=nullptr; framePool_=nullptr; item_=nullptr;
    }
    ~CaptureRunner() { stop(); }

private:
    void on_frame(Direct3D11CaptureFramePool const& sender) noexcept {
        try {
            auto frame = sender.TryGetNextFrame();
            if (!frame) return;
            auto arrival = qpc_now();
            auto size = frame.ContentSize();
            if (size.Width <= 0 || size.Height <= 0) return;
            if (size.Width != captureSize_.Width || size.Height != captureSize_.Height) {
                telemetry_.event("content_size_changed", std::to_string(size.Width) + "x" + std::to_string(size.Height));
                frame.Close();
                captureSize_=size;
                framePool_.Recreate(renderer_.winrt_device(), DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, captureSize_);
                return;
            }
            auto access = frame.Surface().as<AbiDxgiInterfaceAccess>();
            winrt::com_ptr<ID3D11Texture2D> texture;
            winrt::check_hresult(access->GetInterface(__uuidof(ID3D11Texture2D), texture.put_void()));
            auto renderStart = qpc_now();
            LARGE_INTEGER presentCall{};
            LARGE_INTEGER presentReturn{};
            bool gpuCopy=false;
            HRESULT presentHr = renderer_.render(texture.get(), sourceMonitor_.rect, g_zoom.load(std::memory_order_relaxed), gpuCopy, presentCall, presentReturn);
            telemetry_.frame(++sequence_, frame.SystemRelativeTime().count(), arrival, renderStart, presentCall, presentReturn, presentHr, size.Width, size.Height, g_zoom.load(std::memory_order_relaxed), gpuCopy);
            if (FAILED(presentHr)) {
                telemetry_.event("present_failed", narrow(format_hr(presentHr)));
                throw winrt::hresult_error(presentHr);
            }
        } catch (winrt::hresult_error const& e) {
            telemetry_.event("capture_error", narrow(e.message().c_str()));
            g_captureFailed.store(true, std::memory_order_relaxed);
            PostMessageW(notifyWindow_, kCaptureErrorMessage, static_cast<WPARAM>(e.code()), 0);
        } catch (...) {
            telemetry_.event("capture_error", "unknown_exception");
            g_captureFailed.store(true, std::memory_order_relaxed);
            PostMessageW(notifyWindow_, kCaptureErrorMessage, static_cast<WPARAM>(E_FAIL), 0);
        }
    }

    Renderer& renderer_; Telemetry& telemetry_; MonitorRecord sourceMonitor_; HWND notifyWindow_{};
    GraphicsCaptureItem item_{nullptr}; Direct3D11CaptureFramePool framePool_{nullptr}; GraphicsCaptureSession session_{nullptr};
    winrt::event_token token_{}; winrt::Windows::Graphics::SizeInt32 captureSize_{}; uint64_t sequence_{};
};

LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) { DestroyWindow(hwnd); return 0; }
        if (wParam == '2') { g_zoom.store(2, std::memory_order_relaxed); return 0; }
        if (wParam == '4') { g_zoom.store(4, std::memory_order_relaxed); return 0; }
        break;
    case kCaptureErrorMessage: {
        auto hr=static_cast<HRESULT>(wParam);
        std::wstring text=L"Capture/render loop failed: "+format_hr(hr)+L"\nSee telemetry for details.";
        MessageBoxW(hwnd,text.c_str(),L"Visual Spike 1",MB_OK|MB_ICONERROR);
        DestroyWindow(hwnd); return 0;
    }
    case WM_DESTROY: PostQuitMessage(0); return 0;
    default: break;
    }
    return DefWindowProcW(hwnd,message,wParam,lParam);
}

WindowPlacement create_detail_window(HINSTANCE instance, MonitorRecord const& destination, bool singleMonitor) {
    WNDCLASSEXW wc{}; wc.cbSize=sizeof(wc); wc.style=CS_HREDRAW|CS_VREDRAW; wc.lpfnWndProc=window_proc; wc.hInstance=instance;
    wc.hCursor=LoadCursorW(nullptr,IDC_ARROW); wc.lpszClassName=kWindowClass; wc.hbrBackground=static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    if (!RegisterClassExW(&wc) && GetLastError()!=ERROR_CLASS_ALREADY_EXISTS) winrt::throw_last_error();

    int monitorWidth=destination.rect.right-destination.rect.left;
    int monitorHeight=destination.rect.bottom-destination.rect.top;
    int x=destination.rect.left, y=destination.rect.top, width=monitorWidth, height=monitorHeight;
    DWORD style=WS_POPUP;
    DWORD exStyle=WS_EX_APPWINDOW;

    if (singleMonitor) {
        width=std::max(640, monitorWidth*45/100);
        height=std::max(360, monitorHeight*45/100);
        width=std::min(width, monitorWidth-40);
        height=std::min(height, monitorHeight-80);
        x=destination.rect.right-width-20;
        y=destination.rect.top+40;
        style=WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_MINIMIZEBOX;
        exStyle|=WS_EX_TOPMOST;
    }

    HWND hwnd=CreateWindowExW(exStyle,kWindowClass,L"Visual Spike 1 — Detail",style,x,y,width,height,nullptr,nullptr,instance,nullptr);
    if (!hwnd) winrt::throw_last_error();
    SetWindowPos(hwnd,singleMonitor?HWND_TOPMOST:HWND_TOP,x,y,width,height,SWP_SHOWWINDOW);
    ShowWindow(hwnd,SW_SHOW); UpdateWindow(hwnd); SetFocus(hwnd);

    WindowPlacement result{};
    result.hwnd=hwnd; result.width=static_cast<UINT>(width); result.height=static_cast<UINT>(height); result.singleMonitor=singleMonitor;
    if (singleMonitor) {
        SetLastError(ERROR_SUCCESS);
        result.excludedFromCapture=SetWindowDisplayAffinity(hwnd,kExcludeFromCapture)!=FALSE;
        result.exclusionError=result.excludedFromCapture?ERROR_SUCCESS:GetLastError();
    }
    return result;
}

void log_environment(Telemetry& telemetry, std::vector<MonitorRecord> const& monitors, int sourceIndex, int destIndex,
                     Renderer const& renderer, WindowPlacement const& window) {
    telemetry.comment("qpc_frequency",std::to_string(telemetry.qpc_frequency_value().QuadPart));
    telemetry.comment("monitor_count",std::to_string(monitors.size()));
    telemetry.comment("source_index",std::to_string(sourceIndex));
    telemetry.comment("dest_index",std::to_string(destIndex));
    telemetry.comment("mode",window.singleMonitor?"single_monitor_development":"cross_monitor_validation");
    telemetry.comment("detail_excluded_from_capture",window.excludedFromCapture?"1":"0");
    telemetry.comment("detail_exclusion_error",std::to_string(window.exclusionError));
    telemetry.comment("renderer_adapter",narrow(renderer.adapter_description()));
    telemetry.comment("wgc_pixel_format","B8G8R8A8UIntNormalized");
    telemetry.comment("wgc_frame_pool_buffers","2");
    telemetry.comment("wgc_cursor_capture","0");
    telemetry.comment("present_sync_interval","1");
    for (size_t i=0;i<monitors.size();++i) {
        auto const& m=monitors[i];
        std::ostringstream s;
        s<<"device="<<narrow(m.deviceName)<<";adapter="<<narrow(m.adapterName)<<";primary="<<(m.primary?1:0)
         <<";rect="<<m.rect.left<<':'<<m.rect.top<<':'<<m.rect.right<<':'<<m.rect.bottom
         <<";mode="<<m.mode.dmPelsWidth<<'x'<<m.mode.dmPelsHeight<<'@'<<m.mode.dmDisplayFrequency
         <<";orientation="<<m.mode.dmDisplayOrientation<<";dpi="<<m.dpiX<<'x'<<m.dpiY;
        telemetry.comment("monitor_"+std::to_string(i),s.str());
    }
}

int choose_source(std::vector<MonitorRecord> const& monitors,int requested) {
    if (requested>=0) return requested;
    for (size_t i=0;i<monitors.size();++i) if (monitors[i].primary) return static_cast<int>(i);
    return 0;
}
int choose_destination(std::vector<MonitorRecord> const& monitors,int source,int requested,bool singleMonitor) {
    if (singleMonitor) return source;
    if (requested>=0) return requested;
    for (size_t i=0;i<monitors.size();++i) if (static_cast<int>(i)!=source) return static_cast<int>(i);
    return -1;
}

} // namespace

int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int) {
    try {
        SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        auto options=parse_options();
        g_zoom.store(options.zoom,std::memory_order_relaxed);
        auto monitors=enumerate_monitors();
        if (monitors.empty()) {
            MessageBoxW(nullptr,L"No active display was detected.",L"Visual Spike 1",MB_OK|MB_ICONERROR);
            return 2;
        }

        bool singleMonitor=options.forceSingleMonitor || monitors.size()==1;
        int sourceIndex=choose_source(monitors,options.sourceIndex);
        int destIndex=choose_destination(monitors,sourceIndex,options.destIndex,singleMonitor);
        if (sourceIndex<0 || sourceIndex>=static_cast<int>(monitors.size()) || destIndex<0 || destIndex>=static_cast<int>(monitors.size()) || (!singleMonitor && sourceIndex==destIndex)) {
            MessageBoxW(nullptr,L"Invalid source/destination monitor selection.",L"Visual Spike 1",MB_OK|MB_ICONERROR);
            return 3;
        }

        Telemetry telemetry(options.logPath);
        auto window=create_detail_window(instance,monitors[destIndex],singleMonitor);
        if (singleMonitor && !window.excludedFromCapture) {
            telemetry.comment("warning","SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE) failed; recursive capture may occur");
        }

        Renderer renderer;
        renderer.initialize(window.hwnd,window.width,window.height);
        log_environment(telemetry,monitors,sourceIndex,destIndex,renderer,window);
        telemetry.begin_frames();

        CaptureRunner capture(renderer,telemetry,monitors[sourceIndex],window.hwnd);
        capture.start();
        MSG msg{};
        while (GetMessageW(&msg,nullptr,0,0)>0) { TranslateMessage(&msg); DispatchMessageW(&msg); }
        capture.stop();
        return g_captureFailed.load(std::memory_order_relaxed)?10:0;
    } catch (winrt::hresult_error const& e) {
        std::wstring text=L"HRESULT failure: "+format_hr(e.code())+L"\n"+std::wstring(e.message().c_str());
        MessageBoxW(nullptr,text.c_str(),L"Visual Spike 1",MB_OK|MB_ICONERROR); return 20;
    } catch (std::exception const& e) {
        std::wstring message(e.what(),e.what()+strlen(e.what()));
        MessageBoxW(nullptr,message.c_str(),L"Visual Spike 1",MB_OK|MB_ICONERROR); return 21;
    } catch (...) {
        MessageBoxW(nullptr,L"Unknown fatal error.",L"Visual Spike 1",MB_OK|MB_ICONERROR); return 22;
    }
}
