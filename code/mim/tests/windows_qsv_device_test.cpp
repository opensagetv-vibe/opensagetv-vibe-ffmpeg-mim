#define main mim_entrypoint_for_test
#include "../sagetv_ffmpeg_mim.cpp"
#undef main
#include <cassert>
int main() {
    Ini ini;
    const std::vector<std::string> original={"-i","fixture.ts","-c:v","h264_qsv","-f","mpegts","-"};
    auto args=original;
    assert(ensure_windows_qsv_device(args,ini,true));
    assert(args[0]=="-init_hw_device" && args[1]=="qsv=vibe_win_qsv:hw,child_device_type=d3d11va,child_device=0");
    assert(!ensure_windows_qsv_device(args,ini,true)); // idempotent
    args=original;args.insert(args.end(),{"-map","0:v:0","-c:v","copy","-f","mpegts","pipe:1"});
    assert(ensure_windows_qsv_device(args,ini,true)); // original-video caption tap does not hide first encoder
    args=original;assert(!ensure_windows_qsv_device(args,ini,false) && args==original);
    for(const auto& flag:{"-init_hw_device","-qsv_device","-filter_hw_device","-hwaccel"}) {
        args=original;args.insert(args.begin(),{flag,"caller"});const auto before=args;
        assert(!ensure_windows_qsv_device(args,ini,true) && args==before);
    }
    for(const auto& codec:{"copy","libx264","hevc_qsv","h264_nvenc"}) {
        args=original;args[3]=codec;const auto before=args;
        assert(!ensure_windows_qsv_device(args,ini,true) && args==before);
    }
    std::cout<<"PASS Windows QSV device scope/idempotency/caller/hardware/codec/Linux guards\n";
}
