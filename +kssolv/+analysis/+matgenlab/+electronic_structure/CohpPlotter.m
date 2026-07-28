classdef CohpPlotter < handle
    %COHPPLOTTER Collect and plot COHP, COOP or COBI curves.
    properties
        zero_at_efermi (1,1) logical=true
        are_coops (1,1) logical=false
        are_cobis (1,1) logical=false
    end
    properties (SetAccess=private)
        cohps
    end
    methods
        function obj=CohpPlotter(zeroAtEfermi,areCoops,areCobis)
            if nargin>=1&&~isempty(zeroAtEfermi),obj.zero_at_efermi=logical(zeroAtEfermi);end
            if nargin>=2&&~isempty(areCoops),obj.are_coops=logical(areCoops);end
            if nargin>=3&&~isempty(areCobis),obj.are_cobis=logical(areCobis);end
            if obj.are_coops&&obj.are_cobis,error("KSSOLV:Matgenlab:CohpPlotter:PopulationType","COOP and COBI flags are exclusive.");end
            obj.cohps=containers.Map("KeyType","char","ValueType","any");
        end
        function add_cohp(obj,label,cohp)
            if cohp.are_coops~=obj.are_coops||cohp.are_cobis~=obj.are_cobis
                error("KSSOLV:Matgenlab:CohpPlotter:PopulationType", ...
                    "All curves must use the plotter's population type.");
            end
            energies=cohp.energies;if obj.zero_at_efermi,energies=energies-cohp.efermi;end
            record=struct(energies=energies,COHP=cohp.cohp,efermi=cohp.efermi);
            if ~isempty(cohp.icohp),record.ICOHP=cohp.icohp;end
            obj.cohps(char(string(label)))=record;
        end
        function add_cohp_dict(obj,input,keySortFunc)
            if nargin<3,keySortFunc=[];end
            source=asMap(input);keys=source.keys;
            if ~isempty(keySortFunc),[~,order]=sort(cellfun(keySortFunc,keys));keys=keys(order);end
            for ii=1:numel(keys),obj.add_cohp(keys{ii},source(keys{ii}));end
        end
        function value=get_cohp_dict(obj),value=obj.cohps;end
        function ax=get_plot(obj,xlim,ylim,plotNegative,integrated,invertAxes)
            if nargin<2,xlim=[];end
            if nargin<3,ylim=[];end
            if nargin<4||isempty(plotNegative),plotNegative=~obj.are_coops&&~obj.are_cobis;end
            if nargin<5||isempty(integrated),integrated=false;end
            if nargin<6||isempty(invertAxes),invertAxes=true;end
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            keys=obj.cohps.keys;colors=lines(max(3,numel(keys)));
            for ii=1:numel(keys)
                item=obj.cohps(keys{ii});
                if integrated
                    if ~isfield(item,"ICOHP"),error("KSSOLV:Matgenlab:CohpPlotter:MissingIcohp","ICOHP data are absent.");end
                    curves=item.ICOHP;
                else
                    curves=item.COHP;
                end
                names=fieldnames(curves);
                for ss=1:numel(names)
                    population=curves.(names{ss});
                    if plotNegative,population=-population;end
                    if strcmp(names{ss},"down"),population=-population;end
                    if invertAxes,x=population;y=item.energies;else,x=item.energies;y=population;end
                    style="-";if strcmp(names{ss},"down"),style="--";end
                    plot(ax,x,y,style,"Color",colors(ii,:),"LineWidth",2, ...
                        "DisplayName",keys{ii});
                end
            end
            if ~isempty(xlim),set(ax,"XLim",reshape(double(xlim),1,2));end
            if ~isempty(ylim),set(ax,"YLim",reshape(double(ylim),1,2));end
            label=populationLabel(obj,integrated,plotNegative);
            if invertAxes,xlabel(ax,label);ylabel(ax,"E - E_f (eV)");
            else,xlabel(ax,"E - E_f (eV)");ylabel(ax,label);end
            if obj.zero_at_efermi
                if invertAxes,yline(ax,0,"k--");else,xline(ax,0,"k--");end
            end
            legend(ax,"show","Location","best");box(ax,"on");
        end
        function save_plot(obj,filename,xlim,ylim)
            if nargin<3,xlim=[];end
            if nargin<4,ylim=[];end
            ax=obj.get_plot(xlim,ylim);exportgraphics(ax,string(filename));close(ax.Parent);
        end
        function show(obj,varargin),ax=obj.get_plot(varargin{:});ax.Parent.Visible="on";end
    end
end
function value=populationLabel(obj,integrated,negative)
if obj.are_coops,name="COOP";elseif obj.are_cobis,name="COBI";else,name="COHP";end
if integrated,name="I"+name;end
if negative,name="-"+name;end
value=name;
end
function value=asMap(input),if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end,end
