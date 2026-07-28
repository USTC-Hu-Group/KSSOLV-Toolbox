classdef StructureInteractorStyle < handle
    %STRUCTUREINTERACTORSTYLE MATLAB callback equivalent of VTK interactor.

    properties
        parent
        mouse_motion (1,1) double = 0
    end

    methods
        function obj=StructureInteractorStyle(parent)
            if nargin<1||~isa(parent, ...
                    "kssolv.analysis.matgenlab.vis.StructureVis")
                error("KSSOLV:Matgenlab:StructureInteractor:Parent", ...
                    "parent must be a StructureVis instance.");
            end
            obj.parent=parent;
        end

        function leftButtonPressEvent(obj,source,event) %#ok<INUSD>
            obj.mouse_motion=0;
        end

        function mouseMoveEvent(obj,source,event) %#ok<INUSD>
            obj.mouse_motion=1;
        end

        function leftButtonReleaseEvent(obj,source,event) %#ok<INUSD>
            if obj.mouse_motion==0
                obj.parent.add_picker_fixed();
            end
        end

        function keyPressEvent(obj,source,event) %#ok<INUSD>
            key=obj.key(event);
            parent=obj.parent;
            switch key
                case "A"
                    parent.supercell(1,1)=parent.supercell(1,1)+1;
                    parent.redraw();
                case "B"
                    parent.supercell(2,2)=parent.supercell(2,2)+1;
                    parent.redraw();
                case "C"
                    parent.supercell(3,3)=parent.supercell(3,3)+1;
                    parent.redraw();
                case "a"
                    parent.supercell(1,1)= ...
                        max(parent.supercell(1,1)-1,1);
                    parent.redraw();
                case "b"
                    parent.supercell(2,2)= ...
                        max(parent.supercell(2,2)-1,1);
                    parent.redraw();
                case "c"
                    parent.supercell(3,3)= ...
                        max(parent.supercell(3,3)-1,1);
                    parent.redraw();
                case {"#","numbersign"}
                    parent.show_polyhedron=~parent.show_polyhedron;
                    parent.redraw();
                case {"-","minus"}
                    parent.show_bonds=~parent.show_bonds;
                    parent.redraw();
                case {"[","bracketleft"}
                    if parent.poly_radii_tol_factor>0
                        parent.poly_radii_tol_factor= ...
                            parent.poly_radii_tol_factor-.05;
                    end
                    parent.redraw();
                case {"]","bracketright"}
                    parent.poly_radii_tol_factor= ...
                        parent.poly_radii_tol_factor+.05;
                    parent.redraw();
                case "h"
                    parent.show_help=~parent.show_help;
                    parent.redraw();
                case "r"
                    parent.redraw(true);
                case "s"
                    parent.write_image("image.png");
                case {"uparrow","Up"}
                    parent.rotate_view(1,90);
                case {"downarrow","Down"}
                    parent.rotate_view(1,-90);
                case {"leftarrow","Left"}
                    parent.rotate_view(0,-90);
                case {"rightarrow","Right"}
                    parent.rotate_view(0,90);
                case "o"
                    parent.orthogonalize_structure();
                    parent.redraw();
            end
        end
    end

    methods (Static,Access=protected)
        function value=key(event)
            if ischar(event)||isstring(event)
                value=string(event);
                return
            end
            value="";
            if isstruct(event)
                if isfield(event,"Character")&& ...
                        strlength(string(event.Character))>0
                    value=string(event.Character);
                elseif isfield(event,"Key")
                    value=string(event.Key);
                end
            elseif isobject(event)
                if isprop(event,"Character")&& ...
                        strlength(string(event.Character))>0
                    value=string(event.Character);
                elseif isprop(event,"Key")
                    value=string(event.Key);
                end
            end
        end
    end
end
