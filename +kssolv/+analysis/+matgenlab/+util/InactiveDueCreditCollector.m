classdef InactiveDueCreditCollector
    %INACTIVEDUECREDITCOLLECTOR Safe citation collector when DueCredit is absent.
    properties (Constant)
        active=false
    end
    methods
        function decorator=dcite(~,varargin)
            decorator=@(functionHandle)functionHandle;
        end
        function varargout=activate(~,varargin)
            varargout=cell(1,nargout);
        end
        function varargout=add(~,varargin)
            varargout=cell(1,nargout);
        end
        function varargout=cite(~,varargin)
            varargout=cell(1,nargout);
        end
        function varargout=dump(~,varargin)
            varargout=cell(1,nargout);
        end
        function varargout=load(~,varargin)
            varargout=cell(1,nargout);
        end
        function text=char(~)
            text='InactiveDueCreditCollector()';
        end
        function text=string(obj)
            text=string(char(obj));
        end
    end
end
