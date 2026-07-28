classdef InputFile < kssolv.analysis.matgenlab.util.MSONable
    %INPUTFILE Standard interface for one calculation input file.
    properties (Access=protected)
        raw_contents (1,1) string = ""
    end
    methods
        function obj=InputFile(contents)
            if nargin>0,obj.raw_contents=string(contents);end
        end
        function text=get_str(obj)
            if strlength(obj.raw_contents)==0
                error("KSSOLV:Matgenlab:InputFile:AbstractGetStr", ...
                    "get_str must be implemented by the concrete input file.");
            end
            text=obj.raw_contents;
        end
        function text=getStr(obj),text=obj.get_str();end
        function text=char(obj),text=char(obj.get_str());end
        function write_file(obj,filename)
            fileId=fopen(filename,"wt","n","UTF-8");
            if fileId<0
                error("KSSOLV:Matgenlab:InputFile:Open", ...
                    "Unable to open '%s' for writing.",string(filename));
            end
            cleanup=onCleanup(@()fclose(fileId));
            fprintf(fileId,"%s",obj.get_str());
        end
        function writeFile(obj,filename),obj.write_file(filename);end
        function data=asDict(obj)
            data=kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.core","InputFile", ...
                struct("contents",obj.raw_contents));
        end
        function data=as_dict(obj),data=obj.asDict();end
    end
    methods (Static)
        function obj=from_str(contents)
            obj=kssolv.analysis.matgenlab.io.InputFile(contents);
        end
        function obj=fromStr(contents)
            obj=kssolv.analysis.matgenlab.io.InputFile.from_str(contents);
        end
        function obj=from_file(path)
            fileId=fopen(path,"rt","n","UTF-8");
            if fileId<0
                error("KSSOLV:Matgenlab:InputFile:MissingFile", ...
                    "Unable to open input file '%s'.",string(path));
            end
            cleanup=onCleanup(@()fclose(fileId));
            contents=fread(fileId,Inf,"*char").';
            obj=kssolv.analysis.matgenlab.io.InputFile. ...
                from_str(contents);
        end
        function obj=fromFile(path)
            obj=kssolv.analysis.matgenlab.io.InputFile.from_file(path);
        end
        function obj=fromDict(data)
            if isfield(data,"contents"),contents=data.contents;
            else,contents="";end
            obj=kssolv.analysis.matgenlab.io.InputFile(contents);
        end
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.io.InputFile.fromDict(data);
        end
    end
end
