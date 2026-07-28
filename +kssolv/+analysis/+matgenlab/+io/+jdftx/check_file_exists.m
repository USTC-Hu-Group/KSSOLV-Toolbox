function wrapped = check_file_exists(func)
%CHECK_FILE_EXISTS Wrap a one-file parser with existence validation.
arguments
    func (1, 1) function_handle
end
wrapped = @invoke;
    function value = invoke(filename)
        if ~isfile(filename)
            error("KSSOLV:Matgenlab:JDFTX:MissingFile", ...
                "'%s' file does not exist.", string(filename));
        end
        value = func(filename);
    end
end
