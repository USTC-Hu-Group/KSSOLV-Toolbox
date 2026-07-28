function text = read_text(filename)
%READ_TEXT Read plain or gzip-compressed Q-Chem text without Python.
filename = char(filename);
if endsWith(lower(filename), ".gz")
    temporary = tempname;
    mkdir(temporary);
    cleanup = onCleanup(@() rmdir(temporary, "s"));
    files = gunzip(filename, temporary);
    target = files{1};
else
    target = filename;
end
fid = fopen(target, "r", "n", "ISO-8859-1");
if fid < 0
    error("KSSOLV:Matgenlab:QChem:Read", "Cannot open '%s'.", filename);
end
fileCleanup = onCleanup(@() fclose(fid));
text = fread(fid, "*char").';
clear fileCleanup cleanup
end
