function text=read_text(filename)
%READ_TEXT Read plain or gzip-compressed text.
filename=char(filename);
if endsWith(filename,'.gz')
    td=tempname; mkdir(td); cleanup=onCleanup(@()rmdir(td,'s'));
    files=gunzip(filename,td); text=fileread(files{1});
else
    text=fileread(filename);
end
end
