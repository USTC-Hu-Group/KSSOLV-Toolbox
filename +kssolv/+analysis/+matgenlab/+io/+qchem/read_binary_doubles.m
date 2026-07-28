function values = read_binary_doubles(filename)
%READ_BINARY_DOUBLES Read native Q-Chem scratch doubles, including gzip.
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
fid = fopen(target, "r", "ieee-le");
if fid < 0, error("KSSOLV:Matgenlab:QChem:Read", "Cannot open '%s'.", filename); end
fileCleanup = onCleanup(@() fclose(fid));
values = fread(fid, Inf, "*double");
clear fileCleanup cleanup
end
