classdef NetcdfReader < handle
    properties (SetAccess=private)
        path string
        rootgrp struct
        ngroups double
    end
    methods
        function obj=NetcdfReader(path)
            obj.path=string(path);
            try,obj.rootgrp=ncinfo(path);catch exc,error("KSSOLV:Matgenlab:Abinit:NetcdfReader","In file %s: %s",path,exc.message);end %#ok<NOCOMMA>
            obj.ngroups=1+obj.countGroups(obj.rootgrp);
        end
        function close(~)
            % MATLAB's high-level NetCDF API opens and closes each read.
        end
        function value=walk_tree(obj,top)
            if nargin<2||isempty(top),top=obj.rootgrp;end
            value={top};for i=1:numel(top.Groups),value=[value,obj.walk_tree(top.Groups(i))];end %#ok<AGROW>
        end
        function print_tree(obj)
            groups=obj.walk_tree();for i=1:numel(groups),fprintf("%s\n",groups{i}.Name);end
        end
        function value=read_dimvalue(obj,dimname,varargin)
            [path,hasDefault,default]=obj.readOptions(varargin{:}); %#ok<PROP>
            info=obj.groupInfo(path);idx=find(strcmp({info.Dimensions.Name},char(string(dimname))),1); %#ok<PROP>
            if isempty(idx)
                if hasDefault,value=default;return;end
                error("KSSOLV:Matgenlab:Abinit:NetcdfReader","Dimension %s not found in %s.",dimname,obj.path);
            end
            value=info.Dimensions(idx).Length;
        end
        function value=read_varnames(obj,varargin)
            path="/";if ~isempty(varargin),path=varargin{1};end %#ok<PROP>
            info=obj.groupInfo(path);value=string({info.Variables.Name}); %#ok<PROP>
        end
        function value=read_value(obj,varname,varargin)
            [path,hasDefault,default,cmode]=obj.readOptions(varargin{:}); %#ok<PROP>
            fullName=obj.fullVariable(path,varname); %#ok<PROP>
            try,value=ncread(obj.path,fullName);catch %#ok<NOCOMMA>
                if hasDefault,value=default;return;end
                error("KSSOLV:Matgenlab:Abinit:NetcdfReader","Variable %s not found in %s.",varname,obj.path);
            end
            if cmode=="c"
                if size(value,1)~=2,error("KSSOLV:Matgenlab:Abinit:ComplexShape","Complex storage dimension must be two.");end
                value=squeeze(value(1,:,:,:,:,:,:))+1i*squeeze(value(2,:,:,:,:,:,:));
            end
            if isscalar(value),value=double(value);end
        end
        function value=read_variable(obj,varname,varargin)
            path="/";if ~isempty(varargin),path=varargin{1};end %#ok<PROP>
            info=obj.groupInfo(path);idx=find(strcmp({info.Variables.Name},char(string(varname))),1); %#ok<PROP>
            if isempty(idx),error("KSSOLV:Matgenlab:Abinit:NetcdfReader","Variable %s not found.",varname);end
            value=info.Variables(idx);value.Value=obj.read_value(varname,"path",path); %#ok<PROP>
        end
        function value=read_keys(obj,keys,varargin)
            path="/";if ~isempty(varargin),path=varargin{end};end %#ok<PROP>
            value=struct();
            for key=reshape(string(keys),1,[])
                try,value.(char(key))=obj.read_value(key,"path",path); %#ok<NOCOMMA,PROP>
                catch
                    try,value.(char(key))=obj.read_dimvalue(key,"path",path); %#ok<NOCOMMA,PROP>
                    catch,value.(char(key))=[];end
                end
            end
        end
    end
    methods(Access=private)
        function n=countGroups(obj,info)
            n=numel(info.Groups);for i=1:numel(info.Groups),n=n+obj.countGroups(info.Groups(i));end
        end
        function info=groupInfo(obj,path)
            path=string(path);info=obj.rootgrp;if path=="/",return,end
            parts=split(strip(path,"/"),"/");
            for part=reshape(parts,1,[])
                idx=find(endsWith(string({info.Groups.Name}),"/"+part)|string({info.Groups.Name})==part,1);
                if isempty(idx),error("KSSOLV:Matgenlab:Abinit:NetcdfReader","Group %s not found.",path);end
                info=info.Groups(idx);
            end
        end
        function name=fullVariable(~,path,varname)
            if string(path)=="/",name=char(string(varname));else,name=char(strip(string(path),"right","/")+"/"+string(varname));end
        end
        function [path,hasDefault,default,cmode]=readOptions(~,varargin)
            path="/";hasDefault=false;default=[];cmode="";
            for i=1:2:numel(varargin)
                switch string(varargin{i})
                    case "path",path=varargin{i+1};
                    case "default",hasDefault=true;default=varargin{i+1};
                    case "cmode",cmode=string(varargin{i+1});
                end
            end
        end
    end
end
