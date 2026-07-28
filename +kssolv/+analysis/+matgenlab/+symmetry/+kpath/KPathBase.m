classdef KPathBase < handle
    %KPATHBASE Base data model for reciprocal-space high-symmetry paths.
    properties (SetAccess=protected)
        structure
        lattice
        rec_lattice
        kpath
        symprec (1,1) double
        angle_tolerance (1,1) double
        atol (1,1) double
    end
    methods
        function obj=KPathBase(structure,symprec,angleTolerance,atol)
            if nargin<2||isempty(symprec),symprec=0.01;end
            if nargin<3||isempty(angleTolerance),angleTolerance=5;end
            if nargin<4||isempty(atol),atol=1e-5;end
            obj.structure=structure;
            obj.lattice=structure.lattice;
            obj.rec_lattice=structure.lattice.reciprocal_lattice;
            obj.kpath=[];
            obj.symprec=symprec;
            obj.angle_tolerance=angleTolerance;
            obj.atol=atol;
        end

        function [points,labels]=get_kpoints( ...
                obj,lineDensity,coordsAreCartesian)
            if nargin<2||isempty(lineDensity),lineDensity=20;end
            if nargin<3||isempty(coordsAreCartesian)
                coordsAreCartesian=true;
            end
            points=zeros(0,3);labels=strings(0,1);
            paths=obj.kpath.path;
            for pathIndex=1:numel(paths)
                path=paths{pathIndex};
                for step=2:numel(path)
                    first=obj.kpath.kpoints(path{step-1});
                    last=obj.kpath.kpoints(path{step});
                    firstCartesian=obj.rec_lattice. ...
                        get_cartesian_coords(first);
                    lastCartesian=obj.rec_lattice. ...
                        get_cartesian_coords(last);
                    intervals=ceil(norm( ...
                        firstCartesian-lastCartesian)*lineDensity);
                    if intervals==0,continue,end
                    parameter=linspace(0,1,intervals+1).';
                    segment=firstCartesian+ ...
                        (lastCartesian-firstCartesian).*parameter;
                    segmentLabels=strings(intervals+1,1);
                    segmentLabels(1)=string(path{step-1});
                    segmentLabels(end)=string(path{step});
                    points=[points;segment]; %#ok<AGROW>
                    labels=[labels;segmentLabels]; %#ok<AGROW>
                end
            end
            if ~coordsAreCartesian
                points=obj.rec_lattice.get_fractional_coords(points);
            end
        end
    end
end
