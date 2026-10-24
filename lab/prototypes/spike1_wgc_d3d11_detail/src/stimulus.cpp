#include <windows.h>
#include <shellapi.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>

namespace {

constexpr wchar_t kClassName[] = L"VisualSpike1StimulusWindow";
constexpr UINT_PTR kTimerId = 1;
constexpr UINT kTimerMs = 16;

struct Options {
    int durationSeconds{60};
    bool movePointer{true};
    std::filesystem::path logPath{L"scenario_events.jsonl"};
};

struct State {
    Options options;
    std::ofstream log;
    LARGE_INTEGER qpcFreq{};
    LARGE_INTEGER startQpc{};
    RECT monitor{};
    int lastPhase{-1};
    int syncId{0};
    bool finished{false};
};

State g;

LARGE_INTEGER qpc_now() { LARGE_INTEGER v{}; QueryPerformanceCounter(&v); return v; }

double elapsed_seconds() {
    auto now=qpc_now();
    return static_cast<double>(now.QuadPart-g.startQpc.QuadPart)/static_cast<double>(g.qpcFreq.QuadPart);
}

Options parse_options() {
    Options o{};
    int argc=0;
    LPWSTR* argv=CommandLineToArgvW(GetCommandLineW(),&argc);
    if (!argv) return o;
    for(int i=1;i<argc;++i) {
        std::wstring a=argv[i];
        auto next=[&]() -> std::wstring { if(i+1>=argc) throw std::runtime_error("missing argument value"); return argv[++i]; };
        if(a==L"--duration") o.durationSeconds=std::max(10,std::stoi(next()));
        else if(a==L"--log") o.logPath=next();
        else if(a==L"--no-pointer") o.movePointer=false;
    }
    LocalFree(argv);
    return o;
}

std::string json_escape(std::string const& s) {
    std::string r;
    for(char c:s) {
        switch(c) {
        case '"': r+="\\\""; break;
        case '\\': r+="\\\\"; break;
        case '\n': r+="\\n"; break;
        case '\r': r+="\\r"; break;
        case '\t': r+="\\t"; break;
        default: r+=c; break;
        }
    }
    return r;
}

void log_event(std::string const& type,std::string const& detail) {
    auto now=qpc_now();
    g.log << "{\"qpc\":" << now.QuadPart
          << ",\"elapsed_ms\":" << std::fixed << std::setprecision(3)
          << (1000.0*static_cast<double>(now.QuadPart-g.startQpc.QuadPart)/static_cast<double>(g.qpcFreq.QuadPart))
          << ",\"type\":\"" << json_escape(type) << "\",\"detail\":\"" << json_escape(detail) << "\"}\n";
    g.log.flush();
}

int phase_for(double t) {
    int slice=static_cast<int>(t)/10;
    return slice%6;
}

char const* phase_name(int p) {
    switch(p) {
    case 0: return "sync_flash";
    case 1: return "slow_motion";
    case 2: return "fast_motion";
    case 3: return "smooth_scroll";
    case 4: return "rapid_scroll";
    default: return "edge_pointer_sweep";
    }
}

void update_pointer(double t,int phase) {
    if(!g.options.movePointer) return;
    int w=g.monitor.right-g.monitor.left;
    int h=g.monitor.bottom-g.monitor.top;
    double local=std::fmod(t,10.0)/10.0;
    int x=g.monitor.left+w/2;
    int y=g.monitor.top+h/2;
    if(phase==1) {
        x=g.monitor.left+static_cast<int>((0.10+0.80*local)*w);
        y=g.monitor.top+static_cast<int>((0.30+0.20*std::sin(local*6.2831853))*h);
    } else if(phase==2) {
        x=g.monitor.left+static_cast<int>((0.1+0.8*std::fmod(local*4.0,1.0))*w);
        y=g.monitor.top+static_cast<int>((0.2+0.6*std::fmod(local*7.0,1.0))*h);
    } else if(phase==5) {
        int leg=static_cast<int>(local*4.0)%4;
        double q=std::fmod(local*4.0,1.0);
        if(leg==0){x=g.monitor.left+static_cast<int>((0.05+0.90*q)*w);y=g.monitor.top+static_cast<int>(0.05*h);}
        else if(leg==1){x=g.monitor.left+static_cast<int>(0.95*w);y=g.monitor.top+static_cast<int>((0.05+0.90*q)*h);}
        else if(leg==2){x=g.monitor.left+static_cast<int>((0.95-0.90*q)*w);y=g.monitor.top+static_cast<int>(0.95*h);}
        else {x=g.monitor.left+static_cast<int>(0.05*w);y=g.monitor.top+static_cast<int>((0.95-0.90*q)*h);}
    }
    SetCursorPos(x,y);
}

void paint(HWND hwnd,HDC dc) {
    RECT client{}; GetClientRect(hwnd,&client);
    int w=client.right-client.left, h=client.bottom-client.top;
    double t=elapsed_seconds();
    int phase=phase_for(t);
    double local=std::fmod(t,10.0);

    HBRUSH bg=CreateSolidBrush(RGB(18,18,22));
    FillRect(dc,&client,bg); DeleteObject(bg);

    SetBkMode(dc,TRANSPARENT);
    SetTextColor(dc,RGB(245,245,245));
    HFONT title=CreateFontW(44,0,0,0,FW_BOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
    HFONT body=CreateFontW(24,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Consolas");
    auto old=SelectObject(dc,title);
    std::wstring heading=L"Visual Spike 1 Stimulus";
    TextOutW(dc,40,30,heading.c_str(),static_cast<int>(heading.size()));
    SelectObject(dc,body);
    std::wstringstream info;
    info << L"phase=" << phase_name(phase) << L"   elapsed=" << std::fixed << std::setprecision(2) << t << L"s";
    auto text=info.str(); TextOutW(dc,42,92,text.c_str(),static_cast<int>(text.size()));

    if(phase==0) {
        bool white=static_cast<int>(local*4.0)%2==0;
        HBRUSH b=CreateSolidBrush(white?RGB(255,255,255):RGB(0,0,0));
        RECT r{w/8,h/4,7*w/8,3*h/4}; FillRect(dc,&r,b); DeleteObject(b);
        SetTextColor(dc,white?RGB(0,0,0):RGB(255,255,255));
        std::wstring label=L"SYNC " + std::to_wstring(g.syncId);
        TextOutW(dc,w/2-90,h/2-15,label.c_str(),static_cast<int>(label.size()));
    } else if(phase==1 || phase==2) {
        double speed=phase==1?0.35:1.8;
        double pos=(std::sin(t*speed*6.2831853)+1.0)*0.5;
        int cx=static_cast<int>(80+pos*(w-160));
        HBRUSH b=CreateSolidBrush(RGB(255,235,0));
        RECT r{cx-55,h/2-55,cx+55,h/2+55}; FillRect(dc,&r,b); DeleteObject(b);
        HPEN pen=CreatePen(PS_SOLID,4,RGB(0,180,255)); auto oldPen=SelectObject(dc,pen);
        MoveToEx(dc,60,h/2,nullptr); LineTo(dc,w-60,h/2); SelectObject(dc,oldPen); DeleteObject(pen);
    } else {
        int band=44;
        int offset=phase==3?static_cast<int>(t*80.0)%band:static_cast<int>(t*420.0)%band;
        for(int y=-band+offset;y<h;y+=band) {
            HBRUSH b=CreateSolidBrush(((y/band)&1)?RGB(240,240,240):RGB(40,100,220));
            RECT r{70,y,w-70,y+band/2}; FillRect(dc,&r,b); DeleteObject(b);
        }
        if(phase==5) {
            SetTextColor(dc,RGB(255,120,70));
            std::wstring label=L"POINTER EDGE SWEEP";
            TextOutW(dc,42,h-70,label.c_str(),static_cast<int>(label.size()));
        }
    }

    SelectObject(dc,old); DeleteObject(title); DeleteObject(body);
}

LRESULT CALLBACK wnd_proc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    switch(msg) {
    case WM_TIMER: {
        double t=elapsed_seconds();
        int phase=phase_for(t);
        if(phase!=g.lastPhase) {
            g.lastPhase=phase;
            if(phase==0) ++g.syncId;
            log_event("phase_start",phase_name(phase));
        }
        update_pointer(t,phase);
        InvalidateRect(hwnd,nullptr,FALSE);
        if(t>=g.options.durationSeconds && !g.finished) {
            g.finished=true; log_event("scenario_complete","duration_reached");
            DestroyWindow(hwnd);
        }
        return 0;
    }
    case WM_PAINT: {
        PAINTSTRUCT ps{}; HDC dc=BeginPaint(hwnd,&ps); paint(hwnd,dc); EndPaint(hwnd,&ps); return 0;
    }
    case WM_KEYDOWN:
        if(wp==VK_ESCAPE){log_event("scenario_aborted","escape");DestroyWindow(hwnd);return 0;}
        break;
    case WM_DESTROY: KillTimer(hwnd,kTimerId); PostQuitMessage(0); return 0;
    default: break;
    }
    return DefWindowProcW(hwnd,msg,wp,lp);
}

} // namespace

int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int) {
    try {
        SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        g.options=parse_options();
        g.log.open(g.options.logPath,std::ios::out|std::ios::trunc);
        if(!g.log) throw std::runtime_error("cannot open scenario event log");
        QueryPerformanceFrequency(&g.qpcFreq); g.startQpc=qpc_now();

        POINT cursor{}; GetCursorPos(&cursor);
        HMONITOR monitor=MonitorFromPoint(cursor,MONITOR_DEFAULTTOPRIMARY);
        MONITORINFO mi{}; mi.cbSize=sizeof(mi); if(!GetMonitorInfoW(monitor,&mi)) throw std::runtime_error("GetMonitorInfo failed");
        g.monitor=mi.rcMonitor;

        g.log << "{\"type\":\"scenario_start\",\"qpc\":" << g.startQpc.QuadPart
              << ",\"qpc_frequency\":" << g.qpcFreq.QuadPart
              << ",\"duration_s\":" << g.options.durationSeconds
              << ",\"move_pointer\":" << (g.options.movePointer?"true":"false") << "}\n";
        g.log.flush();

        WNDCLASSEXW wc{}; wc.cbSize=sizeof(wc); wc.lpfnWndProc=wnd_proc; wc.hInstance=instance; wc.hCursor=LoadCursorW(nullptr,IDC_ARROW);
        wc.hbrBackground=static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)); wc.lpszClassName=kClassName;
        if(!RegisterClassExW(&wc)) throw std::runtime_error("RegisterClassEx failed");

        int w=g.monitor.right-g.monitor.left, h=g.monitor.bottom-g.monitor.top;
        HWND hwnd=CreateWindowExW(0,kClassName,L"Visual Spike 1 Stimulus",WS_POPUP,g.monitor.left,g.monitor.top,w,h,nullptr,nullptr,instance,nullptr);
        if(!hwnd) throw std::runtime_error("CreateWindowEx failed");
        ShowWindow(hwnd,SW_SHOW); UpdateWindow(hwnd); SetForegroundWindow(hwnd);
        SetTimer(hwnd,kTimerId,kTimerMs,nullptr);
        log_event("window_ready","stimulus_visible");

        MSG msg{}; while(GetMessageW(&msg,nullptr,0,0)>0){TranslateMessage(&msg);DispatchMessageW(&msg);}
        return 0;
    } catch(std::exception const& e) {
        std::wstring message(e.what(),e.what()+strlen(e.what()));
        MessageBoxW(nullptr,message.c_str(),L"Visual Spike 1 Stimulus",MB_OK|MB_ICONERROR); return 1;
    }
}
