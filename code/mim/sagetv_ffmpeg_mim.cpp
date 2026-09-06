#include <algorithm>
#include <atomic>
#include <chrono>
#include <cctype>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <mutex>
#include <optional>
#include <set>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <io.h>
static_assert(sizeof(void*) == 8, "SageTV FFmpeg MIM supports Windows x64 only.");
#else
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/stat.h>
#ifdef __linux__
#include <sys/prctl.h>
#endif
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

namespace fs = std::filesystem;

static constexpr const char* MIM_VERSION = "0.4.8";

static std::string trim(std::string s) {
    auto is_ws = [](unsigned char c){ return std::isspace(c) != 0; };
    while (!s.empty() && is_ws((unsigned char)s.front())) s.erase(s.begin());
    while (!s.empty() && is_ws((unsigned char)s.back())) s.pop_back();
    return s;
}

static std::string lower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return (char)std::tolower(c); });
    return s;
}

static bool ieq(const std::string& a, const std::string& b) { return lower(a) == lower(b); }

static bool parse_bool(const std::string& v, bool def=false) {
    const auto x = lower(trim(v));
    if (x == "1" || x == "true" || x == "yes" || x == "on") return true;
    if (x == "0" || x == "false" || x == "no" || x == "off") return false;
    return def;
}

static long long parse_ll(const std::string& v, long long def=0) {
    try { size_t n=0; long long r=std::stoll(trim(v), &n, 10); return n ? r : def; }
    catch (...) { return def; }
}

static std::vector<std::string> split_csv(const std::string& s) {
    std::vector<std::string> out; std::string cur;
    std::stringstream ss(s);
    while (std::getline(ss, cur, ',')) { cur = trim(cur); if (!cur.empty()) out.push_back(cur); }
    return out;
}

class Ini {
public:
    bool load(const fs::path& p) {
        std::ifstream f(p);
        if (!f) return false;
        std::string line, section;
        while (std::getline(f, line)) {
            if (!line.empty() && line.back() == '\r') line.pop_back();
            auto t = trim(line);
            if (t.empty() || t[0] == ';' || t[0] == '#') continue;
            if (t.front() == '[' && t.back() == ']') { section = lower(trim(t.substr(1, t.size()-2))); continue; }
            auto eq = t.find('=');
            if (eq == std::string::npos) continue;
            auto k = lower(trim(t.substr(0, eq)));
            auto v = trim(t.substr(eq+1));
            data_[section][k] = v;
        }
        return true;
    }
    std::string get(const std::string& sec, const std::string& key, const std::string& def="") const {
        auto si=data_.find(lower(sec)); if (si==data_.end()) return def;
        auto ki=si->second.find(lower(key)); return ki==si->second.end()?def:ki->second;
    }
    bool has(const std::string& sec, const std::string& key) const {
        auto si=data_.find(lower(sec));
        return si!=data_.end() && si->second.find(lower(key))!=si->second.end();
    }
    bool get_bool(const std::string& s, const std::string& k, bool d=false) const { return parse_bool(get(s,k,d?"true":"false"), d); }
    long long get_ll(const std::string& s, const std::string& k, long long d=0) const { return parse_ll(get(s,k,std::to_string(d)), d); }
private:
    std::map<std::string,std::map<std::string,std::string>> data_;
};

class Logger {
public:
    void init(const fs::path& path, bool enabled) {
        enabled_=enabled;
        if (enabled_) { fs::create_directories(path.parent_path().empty()?fs::path("."):path.parent_path()); out_.open(path, std::ios::app); }
    }
    template<typename... T> void log(T&&... xs) {
        if (!enabled_) return;
        std::lock_guard<std::mutex> lk(mu_);
        auto now=std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::tm tm{};
#ifdef _WIN32
        localtime_s(&tm,&now);
#else
        localtime_r(&now,&tm);
#endif
        out_ << std::put_time(&tm,"%Y-%m-%d %H:%M:%S") << " ";
        (out_ << ... << xs) << '\n'; out_.flush();
    }
private:
    bool enabled_=false; std::ofstream out_; std::mutex mu_;
};

static fs::path executable_path() {
#ifdef _WIN32
    std::vector<wchar_t> buf(32768); DWORD n=GetModuleFileNameW(nullptr,buf.data(),(DWORD)buf.size());
    return n?fs::path(std::wstring(buf.data(),n)):fs::current_path()/"ffmpeg.exe";
#else
    std::vector<char> buf(4096); ssize_t n=readlink("/proc/self/exe",buf.data(),buf.size()-1);
    if (n>0) { buf[(size_t)n]=0; return fs::path(buf.data()); }
    return fs::current_path()/"ffmpeg";
#endif
}

static bool native_file_exists(const fs::path& p) {
#ifdef _WIN32
    // MinGW std::filesystem can report false for an otherwise valid companion
    // executable when SageTV is launched from a WSL UNC path. Ask Win32
    // directly so \\wsl.localhost\... paths work as well as local drive paths.
    const DWORD a = GetFileAttributesW(p.wstring().c_str());
    return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY) == 0;
#else
    std::error_code ec;
    return fs::is_regular_file(p, ec);
#endif
}

static std::string shell_quote(const std::string& s) {
#ifdef _WIN32
    std::string r="\""; for(char c:s){ if(c=='\"') r+="\\\""; else r+=c; } return r+="\"";
#else
    std::string r="'"; for(char c:s){ if(c=='\'') r+="'\\''"; else r+=c; } return r+="'";
#endif
}

static std::string display_quote(const std::string& s) {
    if (s.find_first_of(" \t\"'") == std::string::npos) return s;
    std::string r="\""; for(char c:s){ if(c=='\"') r+="\\\""; else r+=c; } return r+="\"";
}

static std::string join_display(const fs::path& exe, const std::vector<std::string>& args) {
    std::ostringstream o; o << display_quote(exe.string()); for (const auto& a:args) o << ' ' << display_quote(a); return o.str();
}

static std::string json_escape(const std::string& value) {
    std::ostringstream out;
    for (unsigned char c : value) {
        switch (c) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\b': out << "\\b"; break;
            case '\f': out << "\\f"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default:
                if (c < 0x20) out << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(c) << std::dec;
                else out << static_cast<char>(c);
        }
    }
    return out.str();
}

static long long current_process_id() {
#ifdef _WIN32
    return static_cast<long long>(GetCurrentProcessId());
#else
    return static_cast<long long>(getpid());
#endif
}

static bool process_is_alive(long long pid) {
    if (pid <= 0) return false;
#ifdef _WIN32
    HANDLE process=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,static_cast<DWORD>(pid));
    if (!process) return false;
    DWORD code=0; const bool alive=GetExitCodeProcess(process,&code) && code==STILL_ACTIVE;
    CloseHandle(process); return alive;
#else
    return kill(static_cast<pid_t>(pid),0)==0 || errno==EPERM;
#endif
}

static fs::path mim_status_directory(const fs::path& executable_dir, const Ini& ini) {
    fs::path status=trim(ini.get("status","directory","cache/status"));
    if (status.is_relative()) status=executable_dir/status;
    return status;
}

static bool atomic_write_text(const fs::path& destination, const std::string& text) {
    std::error_code ec;
    fs::create_directories(destination.parent_path(),ec);
    const fs::path temporary=destination.string()+".tmp-"+std::to_string(current_process_id());
    {
        std::ofstream out(temporary,std::ios::binary|std::ios::trunc);
        if (!out) return false;
        out << text << '\n';
        if (!out) return false;
    }
#ifdef _WIN32
    fs::remove(destination,ec); ec.clear();
#endif
    fs::rename(temporary,destination,ec);
    if (ec) { fs::remove(temporary,ec); return false; }
    return true;
}

static std::string read_text_file(const fs::path& path) {
    std::ifstream in(path,std::ios::binary);
    if (!in) return {};
    return std::string(std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>());
}

static void print_mim_status(const fs::path& executable_dir, const Ini& ini,
                             const std::string& platform_name) {
    const fs::path directory=mim_status_directory(executable_dir,ini);
    std::vector<std::string> active;
    std::error_code ec;
    if (fs::is_directory(directory,ec)) {
        for (const auto& entry : fs::directory_iterator(directory,ec)) {
            if (ec || !entry.is_regular_file()) continue;
            const std::string name=entry.path().filename().string();
            if (name.rfind("job-",0)!=0 || name.size()<10 || name.substr(name.size()-5)!=".json") continue;
            long long pid=0;
            try { pid=std::stoll(name.substr(4,name.size()-9)); } catch (...) { pid=0; }
            if (!process_is_alive(pid)) { fs::remove(entry.path(),ec); ec.clear(); continue; }
            auto record=trim(read_text_file(entry.path()));
            if (!record.empty()) active.push_back(record);
        }
    }
    auto last=trim(read_text_file(directory/"last.json"));
    auto last_transcode=trim(read_text_file(directory/"last-transcode.json"));
    std::cout << "{\"mimVersion\":\"" << MIM_VERSION << "\",\"platform\":\""
              << json_escape(platform_name) << "\",\"activeJobs\":[";
    for (size_t i=0;i<active.size();++i) { if (i) std::cout << ','; std::cout << active[i]; }
    std::cout << "],\"lastJob\":" << (last.empty()?"null":last)
              << ",\"lastTranscodeJob\":" << (last_transcode.empty()?"null":last_transcode)
              << "}\n";
}

static bool is_encode_backend(const std::string& backend) {
    return backend=="qsv" || backend=="nvenc" || backend=="vaapi" || backend=="amf" ||
        backend=="d3d12va" || backend=="software";
}

static std::string mim_status_record(const std::string& platform_name, long long pid,
                                     const std::string& state, const std::string& backend,
                                     const std::string& encoder, bool hardware_decode,
                                     bool active_file, const std::optional<fs::path>& input,
                                     const std::string& output_format, long long started_ms,
                                     std::optional<int> exit_code=std::nullopt) {
    const bool hardware_encode=is_encode_backend(backend) && backend!="software";
    std::ostringstream out;
    out << "{\"mimVersion\":\"" << MIM_VERSION << "\",\"platform\":\""
        << json_escape(platform_name) << "\",\"mimPid\":" << pid
        << ",\"state\":\"" << json_escape(state) << "\",\"backend\":\""
        << json_escape(backend) << "\",\"encoder\":\"" << json_escape(encoder)
        << "\",\"hardwareEncode\":" << (hardware_encode?"true":"false")
        << ",\"hardwareDecode\":" << (hardware_decode?"true":"false")
        << ",\"activeFile\":" << (active_file?"true":"false")
        << ",\"input\":\"" << json_escape(input?input->string():"")
        << "\",\"outputFormat\":\"" << json_escape(output_format)
        << "\",\"startedEpochMs\":" << started_ms;
    if (exit_code) out << ",\"exitCode\":" << *exit_code;
    out << '}';
    return out.str();
}

static uint64_t fnv1a64(const std::string& s) {
    uint64_t h=1469598103934665603ULL; for(unsigned char c:s){ h^=c; h*=1099511628211ULL; } return h;
}
static std::string hex64(uint64_t v) { std::ostringstream o; o<<std::hex<<std::setw(16)<<std::setfill('0')<<v; return o.str(); }

static std::string file_stamp(const fs::path& p) {
    std::error_code ec; auto size=fs::file_size(p,ec); if(ec) size=0;
    auto t=fs::last_write_time(p,ec); long long tv=0; if(!ec) tv=(long long)t.time_since_epoch().count();
    return std::to_string(size)+":"+std::to_string(tv);
}

static std::string file_identity(const fs::path& p) {
#ifdef _WIN32
    HANDLE h = CreateFileW(p.wstring().c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
                           nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return {};
    BY_HANDLE_FILE_INFORMATION info{};
    std::string out;
    if (GetFileInformationByHandle(h, &info)) {
        std::ostringstream o;
        o << std::hex << info.dwVolumeSerialNumber << ":" << info.nFileIndexHigh << ":" << info.nFileIndexLow;
        out = o.str();
    }
    CloseHandle(h);
    return out;
#else
    struct stat st{};
    if (::stat(p.c_str(), &st) != 0) return {};
    return std::to_string((unsigned long long)st.st_dev) + ":" + std::to_string((unsigned long long)st.st_ino);
#endif
}

static bool likely_mpegts(const fs::path& p) {
    auto e = lower(p.extension().string());
    return e == ".ts" || e == ".mts" || e == ".m2ts" || e == ".m2t";
}

static std::pair<int,std::string> run_capture(const fs::path& exe, const std::vector<std::string>& args) {
    std::string cmd=shell_quote(exe.string()); for(auto& a:args) cmd += " " + shell_quote(a);
    cmd += " 2>&1";
#ifdef _WIN32
    FILE* fp=_popen(cmd.c_str(),"r");
#else
    FILE* fp=popen(cmd.c_str(),"r");
#endif
    if(!fp) return {-1,{}};
    std::string out; char b[4096]; while(fgets(b,sizeof(b),fp)) out += b;
#ifdef _WIN32
    int rc=_pclose(fp);
#else
    int st=pclose(fp); int rc=WIFEXITED(st)?WEXITSTATUS(st):-1;
#endif
    return {rc,out};
}

static bool has_flag(const std::vector<std::string>& a, const std::string& opt) {
    return std::any_of(a.begin(),a.end(),[&](const std::string& x){return x==opt;});
}
static std::optional<size_t> find_opt(const std::vector<std::string>& a, const std::vector<std::string>& names, size_t start=0) {
    for(size_t i=start;i<a.size();++i) for(auto& n:names) if(a[i]==n) return i; return std::nullopt;
}
static std::optional<std::string> get_opt_value(const std::vector<std::string>& a, const std::vector<std::string>& names) {
    auto i=find_opt(a,names); if(i && *i+1<a.size()) return a[*i+1]; return std::nullopt;
}
static void remove_flag(std::vector<std::string>& a, const std::string& opt) {
    a.erase(std::remove(a.begin(),a.end(),opt),a.end());
}
static void remove_opt_value(std::vector<std::string>& a, const std::vector<std::string>& names) {
    for(size_t i=0;i<a.size();) {
        bool hit=false; for(auto& n:names) if(a[i]==n){hit=true;break;}
        if(hit){ a.erase(a.begin()+i, a.begin()+std::min(a.size(),i+2)); } else ++i;
    }
}
static void remove_input_opt_value(std::vector<std::string>& a, const std::vector<std::string>& names) {
    auto input=find_opt(a,{"-i"});
    size_t end=input.value_or(a.size());
    for(size_t i=0;i<end;) {
        bool hit=false; for(auto& n:names) if(a[i]==n){hit=true;break;}
        if(hit) {
            const auto erase_end=std::min(a.size(),i+2);
            const auto removed=erase_end-i;
            a.erase(a.begin()+i,a.begin()+erase_end);
            end-=std::min(end-i,removed);
        } else ++i;
    }
}
static void remove_output_opt_value(std::vector<std::string>& a, const std::vector<std::string>& names) {
    auto input=find_opt(a,{"-i"});
    size_t i=input ? std::min(a.size(),*input+2) : 0;
    while(i<a.size()) {
        bool hit=false; for(auto& n:names) if(a[i]==n){hit=true;break;}
        if(hit) a.erase(a.begin()+i,a.begin()+std::min(a.size(),i+2)); else ++i;
    }
}
static size_t input_option_pos(const std::vector<std::string>& a) {
    auto i=find_opt(a,{"-i"}); return i?*i:a.size();
}
static size_t after_input_pos(const std::vector<std::string>& a) {
    auto i=find_opt(a,{"-i"}); if(!i) return 0; return std::min(a.size(),*i+2);
}
static void set_input_opt(std::vector<std::string>& a, const std::vector<std::string>& aliases, const std::string& canon, const std::string& value) {
    remove_input_opt_value(a,aliases); auto p=input_option_pos(a); a.insert(a.begin()+p,{canon,value});
}
static void set_output_opt(std::vector<std::string>& a, const std::vector<std::string>& aliases, const std::string& canon, const std::string& value) {
    remove_output_opt_value(a,aliases); auto p=after_input_pos(a); a.insert(a.begin()+p,{canon,value});
}
static std::optional<std::string> get_output_opt_value(const std::vector<std::string>& a,
                                                       const std::vector<std::string>& names) {
    auto input=find_opt(a,{"-i"});
    size_t start=input ? std::min(a.size(),*input+2) : 0;
    auto option=find_opt(a,names,start);
    if(option && *option+1<a.size()) return a[*option+1];
    return std::nullopt;
}
static void add_output_tokens(std::vector<std::string>& a, const std::vector<std::string>& t) {
    auto p=after_input_pos(a); a.insert(a.begin()+p,t.begin(),t.end());
}

static std::string format_seconds(double value) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(3) << value;
    auto text=out.str();
    while(text.size()>1 && text.back()=='0') text.pop_back();
    if(!text.empty() && text.back()=='.') text.pop_back();
    return text;
}

static void add_completed_mpegts_seek_preroll(std::vector<std::string>& a,
                                               const Ini& ini,
                                               const std::optional<fs::path>& input,
                                               bool active,
                                               Logger& log) {
    if(active || !input || !likely_mpegts(*input) ||
       !ini.get_bool("seek","completed_mpegts_preroll",false)) return;

    auto input_pos=find_opt(a,{"-i"});
    auto seek_pos=find_opt(a,{"-ss"});
    if(!input_pos || !seek_pos || *seek_pos>*input_pos || *seek_pos+1>=a.size()) return;

    const double preroll=static_cast<double>(std::max<long long>(0,
        ini.get_ll("seek","completed_mpegts_preroll_seconds",5)));
    if(preroll<=0) return;

    double requested=0;
    try {
        size_t consumed=0;
        requested=std::stod(a[*seek_pos+1],&consumed);
        if(consumed!=a[*seek_pos+1].size() || requested<=preroll) return;
    } catch(...) {
        // HH:MM:SS and other FFmpeg time syntaxes remain untouched. SageTV's
        // MiniPlayer path currently emits numeric seconds.
        return;
    }

    const auto input_seek=format_seconds(requested-preroll);
    const auto output_seek=format_seconds(preroll);
    a[*seek_pos+1]=input_seek;
    auto after=after_input_pos(a);
    a.insert(a.begin()+after,{"-ss",output_seek});
    log.log("seek: completed MPEG-TS requested=",format_seconds(requested),
            " input_seek=",input_seek," output_preroll=",output_seek);
}

static std::optional<long long> parse_bitrate_bps(const std::string& s) {
    auto t=lower(trim(s)); if(t.empty()) return std::nullopt; double mult=1;
    if(t.back()=='k'){mult=1000;t.pop_back();} else if(t.back()=='m'){mult=1000000;t.pop_back();} else if(t.back()=='g'){mult=1000000000;t.pop_back();}
    try { return (long long)(std::stod(t)*mult); } catch (...) { return std::nullopt; }
}
static std::string format_bitrate(long long bps) {
    if(bps%1000000==0) return std::to_string(bps/1000000)+"M";
    if(bps%1000==0) return std::to_string(bps/1000)+"k";
    return std::to_string(bps);
}

struct ProbeCache {
    fs::path dir; Logger* log=nullptr;
    fs::path entry(const fs::path& input) const { return dir/(hex64(fnv1a64(fs::absolute(input).lexically_normal().string()))+".cache"); }
    bool hit(const fs::path& input) {
        auto p=entry(input); std::ifstream f(p); if(!f) return false;
        std::string line,path,stamp,identity; bool ok=false;
        while(std::getline(f,line)){
            auto e=line.find('='); if(e==std::string::npos)continue;
            auto k=line.substr(0,e),v=line.substr(e+1);
            if(k=="path")path=v; else if(k=="stamp")stamp=v; else if(k=="identity")identity=v; else if(k=="ok")ok=(v=="1");
        }
        auto abs=fs::absolute(input).lexically_normal().string();
        if(!ok || path!=abs) return false;
        const auto current_id=file_identity(input);
        if(!identity.empty() && !current_id.empty() && identity!=current_id) return false;
        return stamp==file_stamp(input);
    }
    void populate_async(fs::path ffprobe, fs::path input, long long probesize, long long analyze) {
        auto outdir=dir; auto outpath=entry(input); auto* lg=log;
        std::thread([ffprobe,input,probesize,analyze,outdir,outpath,lg](){
            std::error_code ec; fs::create_directories(outdir,ec);
            std::vector<std::string> a={"-v","error","-probesize",std::to_string(probesize),"-analyzeduration",std::to_string(analyze),
                "-show_entries","format=format_name:stream=index,codec_type,codec_name,width,height,avg_frame_rate","-of","compact=p=0:nk=0",input.string()};
            auto [rc,text]=run_capture(ffprobe,a);
            if(rc==0 && text.find("video")!=std::string::npos){
                std::ofstream f(outpath);
                f<<"ok=1\npath="<<fs::absolute(input).lexically_normal().string()<<"\nstamp="<<file_stamp(input)<<"\nidentity="<<file_identity(input)<<"\n";
                f<<"probe="; for(char c:text){ if(c=='\n'||c=='\r') f<<';'; else f<<c; } f<<"\n";
                if(lg) lg->log("probe-cache populated input=",input.string());
            } else if(lg) lg->log("probe-cache miss probe failed rc=",rc," input=",input.string());
        }).detach();
    }
};
struct PlatformInfo { std::string name; };
static PlatformInfo platform_info() {
#ifdef _WIN32
    return {"windows-x64"};
#else
    return {"linux-x64"};
#endif
}

static bool is_management_call(const std::vector<std::string>& a) {
    static const std::set<std::string> direct={"-version","-buildconf","-formats","-demuxers","-muxers","-devices","-codecs","-decoders","-encoders","-bsfs","-protocols","-filters","-pix_fmts","-layouts","-sample_fmts","-dispositions","-colors","-hwaccels"};
    if(a.empty()) return true;
    for(const auto& x:a) {
        if(direct.count(x)) return true;
        if(x=="-h" || x=="-help" || x.rfind("-h=",0)==0) return true;
    }
    return !find_opt(a,{"-i"}).has_value();
}

static fs::path resolve_config_path(const fs::path& exe_dir, const Ini& ini, const PlatformInfo& p, bool probe=false) {
    std::string key;
    if(p.name=="linux-x64") key=probe?"linux_x64_ffprobe":"linux_x64_ffmpeg";
    else key=probe?"windows_x64_ffprobe":"windows_x64_ffmpeg";
    auto raw=ini.get("paths",key, probe?"./ffprobe":"./ffmpeg.real");
    fs::path x(raw);
    if (x.is_relative()) x=exe_dir/x;
#ifdef _WIN32
    // Preserve UNC prefixes exactly. lexically_normal() in older MinGW
    // std::filesystem implementations can mishandle \\server\share paths.
    return x;
#else
    return x.lexically_normal();
#endif
}

static std::string load_capabilities(const fs::path& real, const fs::path& cache_dir, Logger& log) {
    std::error_code ec; fs::create_directories(cache_dir,ec);
    auto key=hex64(fnv1a64(real.string()+":"+file_stamp(real)));
    auto cp=cache_dir/("encoders-"+key+".txt");
    std::ifstream in(cp); if(in){ std::ostringstream ss; ss<<in.rdbuf(); return ss.str(); }
    auto [rc,out]=run_capture(real,{"-hide_banner","-encoders"});
    if(rc==0){ std::ofstream f(cp); f<<out; log.log("capability cache populated for ",real.string()); }
    else log.log("WARNING capability probe failed rc=",rc," for ",real.string());
    return out;
}

static bool linux_has_vendor(const std::string& vendor) {
#ifndef _WIN32
    std::error_code ec; fs::path d="/sys/class/drm"; if(!fs::exists(d,ec)) return false;
    for(auto& e:fs::directory_iterator(d,ec)) {
        auto n=e.path().filename().string(); if(n.rfind("renderD",0)!=0) continue;
        std::ifstream f(e.path()/"device/vendor"); std::string v; if(f>>v && lower(v)==lower(vendor)) return true;
    }
#endif
    return false;
}

static bool hardware_encode_preflight(const Ini& ini, const fs::path& real,
                                      const fs::path& cache_dir, Logger& log,
                                      const std::string& backend,
                                      const std::string& encoder) {
#ifdef _WIN32
    // The Linux/Unraid release is the commissioned runtime target. Windows
    // keeps capability-based selection until a bounded native process runner
    // is added; do not invoke the unrelated Windows timeout.exe utility.
    (void)ini; (void)real; (void)cache_dir; (void)log; (void)backend; (void)encoder;
    return true;
#else
    if(!ini.get_bool("hardware","preflight_hardware_encode",true) || backend=="software")
        return true;
    const fs::path timeout_exe="/usr/bin/timeout";
    if(!native_file_exists(timeout_exe)) {
        log.log("WARNING hardware preflight skipped because /usr/bin/timeout is unavailable");
        return true;
    }

    auto dev=trim(ini.get("hardware","linux_render_device","/dev/dri/renderD128"));
    std::error_code ec;
    fs::create_directories(cache_dir,ec);
    const auto cache_key=hex64(fnv1a64(real.string()+":"+file_stamp(real)+":"+
                                           backend+":"+encoder+":"+dev));
    const auto cache_file=cache_dir/("preflight-"+cache_key+".ok");
    if(native_file_exists(cache_file)) {
        log.log("hardware preflight cache HIT backend=",backend," encoder=",encoder);
        return true;
    }

    long long timeout_ms=std::max<long long>(1000,
        ini.get_ll("hardware","preflight_timeout_ms",5000));
    long long timeout_seconds=std::max<long long>(1,(timeout_ms+999)/1000);
    std::vector<std::string> args={"--signal=KILL",std::to_string(timeout_seconds)+"s",
        real.string(),"-hide_banner","-loglevel","error"};
    if(backend=="qsv") {
        args.insert(args.end(),{"-init_hw_device","qsv:hw,child_device="+dev});
    } else if(backend=="vaapi") {
        args.insert(args.end(),{"-vaapi_device",dev});
    }
    args.insert(args.end(),{"-f","lavfi","-i","color=black:size=64x64:rate=1",
                            "-frames:v","1","-an"});
    if(backend=="vaapi")
        args.insert(args.end(),{"-vf","format=nv12,hwupload"});
    args.insert(args.end(),{"-c:v",encoder,"-f","null","-"});

    auto [rc,output]=run_capture(timeout_exe,args);
    if(rc!=0) {
        if(output.size()>1000) output.resize(1000);
        for(char& c:output) if(c=='\r' || c=='\n') c=' ';
        log.log("WARNING hardware preflight failed backend=",backend,
                " encoder=",encoder," rc=",rc," diagnostic=",output);
        return false;
    }

    const auto temporary=cache_file.string()+".tmp."+std::to_string((long long)getpid());
    {
        std::ofstream saved(temporary,std::ios::trunc);
        saved << "backend=" << backend << "\nencoder=" << encoder << "\n";
    }
    fs::rename(temporary,cache_file,ec);
    if(ec) {
        fs::remove(cache_file,ec);
        ec.clear();
        fs::rename(temporary,cache_file,ec);
    }
    if(ec) fs::remove(temporary,ec);
    log.log("hardware preflight PASS backend=",backend," encoder=",encoder);
    return true;
#endif
}

static std::string choose_backend(const Ini& ini, const PlatformInfo& p, const fs::path& real,
                                  const fs::path& cache, Logger& log, const std::string& family,
                                  bool hardware_allowed=true) {
    auto configured=lower(ini.get("hardware","backend","auto"));
    auto caps=load_capabilities(real,cache,log);
    auto has=[&](const std::string& e){return !e.empty() && caps.find(e)!=std::string::npos;};
    auto enc=[&](const std::string& b){
        if(family=="hevc") {
            if(b=="software") return std::string("libx265");
            if(b=="d3d12va") return std::string("hevc_d3d12va");
            return std::string("hevc_")+b;
        }
        if(b=="software") return std::string("libx264");
        if(b=="d3d12va") return std::string("h264_d3d12va");
        return std::string("h264_")+b;
    };

    // A configured backend can also occur in the preference list. Keep the
    // bounded runtime result for this selection pass so an unavailable device
    // cannot impose the preflight timeout twice before software fallback.
    std::map<std::string,bool> preflight_results;
    auto preflight=[&](const std::string& b){
        const auto key=b+":"+enc(b);
        const auto found=preflight_results.find(key);
        if(found!=preflight_results.end()) return found->second;
        const bool usable=hardware_encode_preflight(ini,real,cache,log,b,enc(b));
        preflight_results.emplace(key,usable);
        return usable;
    };

    auto backend_usable=[&](const std::string& b){
        if(!hardware_allowed && b!="software") return false;
        if(!has(enc(b))) return false;
#ifndef _WIN32
        if(b=="qsv" && !linux_has_vendor("0x8086")) return false;
        if(b=="nvenc" && !(fs::exists("/dev/nvidiactl")||fs::exists("/dev/nvidia0"))) return false;
        if(b=="vaapi" && !(linux_has_vendor("0x8086")||linux_has_vendor("0x1002"))) return false;
        if(b=="amf" || b=="d3d12va") return false;
#else
        if(b=="vaapi") return false;
#endif
        return b=="software" || preflight(b);
    };

    if(configured!="auto") {
        // An explicitly configured backend is authoritative. Require the encoder to be
        // compiled in and, on Linux, pass the bounded runtime preflight. The
        // preflight itself is authoritative for container device visibility;
        // a simple host-path check is not used for explicit configurations.
        if((hardware_allowed || configured=="software") && has(enc(configured)) &&
           (configured=="software" || preflight(configured))) return configured;
        log.log("WARNING configured backend=",configured," does not expose ",enc(configured),"; falling back");
    }

    auto prefs=split_csv(ini.get("hardware",p.name=="linux-x64"?"linux_preference":"windows_preference",
                                 p.name=="linux-x64"?"qsv,nvenc,vaapi,software":"qsv,nvenc,amf,d3d12va,software"));
    for(auto b:prefs){ b=lower(b); if(backend_usable(b)) return b; }

    // If no hardware encoder exists, preserve SageTV's request through a software encoder
    // rather than silently turning a requested transcode into stream copy.
    if(backend_usable("software")) return "software";
    return "unavailable";
}

static std::string codec_for_backend(const Ini& ini, const std::string& b, const std::string& family) {
    const auto key="codec_"+family+"_"+b;
    if(family=="hevc") {
        if(b=="software") return ini.get("video",key,"libx265");
        if(b=="d3d12va") return ini.get("video",key,"hevc_d3d12va");
        return ini.get("video",key,"hevc_"+b);
    }
    if(b=="software") return ini.get("video",key,ini.get("video","codec_auto_software","libx264"));
    if(b=="d3d12va") return ini.get("video",key,ini.get("video","codec_auto_d3d12va","h264_d3d12va"));
    return ini.get("video",key,ini.get("video","codec_auto_"+b,"h264_"+b));
}

static std::optional<fs::path> input_path_from_args(const std::vector<std::string>& a) {
    auto i=find_opt(a,{"-i"}); if(!i || *i+1>=a.size()) return std::nullopt;
    auto s=a[*i+1]; if(s=="-" || s.rfind("pipe:",0)==0 || s.find("://")!=std::string::npos) return std::nullopt;
    return fs::path(s);
}

static bool translate_local_stv(std::vector<std::string>& a, Logger& log) {
    auto i=find_opt(a,{"-i"}); if(!i || *i+1>=a.size()) return false;
    auto &u=a[*i+1];
    static const std::vector<std::string> prefixes={"stv://localhost/","stv://127.0.0.1/"};
    for(const auto& p:prefixes) {
        if(lower(u).rfind(lower(p),0)==0) {
            auto old=u; u=u.substr(p.size());
#ifndef _WIN32
            // stv://localhost//var/media/file.ts preserves the POSIX leading slash.
            if(!u.empty() && u[0] != '/' && old.size()>p.size() && old[p.size()]=='/') u="/"+u;
#endif
            log.log("translated local stv input: ",old," -> ",u);
            return true;
        }
    }
    return false;
}

static void merge_plus_flags(std::vector<std::string>& a, const std::string& add) {
    auto cur=get_opt_value(a,{"-fflags"}); std::string merged=cur.value_or("");
    for(auto token: {std::string("+genpts"),std::string("+nobuffer"),std::string("+discardcorrupt")}) {
        if(add.find(token)!=std::string::npos && merged.find(token)==std::string::npos) merged += token;
    }
    if(!merged.empty()) set_input_opt(a,{"-fflags"},"-fflags",merged);
}

static std::optional<std::string> requested_video_codec(const std::vector<std::string>& original) {
    return get_opt_value(original,{"-vcodec","-c:v","-codec:v"});
}

static bool csv_contains_ci(const std::string& csv, const std::string& value) {
    for(const auto& item:split_csv(csv)) if(ieq(item,value)) return true;
    return false;
}

// Return the hardware codec family the MIM should target when SageTV asks for a
// software transcode. No value means the job should remain stream-copy/pass-through.
static std::optional<std::string> requested_transcode_family(const Ini& ini,
                                                              const std::vector<std::string>& original) {
    auto requested=requested_video_codec(original);
    if(!requested) return std::nullopt;
    auto codec=lower(trim(*requested));
    if(codec.empty() || codec=="copy") return std::nullopt;

    if(csv_contains_ci(ini.get("transcode_map","h264_software","h264,libx264,libopenh264"),codec))
        return std::string("h264");
    if(csv_contains_ci(ini.get("transcode_map","hevc_software","hevc,h265,libx265"),codec))
        return std::string("hevc");
    if(csv_contains_ci(ini.get("transcode_map","legacy_software","mpeg4,mpeg2video"),codec))
        return lower(ini.get("transcode_map","legacy_target","h264"));

    // Backward compatibility with the original single/list trigger settings.
    auto values=split_csv(ini.get("general","hardware_trigger_values",
                                  ini.get("general","hardware_trigger_value","mpeg4")));
    for(const auto& value:values)
        if(ieq(codec,value)) return lower(ini.get("transcode_map","trigger_target","h264"));
    return std::nullopt;
}

static bool looks_like_sagetv_job(const std::vector<std::string>& original) {
    if(has_flag(original,"-stdinctrl") || has_flag(original,"-activefile") ||
       has_flag(original,"-sagetvdiscstream")) return true;
    auto i=find_opt(original,{"-i"});
    if(i && *i+1<original.size() && lower(original[*i+1]).rfind("stv://",0)==0) return true;
    return false;
}

static void force_stream_copy(std::vector<std::string>& a, const Ini& ini) {
    // Remove options which require decode/filter/encode and would conflict with -c copy.
    remove_opt_value(a,{"-vcodec","-c:v","-codec:v"});
    remove_opt_value(a,{"-acodec","-c:a","-codec:a"});
    for(const auto& aliases : std::vector<std::vector<std::string>>{
            {"-b","-b:v"},{"-maxrate","-maxrate:v"},{"-bufsize","-bufsize:v"},
            {"-g"},{"-bf"},{"-preset"},{"-profile:v"},{"-level:v"},{"-crf"},
            {"-q:v","-qscale:v"},{"-s"},{"-vf","-filter:v"},{"-pix_fmt"},{"-r"},
            {"-b:a","-ab"},{"-ar"},{"-ac"},{"-af","-filter:a"}}) {
        remove_opt_value(a,aliases);
    }
    if(ini.get_bool("copy_default","video",true))
        set_output_opt(a,{"-vcodec","-c:v","-codec:v"},"-c:v","copy");
    if(ini.get_bool("copy_default","audio",true))
        set_output_opt(a,{"-acodec","-c:a","-codec:a"},"-c:a","copy");
}

static std::vector<std::string> rewrite_args(const Ini& ini, const PlatformInfo& p, const fs::path& exe_dir,
                                              const fs::path& real, const fs::path& ffprobe,
                                              const std::vector<std::string>& original, Logger& log,
                                              bool& stdinctrl, bool& active, std::optional<fs::path>& input,
                                              std::string& backend) {
    std::vector<std::string> a=original;

    // SageTV's historical transcoder calls `-dumpmetadata -v 2 -i <file>`.
    // -dumpmetadata was a SageTV-only FFmpeg customization and does not exist
    // in current upstream FFmpeg.  Passing it through causes an immediate
    // "Option not found" (exit code 8), so SageTV receives no Input/Stream
    // description and reports FORMATERROR.  For modern FFmpeg, remove the
    // private flag and force INFO logging so av_dump_format() emits the same
    // Input/Duration/Stream text SageTV's format parser consumes.
    if (has_flag(a,"-dumpmetadata")) {
        remove_flag(a,"-dumpmetadata");
        remove_opt_value(a,{"-v","-loglevel"});
        a.insert(a.begin(),{"-loglevel","info"});
        stdinctrl=false; active=false; input=input_path_from_args(a); backend="metadata";
        log.log("compat: SageTV -dumpmetadata -> modern FFmpeg input probe at loglevel=info");
        return a;
    }

    if (is_management_call(a)) {
        stdinctrl=false; active=false; input.reset(); backend="passthrough";
        return a;
    }
    const bool sagetv_job=looks_like_sagetv_job(original);
    const bool disc_stream=has_flag(a,"-sagetvdiscstream");
    remove_flag(a,"-sagetvdiscstream");
    if(disc_stream) log.log("compat: SageTV DVD VM stream transform enabled");
    stdinctrl=has_flag(a,"-stdinctrl"); active=has_flag(a,"-activefile");
    remove_flag(a,"-stdinctrl"); remove_flag(a,"-activefile");
    translate_local_stv(a,log);
    input=input_path_from_args(a);
    auto transcode_family=sagetv_job ? requested_transcode_family(ini,original) : std::optional<std::string>{};
    if(lower(ini.get("general","mode","passthrough"))=="always" && !transcode_family)
        transcode_family=lower(ini.get("transcode_map","trigger_target","h264"));
    const bool triggered=transcode_family.has_value();

    if(active && ini.get_bool("active_file","enabled",true)) {
        auto strategy=lower(ini.get("active_file","strategy","stock_follow"));
        if(strategy=="stock_follow") {
            auto ip=find_opt(a,{"-i"});
            if(ip && *ip+1<a.size() && a[*ip+1].find("://")==std::string::npos) {
                a.insert(a.begin()+*ip,{"-follow","1"});
            } else log.log("WARNING activefile stock_follow cannot be applied to non-local/stv input");
        } else if(strategy!="disabled") {
            log.log("WARNING active_file strategy '",strategy,"' not implemented in v0.4.7; treating as disabled");
        }
    }

    // v0.3 policy: recognized SageTV media jobs COPY by default. Hardware transcoding
    // happens only when SageTV explicitly requests a configured trigger codec.
    // Unrelated/normal ffmpeg invocations remain transparent passthrough.
    if(!triggered) {
        auto action=lower(ini.get("general","default_sagetv_action","copy"));
        if(sagetv_job && action=="copy") {
            backend="copy";
            force_stream_copy(a,ini);
            log.log("policy: SageTV job did not match a transcode trigger -> stream copy");
            return a;
        }
        backend="passthrough";
        return a;
    }

    // SageTV commonly supplies numeric -v 3, which suppresses even useful
    // modern FFmpeg diagnostics.  Use a configurable error-level log for
    // mapped transcodes; stderr is still passed through unchanged and may also
    // be mirrored into the MIM log by run_child_posix().
    auto transcode_loglevel=trim(ini.get("logging","ffmpeg_transcode_loglevel","error"));
    if(!transcode_loglevel.empty()) {
        remove_opt_value(a,{"-v","-loglevel"});
        a.insert(a.begin(),{"-loglevel",transcode_loglevel});
    }

    // SageTV's built-in MiniPlayer profile still supplies a number of legacy
    // FFmpeg-2/3 era encode controls.  The known-working shell wrapper rebuilt
    // the transcode command and intentionally did not forward these.  Current
    // FFmpeg rejects some combinations (notably -vsync 0 together with -r),
    // while the remaining MPEG4-era knobs do not apply to QSV/NVENC/VAAPI.
    // Strip them only for an actual mapped transcode; copy/passthrough jobs are
    // left untouched.
    remove_opt_value(a,{"-vsync","-fps_mode"});
    remove_opt_value(a,{"-async"});
    remove_opt_value(a,{"-rc_init_cplx"});
    remove_opt_value(a,{"-mbd"});
    remove_opt_value(a,{"-minrate","-minrate:v"});
    remove_opt_value(a,{"-muxrate"});
    remove_flag(a,"-deinterlace");

    // Preserve the original helper script's DVD/remux shortcut.
    auto requested_format=get_output_opt_value(original,{"-f"});
    auto copy_trigger=trim(ini.get("general","copy_only_format_trigger","dvd"));
    if(requested_format && !copy_trigger.empty() && ieq(*requested_format,copy_trigger)) {
        backend="copy";
        set_output_opt(a,{"-vcodec","-c:v","-codec:v"},"-c:v",ini.get("copy_only","video_codec","copy"));
        set_output_opt(a,{"-acodec","-c:a","-codec:a"},"-c:a",ini.get("copy_only","audio_codec","copy"));
        set_output_opt(a,{"-f"},"-f",ini.get("copy_only","output_format","mpegts"));
        return a;
    }

    // Probe cache: completed, unchanged recordings may use a smaller discovery
    // probe after a background ffprobe has validated the exact file stamp.
    // Never use that shortcut for an active/growing input. The cache records
    // only that video existed; it does not inject FFprobe's stream metadata
    // into FFmpeg. A reduced 64 KiB/128-packet probe on a later active start
    // could therefore miss audio or video depending on current TS packet order.
    if(input && native_file_exists(*input) && ini.get_bool("probe_cache","enabled",true)) {
        ProbeCache pc{exe_dir/ini.get("probe_cache","directory","cache/probe"),&log};
        bool hit=!active && pc.hit(*input);
        long long normal_probe=ini.get_ll("input","probesize",524288), normal_an=ini.get_ll("input","analyzeduration",500000);
        // -follow 1 prevents the growing file from reaching a real EOF during
        // stream discovery. A small normal probe can therefore identify the
        // MPEG-2 PID but fail to obtain width/height, after which FFmpeg maps
        // only audio for the entire job. Active inputs need their own bounded
        // probe window; completed files may still use the faster cache path.
        if(active) {
            normal_probe=ini.get_ll("active_file","probesize",5000000);
            normal_an=ini.get_ll("active_file","analyzeduration",5000000);
        }
        if(hit) {
            set_input_opt(a,{"-probesize"},"-probesize",std::to_string(ini.get_ll("probe_cache","cached_probesize",524288)));
            set_input_opt(a,{"-analyzeduration"},"-analyzeduration",std::to_string(ini.get_ll("probe_cache","cached_analyzeduration",500000)));
            set_input_opt(a,{"-max_probe_packets"},"-max_probe_packets",std::to_string(ini.get_ll("probe_cache","cached_max_probe_packets",1024)));
            if(ini.get_bool("probe_cache","skip_duration_probe",true) && likely_mpegts(*input)) set_input_opt(a,{"-skip_estimate_duration_from_pts"},"-skip_estimate_duration_from_pts","1");
            log.log("probe-cache HIT input=",input->string());
        } else {
            set_input_opt(a,{"-probesize"},"-probesize",std::to_string(normal_probe));
            set_input_opt(a,{"-analyzeduration"},"-analyzeduration",std::to_string(normal_an));
            if(!active && native_file_exists(ffprobe))
                pc.populate_async(ffprobe,*input,normal_probe,normal_an);
            if(active)
                log.log("probe-cache BYPASS active probe_bytes=",normal_probe,
                        " analyze_us=",normal_an," input=",input->string());
            else
                log.log("probe-cache MISS input=",input->string());
        }
    } else {
        if(lower(ini.get("input","probesize_mode","override"))=="override") set_input_opt(a,{"-probesize"},"-probesize",ini.get("input","probesize","524288"));
        if(lower(ini.get("input","analyzeduration_mode","override"))=="override") set_input_opt(a,{"-analyzeduration"},"-analyzeduration",ini.get("input","analyzeduration","500000"));
    }

    if(lower(ini.get("input","fflags_mode","append"))=="append") merge_plus_flags(a,ini.get("input","fflags","+genpts+discardcorrupt"));
    if(lower(ini.get("input","thread_queue_size_mode","override"))=="override") set_input_opt(a,{"-thread_queue_size"},"-thread_queue_size",ini.get("input","thread_queue_size","8192"));
    if(lower(ini.get("input","max_delay_mode","override"))=="override") set_input_opt(a,{"-max_delay"},"-max_delay",ini.get("input","max_delay","500000"));
    if(active && input && likely_mpegts(*input) && ini.get_ll("input","mpegts_resync_size",0)>0) set_input_opt(a,{"-resync_size"},"-resync_size",ini.get("input","mpegts_resync_size","1048576"));
    // Directly seeking into broadcast MPEG-2 TS can land between sequence
    // headers. On the commissioned Intel host that produced invalid 0x0 MPEG-2
    // frames and eventually crashed FFmpeg's QSV transcode after a MiniPlayer
    // FF/REW. Seek a few seconds earlier and discard that bounded preroll on
    // the output side so the decoder reaches a clean GOP before emitting data.
    add_completed_mpegts_seek_preroll(a,ini,input,active,log);
    if(ini.get_bool("seek","fast_seek",false)) { auto pos=input_option_pos(a); a.insert(a.begin()+pos,"-noaccurate_seek"); }

    const auto family=transcode_family.value_or("h264");
    const bool active_hardware_encode=ini.get_bool("hardware","active_file_hardware_encode",true);
    if(active && !active_hardware_encode)
        log.log("compat: active-file hardware encode disabled; selecting software without GPU preflight");
    backend=choose_backend(ini,p,real,exe_dir/"cache/capabilities",log,family,
                           !active || active_hardware_encode);
    if(backend=="unavailable") {
        auto fallback=lower(ini.get("transcode_map","on_encoder_unavailable","passthrough"));
        log.log("WARNING no encoder available for requested transcode family=",family," fallback=",fallback);
        if(fallback=="copy") {
            backend="copy";
            force_stream_copy(a,ini);
            return a;
        }
        backend="passthrough";
        return a;
    }

    // Some QSV drivers repeatedly reinitialize VA-API when encoding a newly
    // growing MPEG-TS input. FFmpeg keeps producing audio in that state, which
    // leaves the MiniClient stuck on an audio-only Matroska stream. Permit live
    // jobs to use the deterministic software encoder while retaining the
    // selected GPU backend for completed/prerecorded files.
    // The custom FFmpeg rate-control hook is only needed for an actual encode job.
    if(stdinctrl && ini.get_bool("stdinctrl","enabled",true))
        a.insert(a.begin(),"-sagetvratectrl");

    const bool preserve_a53cc=ini.get_bool("closed_captions","preserve_a53cc",true);
    // Hardware MPEG-2 decoders commonly drop AV_FRAME_DATA_A53_CC before the
    // encoder can write it as H.264 user data. Preserve the decoded A/53 frame
    // side data in system memory for every GPU encoder. Deinterlace/scale then
    // uploads the video frames to QSV/VAAPI/NVENC, so video encoding remains on
    // the selected GPU while captions follow FFmpeg's native -a53cc path.
    // qsv_software_decode remains a backward-compatible per-backend override;
    // caption_software_decode is the new cross-vendor default.
    const bool caption_decode_policy=ini.has("closed_captions","caption_software_decode")
        ? ini.get_bool("closed_captions","caption_software_decode",true)
        : (backend=="qsv" && ini.get_bool("closed_captions","qsv_software_decode",true));
    const bool force_caption_software_decode=preserve_a53cc && caption_decode_policy &&
        (backend=="qsv" || backend=="nvenc" || backend=="vaapi");
    const bool configured_hardware_decode=ini.get_bool("hardware","hardware_decode",false);
    const bool hardware_decode=configured_hardware_decode && !force_caption_software_decode &&
        (!active || ini.get_bool("hardware","active_file_hardware_decode",false));
    if(force_caption_software_decode && configured_hardware_decode)
        log.log("compat: ",backend," uses caption-preserving software decode with hardware filter/encode");
    if(active && configured_hardware_decode && !hardware_decode)
        log.log("compat: active-file uses software decode with ",backend," encode");

    // QSV encode needs a device context even when decoding stays in software.
    // Keep device initialization separate from hardware_decode so the safe
    // software-decode -> QSV-encode path works. The Linux syntax below is the
    // form validated on the Ubuntu 26.04 SageTV runtime with oneVPL 2.x.
    if (backend=="qsv") {
#ifndef _WIN32
        auto dev=trim(ini.get("hardware","linux_render_device","/dev/dri/renderD128"));
        if(!dev.empty()) {
            remove_opt_value(a,{"-init_hw_device"});
            auto pos=input_option_pos(a);
            a.insert(a.begin()+pos,{"-init_hw_device","qsv:hw,child_device="+dev});
        }
#endif
        if(hardware_decode) {
            set_input_opt(a,{"-hwaccel"},"-hwaccel","qsv");
            set_input_opt(a,{"-hwaccel_device"},"-hwaccel_device","hw");
            set_input_opt(a,{"-hwaccel_output_format"},"-hwaccel_output_format","qsv");
        } else {
            remove_opt_value(a,{"-hwaccel"});
            remove_opt_value(a,{"-hwaccel_device"});
            remove_opt_value(a,{"-hwaccel_output_format"});
        }
    } else if (hardware_decode && backend=="nvenc") {
        set_input_opt(a,{"-hwaccel"},"-hwaccel","cuda");
        set_input_opt(a,{"-hwaccel_output_format"},"-hwaccel_output_format","cuda");
    } else if (backend=="vaapi") {
        auto dev=trim(ini.get("hardware","linux_render_device","/dev/dri/renderD128"));
        // VAAPI encoding requires a device even when input decoding remains in
        // software. -vaapi_device provides the hardware frames context used by
        // the upload filter and encoder; -hwaccel_device alone is insufficient
        // for the software-decode -> VAAPI-encode path.
        if(!dev.empty()) set_input_opt(a,{"-vaapi_device"},"-vaapi_device",dev);
        if(hardware_decode) {
            set_input_opt(a,{"-hwaccel"},"-hwaccel","vaapi");
            set_input_opt(a,{"-hwaccel_output_format"},"-hwaccel_output_format","vaapi");
            if(!dev.empty()) set_input_opt(a,{"-hwaccel_device"},"-hwaccel_device",dev);
        }
    }

    auto expand_filter_size=[](std::string text,const std::string& width,const std::string& height){
        auto replace_all=[](std::string& value,const std::string& from,const std::string& to){
            size_t p=0;
            while((p=value.find(from,p))!=std::string::npos){
                value.replace(p,from.size(),to);
                p+=to.size();
            }
        };
        replace_all(text,"%w%",width);
        replace_all(text,"%h%",height);
        return text;
    };
    auto requested_size=get_opt_value(a,{"-s"});
    std::string requested_width,requested_height;
    if(requested_size) {
        auto x=lower(*requested_size).find('x');
        if(x!=std::string::npos && x>0 && x+1<requested_size->size()) {
            requested_width=requested_size->substr(0,x);
            requested_height=requested_size->substr(x+1);
        }
    }
    auto apply_hardware_filter=[&](const std::string& prefix,
                                   const std::string& default_no_scale,
                                   const std::string& default_scale){
        auto filter_mode=lower(ini.get("filters","deinterlace","auto"));
        if(filter_mode!="on" && filter_mode!="auto") return;
        std::string vf;
        if(!requested_width.empty() && !requested_height.empty()) {
            vf=expand_filter_size(ini.get("filters",prefix+"_scale",default_scale),
                                  requested_width,requested_height);
            remove_opt_value(a,{"-s"});
        } else {
            vf=ini.get("filters",prefix+"_no_scale",default_no_scale);
        }
        if(!trim(vf).empty()) set_output_opt(a,{"-vf","-filter:v"},"-vf",vf);
    };

    // Restore backend-native deinterlace/scale filters when the decoder emits
    // hardware frames. Software filters cannot consume QSV/CUDA/VAAPI frames
    // and were the source of silent/no-video startup failures on non-QSV GPUs.
    if(backend=="qsv" && hardware_decode) {
        apply_hardware_filter("qsv","deinterlace_qsv",
                              "deinterlace_qsv,scale_qsv=w=%w%:h=%h%");
    } else if(backend=="qsv") {
        // h264_qsv accepts NV12 system-memory frames and performs its own
        // upload. Keep deinterlace/scale in software when decoding in software.
        // The former hwupload+scale_qsv chain ran at almost exactly realtime
        // on growing 1080i MPEG-2 input and intermittently delivered audio
        // before any video. Feeding system-memory NV12 to the same QSV encoder
        // preserves A/53 side data and leaves substantially more live headroom.
        std::string vf;
        if(!requested_width.empty() && !requested_height.empty()) {
            vf=expand_filter_size(ini.get("filters","qsv_software_scale",
                    "yadif=deint=interlaced,scale=w=%w%:h=%h%,format=nv12"),
                    requested_width,requested_height);
            remove_opt_value(a,{"-s"});
        } else {
            vf=ini.get("filters","qsv_software_no_scale",
                       "yadif=deint=interlaced,format=nv12");
        }
        if(!trim(vf).empty()) set_output_opt(a,{"-vf","-filter:v"},"-vf",vf);
    } else if(backend=="nvenc" && hardware_decode) {
        apply_hardware_filter("nvenc","yadif_cuda=deint=interlaced",
                              "yadif_cuda=deint=interlaced,scale_cuda=w=%w%:h=%h%");
    } else if(backend=="vaapi" && hardware_decode) {
        apply_hardware_filter("vaapi","deinterlace_vaapi=auto=1",
                              "deinterlace_vaapi=auto=1,scale_vaapi=w=%w%:h=%h%");
    } else if(backend=="vaapi") {
        // VAAPI encoders accept hardware frames only. Upload software-decoded
        // frames explicitly, optionally scaling on the GPU. Without this chain
        // h264_vaapi/hevc_vaapi fails before emitting a video packet.
        std::string vf;
        if(!requested_width.empty() && !requested_height.empty()) {
            vf=expand_filter_size(ini.get("filters","vaapi_software_scale",
                    "yadif=deint=interlaced,format=nv12,hwupload,scale_vaapi=w=%w%:h=%h%"),
                    requested_width,requested_height);
            remove_opt_value(a,{"-s"});
        } else {
            vf=ini.get("filters","vaapi_software_no_scale",
                       "yadif=deint=interlaced,format=nv12,hwupload");
        }
        if(!trim(vf).empty()) set_output_opt(a,{"-vf","-filter:v"},"-vf",vf);
    }

    auto codec=codec_for_backend(ini,backend,family);
    set_output_opt(a,{"-vcodec","-c:v","-codec:v"},"-c:v",codec);

    if(lower(ini.get("video","gop_mode","clamp"))=="clamp") {
        auto g=get_opt_value(a,{"-g"}); long long maxg=ini.get_ll("video","gop_max",60);
        if(g && maxg>0 && parse_ll(*g,maxg)>maxg) set_output_opt(a,{"-g"},"-g",std::to_string(maxg));
    }
    if(lower(ini.get("video","bframes_mode","override"))=="override") set_output_opt(a,{"-bf"},"-bf",ini.get("video","bframes","0"));

    auto preset=ini.get("video","preset","auto"); if(preset=="auto") preset=ini.get("video","preset_"+backend,"");
    if(lower(ini.get("video","preset_mode","override"))=="override" && !preset.empty()) set_output_opt(a,{"-preset"},"-preset",preset);

    auto br=get_opt_value(a,{"-b:v","-b"});
    if(br) {
        set_output_opt(a,{"-b:v","-b"},"-b:v",*br);
    }
    if(br) if(auto bps=parse_bitrate_bps(*br)) {
        double mm=1.5,bm=3.0; try{mm=std::stod(ini.get("video","maxrate_multiplier","1.5"));}catch(...){} try{bm=std::stod(ini.get("video","bufsize_multiplier","3.0"));}catch(...){}
        set_output_opt(a,{"-maxrate","-maxrate:v"},"-maxrate",format_bitrate((long long)(*bps*mm)));
        set_output_opt(a,{"-bufsize","-bufsize:v"},"-bufsize",format_bitrate((long long)(*bps*bm)));
    }

    // MiniPlayer fixed-push profiles are a wire contract, not merely a codec hint.
    // If SageTV explicitly supplied an audio codec/shape or output container, keep it
    // by default and change only the requested video encoder family.  v0.4.1 broke
    // this contract by converting Matroska+MP2 to MPEG-TS+AC3-copy, which produced
    // audio-only playback on the tested MiniPlayer and was followed by a native
    // SageTV abort while switching files.
    const bool preserve_contract = sagetv_job && ini.get_bool("compatibility","preserve_sagetv_output_contract",true);
    const auto requested_audio = get_opt_value(original,{"-acodec","-c:a","-codec:a"});
    const auto requested_output_format = get_opt_value(original,{"-f"});

    if(preserve_contract && requested_audio) {
        // SageTV's legacy FFmpeg adapter still translates AAC to libfaac. Modern
        // FFmpeg removed that external encoder years ago and provides the native
        // encoder as "aac". Preserve the requested AAC wire codec while translating
        // only the obsolete encoder implementation name.
        if(ieq(*requested_audio,"libfaac")) {
            set_output_opt(a,{"-acodec","-c:a","-codec:a"},"-c:a","aac");
            log.log("compat: translated obsolete SageTV audio encoder libfaac to aac");
        } else {
            log.log("compat: preserving SageTV requested audio contract codec=",*requested_audio);
        }
    } else {
        auto amode=lower(ini.get("audio","mode","copy"));
        if(amode=="copy") {
            remove_opt_value(a,{"-ab","-b:a"});
            remove_opt_value(a,{"-ar"});
            remove_opt_value(a,{"-ac"});
            set_output_opt(a,{"-acodec","-c:a","-codec:a"},"-c:a","copy");
        }
        else if(amode=="ac3") set_output_opt(a,{"-acodec","-c:a","-codec:a"},"-c:a",ini.get("audio","codec","ac3"));
    }

    if(preserve_contract && requested_output_format) {
        log.log("compat: preserving SageTV requested output container=",*requested_output_format);
    } else if(lower(ini.get("output","format_mode","override"))=="override") {
        set_output_opt(a,{"-f"},"-f",ini.get("output","format","mpegts"));
    }

    // Generic low-latency options are safe for the requested muxer.
    if(lower(ini.get("output","flush_packets_mode","override"))=="override") set_output_opt(a,{"-flush_packets"},"-flush_packets",ini.get("output","flush_packets","1"));
    if(lower(ini.get("output","max_interleave_delta_mode","override"))=="override") set_output_opt(a,{"-max_interleave_delta"},"-max_interleave_delta",ini.get("output","max_interleave_delta","500000"));

    // MPEG-TS-specific options must never be injected into Matroska/other fixed-push
    // formats.  Determine the final output muxer after the compatibility decision.
    auto effective_format=get_output_opt_value(a,{"-f"});
    const bool output_is_mpegts=effective_format && ieq(*effective_format,"mpegts");
    if(output_is_mpegts) {
        if(lower(ini.get("output","muxpreload_mode","override"))=="override") set_output_opt(a,{"-muxpreload"},"-muxpreload",ini.get("output","muxpreload","0"));
        if(lower(ini.get("output","muxdelay_mode","override"))=="override") set_output_opt(a,{"-muxdelay"},"-muxdelay",ini.get("output","muxdelay","0"));
        if(ini.get_bool("output","mpegts_initial_discontinuity",true)) {
            auto mf=get_opt_value(a,{"-mpegts_flags"}); auto v=mf.value_or(""); if(v.find("initial_discontinuity")==std::string::npos) v += "+initial_discontinuity";
            if(ini.get_bool("output","mpegts_resend_headers",true) && v.find("resend_headers")==std::string::npos) v += "+resend_headers";
            set_output_opt(a,{"-mpegts_flags"},"-mpegts_flags",v);
        }
    } else {
        remove_opt_value(a,{"-mpegts_flags"});
        remove_opt_value(a,{"-muxpreload"});
        remove_opt_value(a,{"-muxdelay"});
    }

    // Preserve A/53 CEA-608/708 caption side data where common H.264 encoders expose -a53cc.
    if(preserve_a53cc && (backend=="qsv"||backend=="nvenc"||backend=="vaapi"||backend=="software"))
        set_output_opt(a,{"-a53cc"},"-a53cc","1");

    // SageTV live recordings with a .ts/.m2ts suffix are known MPEG-TS. Tell
    // libavformat directly so it does not spend startup time identifying the
    // container again. Insert this last: -f is both an input and output option,
    // and earlier output-option normalization must continue to see the actual
    // MiniPlayer output muxer rather than this input demuxer hint.
    if(active && input && likely_mpegts(*input) && ini.get_bool("active_file","force_mpegts_demuxer",true)) {
        auto p=input_option_pos(a);
        a.insert(a.begin()+p,{"-f","mpegts"});
        log.log("compat: active-file input demuxer forced to mpegts");
    }

    auto extra=trim(ini.get("video","extra_"+backend,""));
    if(!extra.empty()) log.log("NOTE extra_",backend," is configured but shell-style token parsing is intentionally disabled in v0.1 for safety: ",extra);

    return a;
}

struct ControlConfig {
    bool enabled=true, case_insensitive=true, rate_enabled=false;
    std::set<std::string> stop;
    std::string rate_mode="forward";
    std::string inactive_action="terminate_child";
    bool active=false;
    bool isolate_child_process=true;
    long long terminate_grace_ms=2000;
};

static bool is_stop_cmd(const ControlConfig& c, std::string line) {
    line=trim(line); if(c.case_insensitive) line=lower(line); return c.stop.count(line)>0;
}
static bool starts_ci(const std::string& s, const std::string& p) { return lower(trim(s)).rfind(lower(p),0)==0; }

#ifndef _WIN32
static volatile sig_atomic_t g_mim_parent_signal = 0;
static void mim_parent_signal_handler(int sig) { g_mim_parent_signal = sig; }

static int run_child_posix(const fs::path& exe, const std::vector<std::string>& args,
                           const ControlConfig& cc, Logger& log, bool log_stderr) {
    // The MIM must survive a child closing its stdin or SageTV closing an
    // inherited pipe.  Restore normal SIGPIPE semantics in ffmpeg.real after
    // fork so a broken MiniPlayer output pipe terminates FFmpeg, not the MIM.
    struct sigaction old_sigpipe{};
    struct sigaction ign_sigpipe{};
    ign_sigpipe.sa_handler=SIG_IGN;
    sigemptyset(&ign_sigpipe.sa_mask);
    sigaction(SIGPIPE,&ign_sigpipe,&old_sigpipe);

    int pin[2];
    if(pipe(pin)!=0){ log.log("ERROR stdin pipe failed errno=",errno); sigaction(SIGPIPE,&old_sigpipe,nullptr); return 127; }

    int perr[2]={-1,-1};
    if(log_stderr && pipe(perr)!=0) {
        log.log("WARNING stderr capture pipe failed errno=",errno,"; inheriting stderr");
        log_stderr=false;
    }

    // Record the MIM PID before fork. On Linux, ffmpeg.real arms a parent-death
    // SIGKILL before exec so a hard-killed/destroyed MIM cannot leave the old
    // hardware transcoder running across a SageTV MiniPlayer full switch.
    const pid_t mim_parent_pid=getpid();
    pid_t pid=fork();
    if(pid<0){
        close(pin[0]); close(pin[1]);
        if(perr[0]>=0) close(perr[0]);
        if(perr[1]>=0) close(perr[1]);
        sigaction(SIGPIPE,&old_sigpipe,nullptr);
        return 127;
    }
    if(pid==0){
        // Put ffmpeg.real in its own process group before exec.  STOP/QUIT can
        // then target only FFmpeg and any helper descendants; the SageTV JVM
        // and the MIM remain outside this group.
        if(cc.isolate_child_process) (void)setpgid(0,0);
#ifdef __linux__
        if(cc.isolate_child_process) {
            // PR_SET_PDEATHSIG survives exec. If SageTV destroys the MIM with a
            // signal instead of sending STOP/QUIT, the direct ffmpeg.real child
            // is still guaranteed to receive SIGKILL. Check getppid() afterward
            // to close the small race where the parent died before prctl().
            if(prctl(PR_SET_PDEATHSIG,SIGKILL)!=0) _exit(125);
            if(getppid()!=mim_parent_pid) _exit(125);
        }
#endif
        struct sigaction dfl_sigpipe{};
        dfl_sigpipe.sa_handler=SIG_DFL;
        sigemptyset(&dfl_sigpipe.sa_mask);
        sigaction(SIGPIPE,&dfl_sigpipe,nullptr);

        dup2(pin[0],STDIN_FILENO);
        close(pin[0]); close(pin[1]);
        if(log_stderr) {
            close(perr[0]);
            dup2(perr[1],STDERR_FILENO);
            close(perr[1]);
        }
        std::vector<char*> av; std::string ex=exe.string(); av.push_back(ex.data());
        std::vector<std::string> copy=args; for(auto& x:copy) av.push_back(x.data()); av.push_back(nullptr);
        execv(ex.c_str(),av.data()); _exit(127);
    }

    // Race-proof the child's process-group creation from the parent too. EACCES
    // simply means the child already exec'd after successfully doing setpgid().
    if(cc.isolate_child_process && setpgid(pid,pid)!=0 && errno!=EACCES && errno!=ESRCH)
        log.log("WARNING child process-group isolation setpgid failed pid=",pid," errno=",errno);
    else if(cc.isolate_child_process) {
        log.log("safety: ffmpeg child isolated pid=",pid," pgid=",pid);
#ifdef __linux__
        log.log("safety: parent-death SIGKILL configured for ffmpeg child pid=",pid," mim_pid=",mim_parent_pid);
#endif
    }

    // SageTV may destroy the MIM process directly while performing a full
    // MiniPlayer encoding switch. Convert normal termination signals into a
    // child-process-group teardown so ffmpeg.real is reaped before MIM exits.
    g_mim_parent_signal=0;
    struct sigaction parent_sa{}, old_sigterm{}, old_sigint{}, old_sighup{}, old_sigquit{};
    parent_sa.sa_handler=mim_parent_signal_handler;
    sigemptyset(&parent_sa.sa_mask);
    sigaction(SIGTERM,&parent_sa,&old_sigterm);
    sigaction(SIGINT,&parent_sa,&old_sigint);
    sigaction(SIGHUP,&parent_sa,&old_sighup);
    sigaction(SIGQUIT,&parent_sa,&old_sigquit);

    close(pin[0]);
    if(log_stderr) {
        close(perr[1]);
        fcntl(perr[0],F_SETFL,fcntl(perr[0],F_GETFL,0)|O_NONBLOCK);
    }
    fcntl(STDIN_FILENO,F_SETFL,fcntl(STDIN_FILENO,F_GETFL,0)|O_NONBLOCK);

    std::string buf, errbuf;
    bool stdin_open=true, child_stdin_open=true, kill_escalated=false, parent_signal_logged=false;
    int status=0;
    std::optional<std::chrono::steady_clock::time_point> terminate_requested;

    auto signal_child=[&](int sig,const char* reason){
        if(cc.isolate_child_process) {
            if(kill(-pid,sig)==0) {
                log.log("control: ",reason," -> signal=",sig," ffmpeg process-group pgid=",pid);
                return;
            }
            int group_errno=errno;
            if(group_errno==ESRCH) return;
            if(kill(pid,sig)!=0 && errno!=ESRCH) {
                log.log("WARNING safety: failed to signal child pid=",pid," sig=",sig," group_errno=",group_errno," errno=",errno);
                return;
            }
            log.log("control: ",reason," -> signal=",sig," ffmpeg child pid=",pid," (process-group signal failed errno=",group_errno,")");
            return;
        }
        if(kill(pid,sig)!=0 && errno!=ESRCH) {
            log.log("WARNING safety: failed to signal child pid=",pid," sig=",sig," errno=",errno);
            return;
        }
        log.log("control: ",reason," -> signal=",sig," ffmpeg child pid=",pid);
    };
    auto request_terminate=[&](const char* reason){
        if(!terminate_requested) {
            terminate_requested=std::chrono::steady_clock::now();
            signal_child(SIGTERM,reason);
        }
    };
    auto handle_parent_stdin_closed=[&](const char* reason){
        if(!stdin_open) return;
        stdin_open=false;
        // SageTV's MiniPlayer full-switch path can close the transcoder stdin
        // without first writing STOP/QUIT. For -stdinctrl jobs, EOF/HUP is an
        // unambiguous teardown event and must terminate the isolated FFmpeg
        // process group before the next MiniPlayer is initialized.
        if(cc.enabled) {
            log.log("control: ",reason," -> terminate ffmpeg process-group");
            request_terminate(reason);
        }
        if(child_stdin_open && pin[1]>=0) {
            close(pin[1]); pin[1]=-1; child_stdin_open=false;
        }
    };
    auto send_line=[&](const std::string& l){
        if(!child_stdin_open) return;
        std::string x=l+"\n";
        ssize_t n=write(pin[1],x.data(),x.size());
        if(n<0 && (errno==EPIPE || errno==EBADF)) {
            log.log("safety: ffmpeg stdin closed while forwarding control; containing EPIPE");
            close(pin[1]); pin[1]=-1; child_stdin_open=false;
        } else if(n<0) {
            log.log("WARNING control write to ffmpeg stdin failed errno=",errno);
        }
    };
    auto log_err_lines=[&](){
        size_t e;
        while((e=errbuf.find_first_of("\r\n"))!=std::string::npos) {
            auto line=errbuf.substr(0,e);
            size_t skip=1;
            if(e+1<errbuf.size() && errbuf[e]=='\r' && errbuf[e+1]=='\n') skip=2;
            errbuf.erase(0,e+skip);
            if(!line.empty()) log.log("ffmpeg-stderr: ",line);
        }
    };
    auto drain_stderr=[&](){
        if(!log_stderr) return;
        char tmp[4096];
        for(;;) {
            ssize_t n=read(perr[0],tmp,sizeof(tmp));
            if(n>0) {
                // Preserve the exact child stderr stream for SageTV/console consumers.
                ssize_t off=0;
                while(off<n) {
                    ssize_t w=write(STDERR_FILENO,tmp+off,(size_t)(n-off));
                    if(w<=0) break;
                    off+=w;
                }
                errbuf.append(tmp,(size_t)n);
                log_err_lines();
                continue;
            }
            break;
        }
    };

    for(;;){
        struct pollfd pfds[2]; nfds_t nfds=0; int stdin_idx=-1, err_idx=-1;
        if(stdin_open) { stdin_idx=(int)nfds; pfds[nfds++]={STDIN_FILENO,POLLIN|POLLHUP,0}; }
        if(log_stderr) { err_idx=(int)nfds; pfds[nfds++]={perr[0],POLLIN|POLLHUP,0}; }
        int pr=poll(pfds,nfds,100);
        if(pr>0 && stdin_idx>=0) {
            auto re=pfds[stdin_idx].revents;
            if(re&POLLIN) {
                char tmp[1024]; ssize_t n=read(STDIN_FILENO,tmp,sizeof(tmp));
                if(n>0){
                    if(!cc.enabled) {
                        ssize_t off=0;
                        while(off<n && child_stdin_open) {
                            ssize_t written=write(pin[1],tmp+off,(size_t)(n-off));
                            if(written>0) off+=written;
                            else if(written<0 && errno==EINTR) continue;
                            else {
                                if(errno==EPIPE || errno==EBADF)
                                    log.log("safety: ffmpeg stdin closed during raw media forwarding");
                                else
                                    log.log("WARNING raw media write to ffmpeg stdin failed errno=",errno);
                                close(pin[1]); pin[1]=-1; child_stdin_open=false;
                            }
                        }
                    } else {
                        buf.append(tmp,(size_t)n); size_t e;
                        while((e=buf.find_first_of("\r\n"))!=std::string::npos){
                            auto line=buf.substr(0,e); size_t skip=1;
                            if(e+1<buf.size() && buf[e]=='\r'&&buf[e+1]=='\n')skip=2;
                            buf.erase(0,e+skip);
                            auto t=trim(line); if(t.empty()) continue; log.log("stdin: ",t);
                            if(is_stop_cmd(cc,t)) request_terminate("stop");
                            else if(starts_ci(t,"inactivefile")){
                                if(cc.active && cc.inactive_action=="terminate_child") request_terminate("inactivefile");
                                else log.log("control: inactivefile consumed action=",cc.inactive_action);
                            }
                            else if(starts_ci(t,"videorateadapt")||starts_ci(t,"sagetv_videorateadapt")){
                                if(!cc.rate_enabled) log.log("control: videorateadapt consumed (stream-copy/no rate-control encoder)");
                                else if(cc.rate_mode=="forward") send_line(t);
                                else log.log("control: videorateadapt ignored mode=",cc.rate_mode);
                            }
                            else send_line(t);
                        }
                    }
                } else if(n==0) handle_parent_stdin_closed("stdin EOF");
            }
            if(re&POLLHUP) handle_parent_stdin_closed("stdin HUP");
        }
        if(pr>0 && err_idx>=0 && (pfds[err_idx].revents&(POLLIN|POLLHUP))) drain_stderr();

        if(g_mim_parent_signal!=0 && !parent_signal_logged) {
            parent_signal_logged=true;
            const int sig=(int)g_mim_parent_signal;
            log.log("control: parent signal=",sig," -> terminate ffmpeg process-group");
            request_terminate("parent signal");
            // Do not accept further SageTV control bytes after process teardown
            // has begun. Closing this write end also guarantees FFmpeg sees EOF.
            stdin_open=false;
            if(child_stdin_open && pin[1]>=0) {
                close(pin[1]); pin[1]=-1; child_stdin_open=false;
            }
        }

        if(terminate_requested && !kill_escalated && cc.terminate_grace_ms>=0) {
            auto elapsed=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-*terminate_requested).count();
            if(elapsed>=cc.terminate_grace_ms) {
                kill_escalated=true;
                signal_child(SIGKILL,"terminate grace expired");
            }
        }

        pid_t r=waitpid(pid,&status,WNOHANG);
        if(r==pid) {
            // Drain bytes written immediately before exit before closing the pipe.
            for(int i=0;i<4;++i) { drain_stderr(); usleep(1000); }
            break;
        }
    }
    if(child_stdin_open && pin[1]>=0) close(pin[1]);
    if(log_stderr) {
        drain_stderr();
        close(perr[0]);
        if(!errbuf.empty()) log.log("ffmpeg-stderr: ",errbuf);
    }
    sigaction(SIGTERM,&old_sigterm,nullptr);
    sigaction(SIGINT,&old_sigint,nullptr);
    sigaction(SIGHUP,&old_sighup,nullptr);
    sigaction(SIGQUIT,&old_sigquit,nullptr);
    sigaction(SIGPIPE,&old_sigpipe,nullptr);
    g_mim_parent_signal=0;
    if(WIFEXITED(status)) return WEXITSTATUS(status);
    if(WIFSIGNALED(status)) {
        int sig=WTERMSIG(status);
        log.log("safety: ffmpeg child terminated by signal=",sig,"; parent SageTV/MIM remain isolated");
        return 128+sig;
    }
    return 1;
}
#else
static std::wstring widen(const std::string& s){
    if(s.empty())return{};
    int n=MultiByteToWideChar(CP_UTF8,0,s.c_str(),-1,nullptr,0);
    if(n<=1)return{};
    std::wstring w((size_t)n,L'\0');
    MultiByteToWideChar(CP_UTF8,0,s.c_str(),-1,w.data(),n);
    w.resize((size_t)n-1);
    return w;
}
static std::wstring quote_win(const std::wstring& s){ if(s.find_first_of(L" \t\"")==std::wstring::npos)return s; std::wstring r=L"\""; unsigned bs=0; for(wchar_t c:s){ if(c==L'\\'){bs++;continue;} if(c==L'\"'){r.append(bs*2+1,L'\\');r+=L'\"';bs=0;continue;} r.append(bs,L'\\');bs=0;r+=c;} r.append(bs*2,L'\\');r+=L'\"'; return r; }
static int run_child_windows(const fs::path& exe,const std::vector<std::string>& args,const ControlConfig& cc,Logger& log){
    SECURITY_ATTRIBUTES sa{sizeof(sa),nullptr,TRUE};
    HANDLE rd=nullptr,wr=nullptr;
    if(!CreatePipe(&rd,&wr,&sa,0))return 127;
    SetHandleInformation(wr,HANDLE_FLAG_INHERIT,0);

    std::wstring cmd=quote_win(exe.wstring());
    for(auto&a:args)cmd+=L" "+quote_win(widen(a));
    std::vector<wchar_t> mutable_cmd(cmd.begin(),cmd.end()); mutable_cmd.push_back(0);
    STARTUPINFOW si{}; si.cb=sizeof(si); si.dwFlags=STARTF_USESTDHANDLES;
    si.hStdInput=rd; si.hStdOutput=GetStdHandle(STD_OUTPUT_HANDLE); si.hStdError=GetStdHandle(STD_ERROR_HANDLE);
    PROCESS_INFORMATION pi{};
    BOOL ok=CreateProcessW(exe.wstring().c_str(),mutable_cmd.data(),nullptr,nullptr,TRUE,0,nullptr,exe.parent_path().wstring().c_str(),&si,&pi);
    CloseHandle(rd);
    if(!ok){CloseHandle(wr);log.log("ERROR CreateProcess failed code=",GetLastError());return 127;}

    HANDLE hin=GetStdHandle(STD_INPUT_HANDLE);
    std::string buf;
    auto send_line=[&](const std::string& l){ std::string x=l+"\n"; DWORD n=0; WriteFile(wr,x.data(),(DWORD)x.size(),&n,nullptr); };
    bool stdin_pipe=true;
    for(;;) {
        DWORD wait=WaitForSingleObject(pi.hProcess,50);
        if(wait==WAIT_OBJECT_0) break;
        if(!stdin_pipe || hin==INVALID_HANDLE_VALUE || hin==nullptr) continue;
        DWORD avail=0;
        if(!PeekNamedPipe(hin,nullptr,0,nullptr,&avail,nullptr)) {
            stdin_pipe=false;
            if(wr!=INVALID_HANDLE_VALUE && wr!=nullptr) { CloseHandle(wr); wr=nullptr; }
            continue;
        }
        if(!avail) continue;
        char tmp[1024]; DWORD n=0;
        if(!ReadFile(hin,tmp,(DWORD)std::min<DWORD>((DWORD)sizeof(tmp),avail),&n,nullptr) || n==0) { stdin_pipe=false; continue; }
        if(!cc.enabled) {
            DWORD off=0;
            while(off<n && wr!=nullptr) {
                DWORD written=0;
                if(!WriteFile(wr,tmp+off,n-off,&written,nullptr) || written==0) {
                    log.log("safety: ffmpeg stdin closed during raw media forwarding code=",GetLastError());
                    CloseHandle(wr); wr=nullptr;
                    break;
                }
                off+=written;
            }
        } else {
            buf.append(tmp,(size_t)n);
            size_t e;
            while((e=buf.find_first_of("\r\n"))!=std::string::npos) {
                auto line=buf.substr(0,e); size_t skip=1;
                if(e+1<buf.size() && buf[e]=='\r'&&buf[e+1]=='\n')skip=2;
                buf.erase(0,e+skip);
                auto t=trim(line); if(t.empty())continue;
                log.log("stdin: ",t);
                if(is_stop_cmd(cc,t)) {
                    log.log("control: stop -> TerminateProcess pid=",pi.dwProcessId);
                    TerminateProcess(pi.hProcess,0);
                } else if(starts_ci(t,"inactivefile")) {
                    if(cc.active && cc.inactive_action=="terminate_child") {
                        log.log("control: inactivefile -> terminate stock-follow child pid=",pi.dwProcessId);
                        TerminateProcess(pi.hProcess,0);
                    } else log.log("control: inactivefile consumed action=",cc.inactive_action);
                } else if(starts_ci(t,"videorateadapt")||starts_ci(t,"sagetv_videorateadapt")) {
                    if(!cc.rate_enabled) log.log("control: videorateadapt consumed (stream-copy/no rate-control encoder)");
                    else if(cc.rate_mode=="forward") send_line(t);
                    else log.log("control: videorateadapt ignored mode=",cc.rate_mode);
                } else send_line(t);
            }
        }
    }
    DWORD rc=1; GetExitCodeProcess(pi.hProcess,&rc);
    if(wr!=nullptr) CloseHandle(wr);
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    return (int)rc;
}
#endif

static bool contains_decodable_video_start(const fs::path& input, size_t max_bytes) {
    std::ifstream f(input, std::ios::binary);
    if(!f) return false;
    std::vector<unsigned char> data(max_bytes);
    f.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(data.size()));
    data.resize(static_cast<size_t>(f.gcount()));
    bool mpeg2_sequence=false, mpeg2_picture=false;
    bool h264_sps=false, h264_idr=false;
    bool hevc_sps=false, hevc_irap=false;
    for(size_t i=0; i+4<data.size(); ++i) {
        size_t nal=i;
        if(data[i]==0 && data[i+1]==0 && data[i+2]==1) nal=i+3;
        else if(i+5<data.size() && data[i]==0 && data[i+1]==0 && data[i+2]==0 && data[i+3]==1) nal=i+4;
        else continue;
        const unsigned char b=data[nal];
        if(b==0xB3) mpeg2_sequence=true;
        else if(b==0x00) mpeg2_picture=true;
        const unsigned char h264_type=b & 0x1f;
        if(h264_type==7) h264_sps=true;
        else if(h264_type==5) h264_idr=true;
        const unsigned char hevc_type=(b >> 1) & 0x3f;
        if(hevc_type==33) hevc_sps=true;
        else if(hevc_type>=16 && hevc_type<=23) hevc_irap=true;
        if((mpeg2_sequence && mpeg2_picture) || (h264_sps && h264_idr) || (hevc_sps && hevc_irap)) return true;
    }
    return false;
}

static void wait_for_active_video(const Ini& ini, const fs::path& input, Logger& log) {
    if(!ini.get_bool("active_file","video_ready_gate",true)) return;
    const auto timeout=std::max<long long>(0,ini.get_ll("active_file","video_ready_timeout_ms",2500));
    const auto poll=std::max<long long>(10,ini.get_ll("active_file","video_ready_poll_ms",25));
    // Scan what is already available, up to this ceiling. This does not wait for
    // the file to reach the ceiling; it lets late PMT/video starts be detected
    // without imposing a fixed probe delay on normally formed live streams.
    const auto scan=static_cast<size_t>(std::max<long long>(188,ini.get_ll("active_file","video_ready_scan_bytes",5000000)));
    const auto started=std::chrono::steady_clock::now();
    do {
        if(contains_decodable_video_start(input,scan)) {
            const auto ms=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-started).count();
            log.log("active-file video-ready after ms=",ms," scan_bytes=",scan);
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(poll));
    } while(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-started).count()<timeout);
    log.log("WARNING active-file video-ready timeout ms=",timeout,"; launching FFmpeg fallback probe");
}

int main(int argc,char** argv){
    auto self=executable_path(); auto dir=self.parent_path(); auto platform=platform_info();
    if(argc>=2 && std::string(argv[1])=="--mim-version") {
        std::cout << "SageTV FFmpeg MIM " << MIM_VERSION << " (" << platform.name << ")\n";
        return 0;
    }
    if(argc>=2 && std::string(argv[1])=="--mim-capabilities") {
        std::cout << "{\"mimVersion\":\"" << MIM_VERSION
                  << "\",\"dvdStreamTransform\":true,\"dvdVideoDemux\":true}\n";
        return 0;
    }
    bool dry_run = argc>=2 && std::string(argv[1])=="--mim-dry-run";
    bool status_query = argc>=2 && std::string(argv[1])=="--mim-status";
    fs::path ini_path=dir/"ffmpeg.real.ini";
    if(const char* e=std::getenv("SAGETV_FFMPEG_MIM_INI")) ini_path=e;
    Ini ini; if(!ini.load(ini_path)){ std::cerr<<"SageTV FFmpeg MIM: cannot load "<<ini_path<<"\n"; return 78; }
    auto forced=lower(trim(ini.get("platform","force_platform","auto")));
    if(forced!="auto" && !forced.empty()) platform.name=forced;
    if(status_query) {
        print_mim_status(dir,ini,platform.name);
        return 0;
    }
    std::string log_name=trim(ini.get("logging","file","./ffmpeg.real.log"));
    // v0.4.0 and earlier shipped SageTVFFmpegMIM.log as the default. Treat that
    // exact legacy default as migratable so an older INI does not preserve the
    // obsolete filename after deploying v0.4.1. Other custom filenames remain
    // user-controlled.
    if(log_name.empty() || ieq(log_name,"SageTVFFmpegMIM.log") || ieq(log_name,"./SageTVFFmpegMIM.log"))
        log_name="./ffmpeg.real.log";
    fs::path log_path=log_name; if(log_path.is_relative())log_path=dir/log_path;
    Logger log; log.init(log_path,ini.get_bool("logging","enabled",true));
    log.log("mim-start version=",MIM_VERSION," platform=",platform.name);
    if(!ini.get_bool("general","enabled",true)){ std::cerr<<"SageTV FFmpeg MIM is disabled in INI\n"; return 78; }
    auto real=resolve_config_path(dir,ini,platform,false), ffprobe=resolve_config_path(dir,ini,platform,true);
    if(!native_file_exists(real)){ std::cerr<<"SageTV FFmpeg MIM: real FFmpeg not found: "<<real<<"\n"; log.log("ERROR real FFmpeg missing ",real.string()); return 127; }
    std::vector<std::string> orig; for(int i=dry_run?2:1;i<argc;++i)orig.emplace_back(argv[i]);
    // Administrators and container health checks commonly use GNU-style long
    // management flags, while FFmpeg itself accepts the historical single-dash
    // spelling. Normalize only the two unambiguous aliases before passthrough.
    for(auto& arg:orig) {
        if(arg=="--version") arg="-version";
        else if(arg=="--help") arg="-help";
    }
    if(ini.get_bool("logging","log_original_command",true))log.log("original: ",join_display(self,orig));
    bool stdinctrl=false,active=false; std::optional<fs::path> input; std::string backend;
    auto final_args=rewrite_args(ini,platform,dir,real,ffprobe,orig,log,stdinctrl,active,input,backend);
    if(ini.get_bool("logging","log_final_command",true))log.log("final backend=",backend," cmd=",join_display(real,final_args));
    if(dry_run) {
        std::cout << "backend=" << backend << "\n" << join_display(real,final_args) << "\n";
        return 0;
    }

    const auto started_ms=std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    const long long mim_pid=current_process_id();
    const auto encoder=get_opt_value(final_args,{"-vcodec","-c:v","-codec:v"}).value_or("");
    const auto output_format=get_output_opt_value(final_args,{"-f"}).value_or("");
    const bool status_hardware_decode=has_flag(final_args,"-hwaccel");
    const fs::path status_dir=mim_status_directory(dir,ini);
    const fs::path active_status=status_dir/("job-"+std::to_string(mim_pid)+".json");
    const auto running_status=mim_status_record(platform.name,mim_pid,"running",backend,encoder,
        status_hardware_decode,active,input,output_format,started_ms);
    atomic_write_text(active_status,running_status);
    atomic_write_text(status_dir/"last.json",running_status);
    if(is_encode_backend(backend)) atomic_write_text(status_dir/"last-transcode.json",running_status);

    if(active && input) wait_for_active_video(ini,*input,log);

    ControlConfig cc; cc.enabled=stdinctrl&&ini.get_bool("stdinctrl","enabled",true); cc.case_insensitive=ini.get_bool("stdinctrl","case_insensitive",true); cc.rate_enabled=has_flag(final_args,"-sagetvratectrl"); cc.rate_mode=lower(ini.get("stdinctrl","videorateadapt_mode","forward")); cc.inactive_action=lower(ini.get("active_file","inactivefile_action","terminate_child")); cc.active=active; cc.isolate_child_process=ini.get_bool("safety","isolate_child_process",true); cc.terminate_grace_ms=ini.get_ll("safety","terminate_grace_ms",2000);
    for(auto s:split_csv(ini.get("stdinctrl","stop_commands","STOP,QUIT,Q")))cc.stop.insert(cc.case_insensitive?lower(s):s);
#ifdef _WIN32
    int rc=run_child_windows(real,final_args,cc,log);
#else
    int rc=run_child_posix(real,final_args,cc,log,ini.get_bool("logging","log_ffmpeg_stderr",true));
#endif
    log.log("child exit rc=",rc);
    const auto stopped_status=mim_status_record(platform.name,mim_pid,"stopped",backend,
        encoder,status_hardware_decode,active,input,output_format,started_ms,rc);
    atomic_write_text(status_dir/"last.json",stopped_status);
    if(is_encode_backend(backend)) atomic_write_text(status_dir/"last-transcode.json",stopped_status);
    std::error_code status_remove_error;
    fs::remove(active_status,status_remove_error);
    // A failed transcoder must be contained as a playback EOF, never promoted
    // into a MiniPlayer/server process failure. SageTV requested -stdinctrl on
    // realtime transcoder jobs, so limit this normalization to that contract.
    if(rc!=0 && stdinctrl && ini.get_bool("safety","clean_exit_on_ffmpeg_failure",true)) {
        log.log("safety: contained ffmpeg failure rc=",rc," -> MIM exit rc=0 (MiniPlayer receives EOF/no video)");
        return 0;
    }
    return rc;
}
