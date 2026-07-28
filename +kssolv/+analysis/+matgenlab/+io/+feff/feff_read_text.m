function text=feff_read_text(filename)
%#ok<*MSNU>
%FEFF_READ_TEXT Read plain or gzip-compressed FEFF text.
filename=string(filename);
if endsWith(lower(filename),".gz")
 temp=string(tempname);mkdir(temp);cleanup=onCleanup(@()rmdir(temp,"s")); %#ok<NASGU>
 files=gunzip(filename,temp);text=fileread(files{1});
else
 text=fileread(filename);
end
end
