function text = read_text(filename)
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
%READ_TEXT Read plain or gzip-compressed LOBSTER text.
path = char(string(filename));
if ~isfile(path)
    error("KSSOLV:Matgenlab:Lobster:MissingFile", ...
        "LOBSTER file '%s' does not exist.", path);
end
if endsWith(lower(path), ".gz")
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, "s"));
    files = gunzip(path, folder);
    path = files{1};
end
fileId = fopen(path, "rt", "n", "UTF-8");
if fileId < 0
    error("KSSOLV:Matgenlab:Lobster:Open", ...
        "Unable to open LOBSTER file '%s'.", path);
end
closeFile = onCleanup(@() fclose(fileId));
text = fread(fileId, Inf, "*char").';
if isempty(text)
    error("KSSOLV:Matgenlab:Lobster:EmptyFile", ...
        "LOBSTER file '%s' is empty.", path);
end
end
