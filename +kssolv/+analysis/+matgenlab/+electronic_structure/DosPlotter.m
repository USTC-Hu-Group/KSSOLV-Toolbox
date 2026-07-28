classdef DosPlotter < handle
    %DOSPLOTTER Collect and draw electronic densities of states.
    properties
        zero_at_efermi (1,1) logical=true
        stack (1,1) logical=false
        sigma = []
    end
    properties (SetAccess=private)
        doses
        norm_val (1,1) logical=true
    end
    methods
        function obj=DosPlotter(zeroAtEfermi,stack,sigma)
            if nargin>=1&&~isempty(zeroAtEfermi),obj.zero_at_efermi=logical(zeroAtEfermi);end
            if nargin>=2&&~isempty(stack),obj.stack=logical(stack);end
            if nargin>=3,obj.sigma=sigma;end
            obj.doses=containers.Map("KeyType","char","ValueType","any");
        end
        function add_dos(obj,label,dos)
            if isempty(dos.norm_vol),obj.norm_val=false;end
            energies=dos.energies;if obj.zero_at_efermi,energies=energies-dos.efermi;end
            if isempty(obj.sigma),densities=dos.densities;
            else,densities=dos.get_smeared_densities(obj.sigma);end
            obj.doses(char(string(label)))=struct(energies=energies, ...
                densities=densities,efermi=dos.efermi);
        end
        function add_dos_dict(obj,dosDict,keySortFunc)
            if nargin<3,keySortFunc=[];end
            source=asMap(dosDict);keys=source.keys;
            if ~isempty(keySortFunc)
                [~,order]=sort(cellfun(keySortFunc,keys));keys=keys(order);
            end
            for ii=1:numel(keys),obj.add_dos(keys{ii},source(keys{ii}));end
        end
        function value=get_dos_dict(obj),value=obj.doses;end
        function ax=get_plot(obj,xlim,ylim,invertAxes,betaDashed)
            if nargin<2,xlim=[];end
            if nargin<3,ylim=[];end
            if nargin<4||isempty(invertAxes),invertAxes=false;end
            if nargin<5||isempty(betaDashed),betaDashed=false;end
            figureHandle=figure("Visible","off");ax=axes(figureHandle);hold(ax,"on");
            keys=obj.doses.keys;colors=lines(max(3,numel(keys)));
            cumulative=struct();
            for ii=1:numel(keys)
                data=obj.doses(keys{ii});names=fieldnames(data.densities);
                for jj=1:numel(names)
                    field=names{jj};density=data.densities.(field);
                    if obj.stack
                        if ~isfield(cumulative,field),cumulative.(field)=zeros(size(density));end
                        cumulative.(field)=cumulative.(field)+density;density=cumulative.(field);
                    end
                    if strcmp(field,"down"),density=-density;end
                    if invertAxes,x=density;y=data.energies;else,x=data.energies;y=density;end
                    style="-";if betaDashed&&strcmp(field,"down"),style="--";end
                    if obj.stack
                        area(ax,x,y,"FaceColor",colors(ii,:),"DisplayName",keys{ii});
                    else
                        plot(ax,x,y,style,"Color",colors(ii,:),"LineWidth",2, ...
                            "DisplayName",keys{ii});
                    end
                end
            end
            if ~isempty(xlim),xlim=getLimits(xlim);set(ax,"XLim",xlim);end
            if ~isempty(ylim),ylim=getLimits(ylim);set(ax,"YLim",ylim);end
            if obj.zero_at_efermi
                if invertAxes,yline(ax,0,"k--");else,xline(ax,0,"k--");end
            end
            if invertAxes
                xlabel(ax,densityLabel(obj.norm_val));ylabel(ax,"Energies (eV)");xline(ax,0,"k--");
            else
                xlabel(ax,"Energies (eV)");ylabel(ax,densityLabel(obj.norm_val));yline(ax,0,"k--");
            end
            legend(ax,"show","Location","best");box(ax,"on");
        end
        function save_plot(obj,filename,varargin)
            ax=obj.get_plot(varargin{:});exportgraphics(ax,string(filename));close(ax.Parent);
        end
        function show(obj,varargin)
            ax=obj.get_plot(varargin{:});ax.Parent.Visible="on";
        end
    end
end
function value=asMap(input)
if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end
end
function value=getLimits(input),value=reshape(double(input),1,2);end
function value=densityLabel(normValue),if normValue,value="Density of states (states/eV/Å³)";else,value="Density of states (states/eV)";end,end
