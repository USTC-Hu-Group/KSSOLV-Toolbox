function path=data_path(name)
%DATA_PATH Resolve bundled frozen prototype data.
folder=fileparts(fileparts(mfilename("fullpath")));
path=fullfile(folder,"data",string(name));
end
