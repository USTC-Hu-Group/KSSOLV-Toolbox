function wrapped=add_fig_kwargs(functionHandle)
%ADD_FIG_KWARGS Decorate a figure factory with common post-processing.
if ~isa(functionHandle,"function_handle")
    error("KSSOLV:Matgenlab:Plotting:FunctionHandle", ...
        "add_fig_kwargs expects a function handle.");
end
wrapped=@invoke;
    function figureHandle=invoke(varargin)
        options=struct("title","","size_kwargs",[], ...
            "show",true,"savefig","","tight_layout",false, ...
            "ax_grid",[],"ax_annotate",false,"fig_close",false);
        [options,forward]=splitOptions(options,varargin{:});
        figureHandle=functionHandle(forward{:});
        if isempty(figureHandle),return,end
        if strlength(string(options.title))>0
            sgtitle(figureHandle,options.title);
        end
        if ~isempty(options.size_kwargs)
            sizeValue=options.size_kwargs;
            if isstruct(sizeValue)
                figureHandle.Units="inches";
                position=figureHandle.Position;
                position(3:4)=[sizeValue.w,sizeValue.h];
                figureHandle.Position=position;
            end
        end
        if ~isempty(options.ax_grid)
            for axesHandle=findall(figureHandle,"Type","axes").'
                grid(axesHandle,logical(options.ax_grid));
            end
        end
        if options.ax_annotate
            axesValues=flip(findall(figureHandle,"Type","axes"));
            for index=1:numel(axesValues)
                text(axesValues(index),.05,.95, ...
                    "("+char('a'+mod(index-1,26))+")", ...
                    "Units","normalized");
            end
        end
        if options.tight_layout
            drawnow;
        end
        if strlength(string(options.savefig))>0
            exportgraphics(figureHandle,options.savefig);
        end
        if options.show,figureHandle.Visible="on";drawnow;end
        if options.fig_close,close(figureHandle);end
    end
end
function [options,forward]=splitOptions(options,varargin)
names=fieldnames(options);forward=cell(1,0);
for index=1:2:numel(varargin)
    if index==numel(varargin)
        forward{end+1}=varargin{index}; %#ok<AGROW>
        break
    end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if isempty(match)
        forward(end+1:end+2)=varargin(index:index+1);
    else
        options.(names{match})=varargin{index+1};
    end
end
end
