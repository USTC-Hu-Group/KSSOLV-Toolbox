function path=config_path(name)
%CONFIG_PATH Resolve a bundled compatibility configuration.
folder=fileparts(fileparts(mfilename("fullpath")));
path=fullfile(folder,"data",string(name));
end
