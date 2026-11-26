#include <cstdio>
#include <cstring>
#include <io.h>
#include <fcntl.h>
#include <windows.h>
int main(int argc,char**argv) {
    _setmode(_fileno(stdin),_O_BINARY);
    _setmode(_fileno(stdout),_O_BINARY);
    _setmode(_fileno(stderr),_O_BINARY);
    bool duplex=false;
    for(int i=1;i<argc;i++) {
        if(!strcmp(argv[i],"--duplex-probe")) duplex=true;
        if(!strcmp(argv[i],"--wait-probe")) {Sleep(30000);return 0;}
    }
    if(duplex) {
        char diagnostics[65536];memset(diagnostics,'D',sizeof diagnostics);
        for(int i=0;i<17;i++) if(fwrite(diagnostics,1,sizeof diagnostics,stderr)!=sizeof diagnostics)return 4;
        fflush(stderr);
    }
    unsigned char bytes[8192];size_t count;
    while((count=fread(bytes,1,sizeof bytes,stdin))!=0)
        if(fwrite(bytes,1,count,stdout)!=count)return 5;
    return ferror(stdin)?6:0;
}
