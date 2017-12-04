module szip;

import std.file;
import std.path;
import std.algorithm;
import std.exception;
import std.bitmanip;
import std.zlib;
import std.string;

const ubyte[] magic = [12, 29];

void zip(string sourceDirOrFileName, string outputFilename) {
    enforce(std.file.exists(sourceDirOrFileName));
    enforce(outputFilename != string.init);

    ubyte[] buffer;

    if (std.file.isFile(sourceDirOrFileName)) {
        put!"file"(sourceDirOrFileName, buffer);
    } else {
        readFile(sourceDirOrFileName, string.init, buffer);
    }

    if (std.file.exists(outputFilename)) std.file.remove(outputFilename);

    std.file.write(outputFilename, magic);
    std.file.append(outputFilename, compress(buffer));
}

void unzip(string szipFilename, string outputPath) {
    enforce(std.file.exists(szipFilename));

    ubyte[] buffer = cast(ubyte[])std.file.read(szipFilename);
    enforce(buffer[0 .. 2] == magic, "Not the szip file format.");
    buffer = cast(ubyte[])uncompress(buffer[2 .. $]);

    if (!std.file.exists(outputPath))	std.file.mkdirRecurse(outputPath);

    if (buffer.length == 0) {
        return;
    }
    
    string dir = outputPath;
    while (buffer.length > 0) {
        ubyte type = buffer[0];
        ushort len = buffer.peek!ushort(1);
        string name = cast(string)buffer[3 .. 3 + len];
        if (type == 0x01) {
            dir = _buildPath(outputPath, name);
            if (!std.file.exists(dir))	std.file.mkdirRecurse(dir);
            buffer = buffer[3 + len .. $];
        } else {
            string filename = _buildPath(dir, name);
            uint file_len = buffer.peek!uint(3 + len);
            ubyte[] content = buffer[3 + len + 4 .. 3 + len + 4 + file_len];
            std.file.write(filename, content);
            buffer = buffer[3 + len + 4 + file_len .. $];
        }
    }
}

private:

string _buildPath(string rootDir, string path) {
    string full = std.path.buildPath(rootDir, path);
    version(Windows) {
        return full.replace("\\", "/");
    } else {
        return full;
    }
}

void readFile(string dir, string rootDir, ref ubyte[] buffer) {
    foreach (DirEntry e; dirEntries(dir, SpanMode.shallow).filter!(a => a.isFile)) {
        put!"file"(e.name, buffer);
    }

    foreach (DirEntry e; dirEntries(dir, SpanMode.shallow).filter!(a => a.isDir)) {
        string t = _buildPath(rootDir, std.path.baseName(e.name));
        put!"dir"(t, buffer);
        readFile(e.name, t, buffer);
    }
}

void put(string T = "dir")(string name, ref ubyte[] buffer) if (T == "dir" || T == "file") {
    buffer ~= (T == "dir") ? 0x01 : 0x02;
    buffer ~= [0x00, 0x00];
    string t = (T == "file") ? std.path.baseName(name) : name;
    buffer.write!ushort(cast(ushort)t.length, buffer.length - 2);
    buffer ~= cast(ubyte[])t;
    
    if (T == "file") {
        ubyte[] content = cast(ubyte[])std.file.read(name);
        buffer ~= [0x00, 0x00, 0x00, 0x00];
        buffer.write!uint(cast(uint)content.length, buffer.length - 4);
        buffer ~= content;
    }
}

unittest
{
    szip.zip("/Users/shove/Desktop/Folder1", "/Users/shove/Desktop/archives.szip");
    szip.unzip("/Users/shove/Desktop/archives.szip", "/Users/shove/Desktop/Folder2");
}

unittest
{
    szip.zip("/Users/shove/Desktop/file1.txt", "/Users/shove/Desktop/archives.szip");
    szip.unzip("/Users/shove/Desktop/archives.szip", "/Users/shove/Desktop/Folder2");
}

/*
.szip file format:

type: a byte, 1:dir, 2:file
dir:  len(ushort) + long dir name
file: len(ushort) + short file name + len(uint) + file content

szip archives:
magic + file1 + ... + fileN + dir + file1 + ... + fileN + ...
*/