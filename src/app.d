import std.stdio;

import szip;

void main(string[] argv)
{
    int bits = 256;
    
    if ((argv.length != 4) || ((argv[1] != "-z") && (argv[1] != "-x")))
    {
        writeln("Usage: szip -z sourceDirOrFileName outputFilename(.szip)");
        writeln("       szip -x zipFilename(.szip) outputPath");
        
        return;
    }
    
    if (argv[1] == "-z") {
        szip.zip(argv[2], argv[3]);
    } else {
        szip.unzip(argv[2], argv[3]);
    }
}
