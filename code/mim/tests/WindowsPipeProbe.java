import java.io.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
public final class WindowsPipeProbe {
    static Thread drain(final InputStream in, final ByteArrayOutputStream out) {
        Thread t=new Thread(new Runnable(){public void run(){try {
            byte[] b=new byte[8192];int n;
            while((n=in.read(b))!=-1){if(out.size()+n>2097152)throw new IOException("Output bound");out.write(b,0,n);}
        }catch(IOException stopped){}}});t.setDaemon(true);t.start();return t;
    }
    public static void main(String[] args)throws Exception {
        boolean all=true;StringBuilder rows=new StringBuilder();
        for(final int size:new int[]{0,1,1024,1025,18432,131072,1048576}) {
            final boolean duplex=size==1048576;
            final byte[] data=new byte[size];for(int i=0;i<size;i++)data[i]=(byte)((i*17+3)%256);
            List<String> cmd=new ArrayList<String>(Arrays.asList(args[0],"-f","mpeg","-i","pipe:0","-f","null","-"));
            if(duplex)cmd.add("--duplex-probe");
            long start=System.nanoTime();final Process p=new ProcessBuilder(cmd).start();
            ByteArrayOutputStream out=new ByteArrayOutputStream(),err=new ByteArrayOutputStream();
            Thread output=drain(p.getInputStream(),out),error=drain(p.getErrorStream(),err);
            Thread input=new Thread(new Runnable(){public void run(){try{p.getOutputStream().write(data);p.getOutputStream().close();}catch(IOException stopped){}}});
            input.setDaemon(true);input.start();
            boolean ended=p.waitFor(duplex?8:15,TimeUnit.SECONDS);
            if(!ended)p.destroyForcibly();p.waitFor(3,TimeUnit.SECONDS);input.join(1500);output.join(1500);error.join(1500);
            long ms=(System.nanoTime()-start)/1000000;
            boolean exact=Arrays.equals(data,out.toByteArray());
            boolean pass=ended&&p.exitValue()==0&&exact&&(!duplex||err.size()==17*65536);
            if(rows.length()>0)rows.append(',');
            rows.append("{\"bytes\":"+size+",\"outputBytes\":"+out.size()+",\"diagnosticBytes\":"+err.size()+",\"elapsedMs\":"+ms+",\"ended\":"+ended+",\"exact\":"+exact+",\"passed\":"+pass+"}");all&=pass;
        }
        System.out.println("{\"java\":\""+System.getProperty("java.version")+"\",\"rows\":["+rows+"],\"passed\":"+all+"}");
    }
}
