classdef MultiStructuresVis < kssolv.analysis.matgenlab.vis.StructureVis
    %MULTISTRUCTURESVIS Native viewer for an indexed structure sequence.

    properties (Constant)
        DEFAULT_ANIMATED_MOVIE_OPTIONS = struct( ...
            "time_between_frames",.1, ...
            "looping_type","restart", ...
            "number_of_loops",1, ...
            "time_between_loops",1)
    end

    properties
        structures cell = cell(1,0)
        istruct (1,1) double = 1
        current_structure = []
        tags cell = cell(1,0)
        all_radii cell = cell(1,0)
        all_vis_radii cell = cell(1,0)
        animated_movie_options (1,1) struct = struct()
        warning_txt (1,1) string = ""
        info_txt (1,1) string = ""
        warning_txt_actor = []
        info_txt_actor = []
    end

    methods
        function obj=MultiStructuresVis(elementColorMapping, ...
                showUnitCell,showBonds,showPolyhedron, ...
                polyRadiiTolFactor,excludedBondingElements, ...
                animatedMovieOptions)
            if nargin<1,elementColorMapping=[];end
            if nargin<2,showUnitCell=true;end
            if nargin<3,showBonds=false;end
            if nargin<4,showPolyhedron=false;end
            if nargin<5,polyRadiiTolFactor=.5;end
            if nargin<6,excludedBondingElements=[];end
            if nargin<7
                animatedMovieOptions= ...
                    kssolv.analysis.matgenlab.vis. ...
                    MultiStructuresVis.DEFAULT_ANIMATED_MOVIE_OPTIONS;
            end
            obj@kssolv.analysis.matgenlab.vis.StructureVis( ...
                elementColorMapping,showUnitCell,showBonds, ...
                showPolyhedron,polyRadiiTolFactor, ...
                excludedBondingElements);
            obj.interactor_style=kssolv.analysis.matgenlab.vis. ...
                MultiStructuresInteractorStyle(obj);
            obj.installCallbacks();
            obj.set_animated_movie_options(animatedMovieOptions);
        end

        function set_structures(obj,structures,tags)
            if nargin<3,tags=[];end
            if iscell(structures)
                values=reshape(structures,1,[]);
            else
                values=num2cell(structures);
            end
            if isempty(values)
                error("KSSOLV:Matgenlab:MultiStructuresVis:Empty", ...
                    "At least one structure is required.");
            end
            if ~all(cellfun(@(item)isa(item, ...
                    "kssolv.analysis.matgenlab.core.Structure"),values))
                error("KSSOLV:Matgenlab:MultiStructuresVis:Structure", ...
                    "All entries must be Structure instances.");
            end
            obj.structures=values;
            obj.istruct=1;
            obj.current_structure=values{1};
            if isempty(tags)
                obj.tags=cell(1,0);
            elseif iscell(tags)
                obj.tags=reshape(tags,1,[]);
            else
                obj.tags=num2cell(tags);
            end
            obj.all_radii=cell(1,numel(values));
            obj.all_vis_radii=cell(1,numel(values));
            for structureIndex=1:numel(values)
                structure=values{structureIndex};
                radii=zeros(1,structure.num_sites);
                visual=zeros(1,structure.num_sites);
                for siteIndex=1:structure.num_sites
                    site=structure(siteIndex);
                    [species,occupancies]=site.species.items();
                    radius=0;
                    for speciesIndex=1:numel(species)
                        radius=radius+occupancies(speciesIndex)* ...
                            obj.speciesRadius(species{speciesIndex});
                    end
                    radii(siteIndex)=radius;
                    visual(siteIndex)=.2+.002*radius;
                end
                obj.all_radii{structureIndex}=radii;
                obj.all_vis_radii{structureIndex}=visual;
            end
            obj.set_structure(obj.current_structure,true,false);
        end

        function set_structure(obj,structure,resetCamera,toUnitCell)
            if nargin<3,resetCamera=true;end
            if nargin<4,toUnitCell=false;end
            set_structure@kssolv.analysis.matgenlab.vis.StructureVis( ...
                obj,structure,resetCamera,toUnitCell);
            obj.apply_tags();
        end

        function apply_tags(obj)
            if isempty(obj.tags)||isempty(obj.current_structure),return,end
            styles=containers.Map("KeyType","char","ValueType","any");
            for index=1:numel(obj.tags)
                tag=obj.tags{index};
                if ~isstruct(tag)
                    error("KSSOLV:Matgenlab:MultiStructuresVis:Tag", ...
                        "Each tag must be a scalar structure.");
                end
                applies="all";
                if isfield(tag,"istruct"),applies=tag.istruct;end
                if ~(string(applies)=="all"|| ...
                        isequal(double(applies),obj.istruct))
                    continue
                end
                color=[.5,.5,.5];
                opacity=.5;
                if isfield(tag,"color"),color=tag.color;end
                if isfield(tag,"opacity"),opacity=tag.opacity;end
                siteIndex=tag.site_index;
                if ischar(siteIndex)||isstring(siteIndex)
                    if string(siteIndex)~="unit_cell_all"
                        error("KSSOLV:Matgenlab:MultiStructuresVis:TagSite", ...
                            "Unknown tag site selector '%s'.",siteIndex);
                    end
                    radii=obj.all_vis_radii{obj.istruct};
                    for current=1:obj.current_structure.num_sites
                        radius=1.5*radii(current);
                        if isfield(tag,"radius")
                            radius=1.5*tag.radius;
                        end
                        key=sprintf("%d|0|0|0",current);
                        styles(key)=struct("site_index",current, ...
                            "cell_index",[0,0,0],"radius",radius, ...
                            "color",color,"opacity",opacity);
                    end
                    continue
                end
                obj.validateSiteIndex(siteIndex);
                if ~isfield(tag,"cell_index")
                    error("KSSOLV:Matgenlab:MultiStructuresVis:CellIndex", ...
                        "A tag must define cell_index.");
                end
                cellIndex=reshape(double(tag.cell_index),1,3);
                if isfield(tag,"radius")
                    radius=tag.radius;
                elseif isfield(tag,"radius_factor")
                    radius=tag.radius_factor* ...
                        obj.all_vis_radii{obj.istruct}(siteIndex);
                else
                    radius=1.5* ...
                        obj.all_vis_radii{obj.istruct}(siteIndex);
                end
                key=sprintf("%d|%g|%g|%g",siteIndex,cellIndex);
                styles(key)=struct("site_index",siteIndex, ...
                    "cell_index",cellIndex,"radius",radius, ...
                    "color",color,"opacity",opacity);
            end
            keys_=sort(string(styles.keys()));
            for index=1:numel(keys_)
                style=styles(char(keys_(index)));
                site=obj.current_structure(style.site_index);
                if all(style.cell_index==0)
                    coords=site.coords;
                else
                    image=kssolv.analysis.matgenlab.core.PeriodicSite( ...
                        site.species,site.frac_coords+style.cell_index, ...
                        obj.current_structure.lattice, ...
                        properties=site.site_properties);
                    obj.add_site(image);
                    coords=image.coords;
                end
                obj.add_partial_sphere(coords,style.radius, ...
                    style.color,0,360,style.opacity);
                obj.record(struct("kind","tag", ...
                    "site_index",style.site_index, ...
                    "cell_index",style.cell_index, ...
                    "coords",coords,"radius",style.radius, ...
                    "color",obj.normalizeColor(style.color), ...
                    "opacity",style.opacity));
            end
        end

        function set_animated_movie_options(obj,animatedMovieOptions)
            defaults=obj.DEFAULT_ANIMATED_MOVIE_OPTIONS;
            if nargin<2||isempty(animatedMovieOptions)
                obj.animated_movie_options=defaults;
                return
            end
            if ~isstruct(animatedMovieOptions)|| ...
                    ~isscalar(animatedMovieOptions)
                error("KSSOLV:Matgenlab:MultiStructuresVis:MovieOptions", ...
                    "animated_movie_options must be a scalar structure.");
            end
            names=fieldnames(animatedMovieOptions);
            valid=fieldnames(defaults);
            if any(~ismember(names,valid))
                error("KSSOLV:Matgenlab:MultiStructuresVis:MovieOption", ...
                    "Wrong option for animated movie.");
            end
            for index=1:numel(names)
                defaults.(names{index})= ...
                    animatedMovieOptions.(names{index});
            end
            obj.animated_movie_options=defaults;
        end

        function display_help(obj)
            display_help@kssolv.analysis.matgenlab.vis.StructureVis(obj);
            obj.help_text=obj.help_text+newline+ ...
                "n/p : Next/previous structure"+newline+ ...
                "m : Animate structures";
            handles=findobj(obj.axes_handle,"Type","text", ...
                "Units","normalized");
            if ~isempty(handles),handles(1).String=obj.help_text;end
        end

        function display_warning(obj,warningValue)
            obj.erase_warning();
            obj.warning_txt="WARNING : "+string(warningValue);
            obj.warning_txt_actor=text(obj.axes_handle,.99,.01, ...
                obj.warning_txt,"Units","normalized", ...
                "HorizontalAlignment","right", ...
                "VerticalAlignment","bottom","Color",[1,0,0], ...
                "FontWeight","bold","Interpreter","none");
            obj.rememberHandle(obj.warning_txt_actor);
            obj.record(struct("kind","warning", ...
                "text",obj.warning_txt));
        end

        function erase_warning(obj)
            if ~isempty(obj.warning_txt_actor)&& ...
                    isgraphics(obj.warning_txt_actor)
                obj.warning_txt_actor.Visible="off";
            end
        end

        function display_info(obj,infoValue)
            obj.erase_info();
            obj.info_txt="INFO : "+string(infoValue);
            obj.info_txt_actor=text(obj.axes_handle,.01,.99, ...
                obj.info_txt,"Units","normalized", ...
                "HorizontalAlignment","left", ...
                "VerticalAlignment","top","Color",[0,0,1], ...
                "FontWeight","bold","Interpreter","none");
            obj.rememberHandle(obj.info_txt_actor);
            obj.record(struct("kind","info","text",obj.info_txt));
        end

        function erase_info(obj)
            if ~isempty(obj.info_txt_actor)&& ...
                    isgraphics(obj.info_txt_actor)
                obj.info_txt_actor.Visible="off";
            end
        end
    end

    methods (Access=protected)
        function validateSiteIndex(obj,index)
            if ~isscalar(index)||index~=fix(index)||index<1|| ...
                    index>obj.current_structure.num_sites
                error("KSSOLV:Matgenlab:MultiStructuresVis:SiteIndex", ...
                    "site_index must be a valid MATLAB one-based index.");
            end
        end
    end
end
