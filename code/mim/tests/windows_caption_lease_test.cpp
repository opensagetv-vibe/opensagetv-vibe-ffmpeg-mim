#define main mim_entrypoint_for_test
#include "../sagetv_ffmpeg_mim.cpp"
#undef main

// Actual claim implementation, not a simulated marker. Java8 forcibly stops
// this owned process after checking that its claim is visible/readable.
int main(int argc,char** argv) {
    if(argc!=2)return 2;
    Ini ini;Logger log;
    auto slot=claim_caption_side_channel(ini,fs::path(argv[1]),GetCurrentProcessId(),log);
    if(!slot.claimed())return 3;
    std::cout<<"READY\n"<<std::flush;
    Sleep(30000);
    release_caption_side_channel(slot,log);
    return 0;
}
