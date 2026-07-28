function value=read_gzip_json(path)
%READ_GZIP_JSON Decode a compressed JSON file without Python.
folder=tempname;mkdir(folder);
cleanup=onCleanup(@()rmdir(folder,"s"));
files=gunzip(path,folder);
value=jsondecode(fileread(files{1}));
clear cleanup
end
