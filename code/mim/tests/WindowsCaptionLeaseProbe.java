import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.concurrent.*;

/** Java8/Windows forced-stop proof of the actual native caption claim. */
public final class WindowsCaptionLeaseProbe {
    public static void main(String[] args) throws Exception {
        if(args.length!=2)throw new IllegalArgumentException("Owned executable and scratch parent required");
        Path dir=Files.createTempDirectory(Paths.get(args[1]),"caption-lease-");
        Path pool=Files.createDirectory(dir.resolve("caption-pool"));
        Path sentinel=dir.resolve("unrelated.txt");Files.write(sentinel,new byte[]{42});
        Files.write(pool.resolve("available-31920-0123456789abcdef0123456789abcdef.slot"),new byte[]{1});
        Process child=null;ExecutorService reader=Executors.newSingleThreadExecutor();
        boolean visible=false,readable=false,removed=false,preserved=false;
        try {
            child=new ProcessBuilder(args[0],dir.toString()).redirectError(ProcessBuilder.Redirect.INHERIT).start();
            final Process owner=child;
            String line=reader.submit(()->new BufferedReader(new InputStreamReader(owner.getInputStream(),StandardCharsets.UTF_8)).readLine()).get(10,TimeUnit.SECONDS);
            if(!"READY".equals(line))throw new IOException("Native claim owner did not become ready");
            Path claim;
            try(DirectoryStream<Path> entries=Files.newDirectoryStream(pool,"job-*.slot")) {
                java.util.Iterator<Path> iterator=entries.iterator();
                if(!iterator.hasNext())throw new IOException("Missing live claim");
                claim=iterator.next();if(iterator.hasNext())throw new IOException("Unexpected second claim");
            }
            visible=Files.isRegularFile(claim);readable=Files.readAllBytes(claim).length==1;
            child.destroyForcibly();
            if(!child.waitFor(10,TimeUnit.SECONDS))throw new IOException("Owned native probe did not stop");
            long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(3);
            while(Files.exists(claim)&&System.nanoTime()<deadline)Thread.sleep(25);
            removed=!Files.exists(claim);preserved=Files.readAllBytes(sentinel)[0]==42;
        } finally {
            if(child!=null&&child.isAlive()){child.destroyForcibly();child.waitFor(10,TimeUnit.SECONDS);}
            reader.shutdownNow();
        }
        boolean passed=visible&&readable&&removed&&preserved;
        System.out.println("{\"passed\":"+passed+",\"liveClaimVisible\":"+visible+",\"liveClaimReadable\":"+readable+",\"removedAfterForcedStop\":"+removed+",\"unrelatedPreserved\":"+preserved+"}");
        if(!passed)System.exit(1);
    }
}
