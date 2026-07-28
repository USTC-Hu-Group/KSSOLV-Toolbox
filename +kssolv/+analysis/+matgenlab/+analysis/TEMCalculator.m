classdef TEMCalculator < ...
        kssolv.analysis.matgenlab.analysis.AbstractDiffractionPatternCalculator
    %TEMCALCULATOR Transmission-electron diffraction pattern calculator.
    %
    % Python dictionaries keyed by hkl tuples are represented as struct
    % arrays with fields ``hkl`` and ``value``.

    properties
        symprec = []
        voltage (1,1) double = 200
        beam_direction (1,3) double = [0,0,1]
        camera_length (1,1) double = 160
        debye_waller_factors = struct()
        cs (1,1) double = 1
    end

    methods
        function obj = TEMCalculator( ...
                symprec, voltage, beamDirection, cameraLength, ...
                debyeWallerFactors, cs)
            if nargin >= 1, obj.symprec = symprec; end
            if nargin >= 2 && ~isempty(voltage), obj.voltage = voltage; end
            if nargin >= 3 && ~isempty(beamDirection)
                obj.beam_direction = reshape(double(beamDirection),1,3);
            end
            if nargin >= 4 && ~isempty(cameraLength)
                obj.camera_length = cameraLength;
            end
            if nargin >= 5 && ~isempty(debyeWallerFactors)
                obj.debye_waller_factors = debyeWallerFactors;
            end
            if nargin >= 6 && ~isempty(cs), obj.cs = cs; end
        end

        function value = wavelength_rel(obj)
            electronMass = 9.1093837139e-31;
            elementaryCharge = 1.602176634e-19;
            lightSpeed = 299792458;
            planck = 6.62607015e-34;
            square = 2 * electronMass * elementaryCharge * 1000 * ...
                obj.voltage * (1 + elementaryCharge * 1000 * ...
                obj.voltage / (2 * electronMass * lightSpeed^2));
            value = planck / sqrt(square) * 1e10;
        end

        function points = zone_axis_filter(obj, points, laueZone)
            if nargin < 3, laueZone = 0; end
            if iscell(points)
                points = vertcat(points{:});
                return
            end
            if isempty(points)
                points = zeros(0, 3);
                return
            end
            points = double(points);
            points = points(points * obj.beam_direction.' == laueZone, :);
        end

        function result = get_interplanar_spacings(obj, structure, points)
            points = obj.zone_axis_filter(points);
            points(all(points == 0, 2), :) = [];
            values = zeros(size(points, 1), 1);
            for index = 1:numel(values)
                values(index) = structure.lattice.d_hkl(points(index, :));
            end
            result = obj.makeMap(points, values);
        end

        function result = bragg_angles(obj, interplanarSpacings)
            [planes, values] = obj.unpackMap(interplanarSpacings);
            result = obj.makeMap(planes, ...
                asin(obj.wavelength_rel() ./ (2 * values)));
        end

        function result = get_s2(obj, braggAngles)
            [planes, values] = obj.unpackMap(braggAngles);
            result = obj.makeMap(planes, ...
                (sin(values) ./ obj.wavelength_rel()).^2);
        end

        function result = x_ray_factors(obj, structure, braggAngles)
            [planes, ~] = obj.unpackMap(braggAngles);
            sSquaredMap = obj.get_s2(braggAngles);
            [~, sSquared] = obj.unpackMap(sSquaredMap);
            data = kssolv.analysis.matgenlab.analysis. ...
                diffraction_data("xray");
            elements = structure.elements;
            result = struct();
            for elementIndex = 1:numel(elements)
                element = elements{elementIndex};
                symbol = char(element.symbol);
                coefficients = data.(symbol);
                values = zeros(size(sSquared));
                for planeIndex = 1:numel(values)
                    s2 = sSquared(planeIndex);
                    values(planeIndex) = element.Z - 41.78214 * s2 * ...
                        sum(coefficients(:,1) .* ...
                        exp(-coefficients(:,2) * s2));
                end
                result.(symbol) = obj.makeMap(planes, values);
            end
        end

        function result = electron_scattering_factors( ...
                obj, structure, braggAngles)
            [planes, ~] = obj.unpackMap(braggAngles);
            sSquaredMap = obj.get_s2(braggAngles);
            [~, sSquared] = obj.unpackMap(sSquaredMap);
            xray = obj.x_ray_factors(structure, braggAngles);
            elements = structure.elements;
            result = struct();
            for elementIndex = 1:numel(elements)
                element = elements{elementIndex};
                symbol = char(element.symbol);
                [~, xrayValues] = obj.unpackMap(xray.(symbol));
                values = 0.023934 * ...
                    (element.Z - xrayValues) ./ sSquared;
                result.(symbol) = obj.makeMap(planes, values);
            end
        end

        function result = cell_scattering_factors( ...
                obj, structure, braggAngles)
            [planes, ~] = obj.unpackMap(braggAngles);
            electron = obj.electron_scattering_factors( ...
                structure, braggAngles);
            values = complex(zeros(size(planes, 1), 1));
            for planeIndex = 1:size(planes, 1)
                plane = planes(planeIndex, :);
                for siteIndex = 1:structure.num_sites
                    site = structure(siteIndex);
                    [species, ~] = site.species.items();
                    phase = dot(plane, site.frac_coords);
                    for speciesIndex = 1:numel(species)
                        symbol = char(species{speciesIndex}.symbol);
                        factor = obj.mapValue( ...
                            electron.(symbol), plane);
                        values(planeIndex) = values(planeIndex) + ...
                            factor * exp(2i * pi * phase);
                    end
                end
            end
            result = obj.makeMap(planes, values);
        end

        function result = cell_intensity(obj, structure, braggAngles)
            scattering = obj.cell_scattering_factors( ...
                structure, braggAngles);
            [planes, values] = obj.unpackMap(scattering);
            result = obj.makeMap(planes, real(values .* conj(values)));
        end

        function tableValue = get_pattern( ...
                obj, structure, scaled, two_theta_range) %#ok<INUSD>
            if ~isempty(obj.symprec) && obj.symprec
                analyzer = ...
                    kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure, obj.symprec);
                structure = analyzer.get_refined_structure();
            end
            dots = obj.tem_dots(structure, obj.generate_points(-10, 11));
            count = numel(dots);
            positions = zeros(count, 2);
            hkls = zeros(count, 3);
            intensities = zeros(count, 1);
            radii = zeros(count, 1);
            spacings = zeros(count, 1);
            for index = 1:count
                positions(index,:) = dots(index).position;
                hkls(index,:) = dots(index).hkl;
                intensities(index) = dots(index).intensity;
                radii(index) = dots(index).film_radius;
                spacings(index) = dots(index).d_spacing;
            end
            tableValue = table(positions, hkls, intensities, radii, spacings, ...
                VariableNames = ["Position","hkl","Intensity_norm", ...
                "Film_radius","Interplanar_Spacing"]);
            tableValue.Properties.UserData.PymatgenColumnNames = ...
                cellstr(["Position","(hkl)","Intensity (norm)", ...
                "Film radius","Interplanar Spacing"]);
        end

        function result = normalized_cell_intensity( ...
                obj, structure, braggAngles)
            intensity = obj.cell_intensity(structure, braggAngles);
            [planes, values] = obj.unpackMap(intensity);
            result = obj.makeMap(planes, values / max(values));
        end

        function value = is_parallel(obj, structure, plane, otherPlane)
            angle = obj.get_interplanar_angle( ...
                structure, plane, otherPlane);
            value = angle == 180 || angle == 0 || isnan(angle);
        end

        function result = get_first_point(obj, structure, points)
            points = obj.zone_axis_filter(points);
            spacings = obj.get_interplanar_spacings(structure, points);
            [planes, values] = obj.unpackMap(spacings);
            [maximum, index] = max(values);
            % Python iterates sorted tuple keys when resolving ties.
            ties = find(values == maximum);
            if numel(ties) > 1
                [~, order] = sortrows(planes(ties,:));
                index = ties(order(1));
            end
            result = obj.makeMap(planes(index,:), maximum);
        end

        function positions = get_positions(obj, structure, points)
            points = obj.zone_axis_filter(points);
            first = obj.get_first_point(structure, points);
            firstPoint = first.hkl;
            firstD = first.value;
            spacings = obj.get_interplanar_spacings(structure, points);
            [planes, dValues] = obj.unpackMap(spacings);
            [sortedPlanes, order] = sortrows(planes);
            sortedD = dValues(order);
            secondPoint = [0,0,0];
            secondD = 0;
            for index = 1:size(sortedPlanes,1)
                secondPoint = sortedPlanes(index,:);
                secondD = sortedD(index);
                if ~obj.is_parallel( ...
                        structure, firstPoint, secondPoint)
                    break
                end
            end
            points(all(points == 0,2),:) = [];
            points(ismember(points,firstPoint,"rows"),:) = [];
            points(ismember(points,secondPoint,"rows"),:) = [];
            allPlanes = [[0,0,0]; firstPoint; secondPoint; points];
            values = zeros(size(allPlanes,1),2);
            r1 = obj.wavelength_rel() * obj.camera_length / firstD;
            values(2,:) = [r1,0];
            r2 = obj.wavelength_rel() * obj.camera_length / secondD;
            phi = deg2rad(obj.get_interplanar_angle( ...
                structure, firstPoint, secondPoint));
            values(3,:) = [r2*cos(phi), r2*sin(phi)];
            for index = 4:size(allPlanes,1)
                coefficients = obj.get_plot_coeffs( ...
                    firstPoint, secondPoint, allPlanes(index,:));
                values(index,:) = coefficients(1)*values(2,:) + ...
                    coefficients(2)*values(3,:);
            end
            positions = obj.makeMap(allPlanes, values);
        end

        function dots = tem_dots(obj, structure, points)
            spacings = obj.get_interplanar_spacings(structure, points);
            angles = obj.bragg_angles(spacings);
            intensities = obj.normalized_cell_intensity( ...
                structure, angles);
            positions = obj.get_positions(structure, points);
            [planes, values] = obj.unpackMap(intensities);
            dots = repmat(struct( ...
                "position", zeros(1,2), ...
                "hkl", zeros(1,3), ...
                "intensity", 0, ...
                "film_radius", 0, ...
                "d_spacing", 0), numel(values), 1);
            radius = 0.91 * ...
                (1e-3 * obj.cs * obj.wavelength_rel()^3)^(1/4);
            for index = 1:numel(values)
                plane = planes(index,:);
                dots(index) = struct( ...
                    "position", obj.mapValue(positions, plane), ...
                    "hkl", plane, ...
                    "intensity", values(index), ...
                    "film_radius", radius, ...
                    "d_spacing", obj.mapValue(spacings, plane));
            end
        end

        function fig = get_plot_2d(obj, structure)
            fig = obj.makePlot(structure, false);
        end

        function fig = get_plot_2d_concise(obj, structure)
            fig = obj.makePlot(structure, true);
        end
    end

    methods (Static)
        function points = generate_points(coordLeft, coordRight)
            if nargin < 1, coordLeft = -10; end
            if nargin < 2, coordRight = 10; end
            values = coordLeft:coordRight;
            [z,x,y] = ndgrid(values, values, values);
            points = [x(:),y(:),z(:)];
        end

        function angle = get_interplanar_angle(structure, p1, p2)
            lattice = structure.lattice;
            a = lattice.a; b = lattice.b; c = lattice.c;
            alpha = deg2rad(lattice.alpha);
            beta = deg2rad(lattice.beta);
            gamma = deg2rad(lattice.gamma);
            volume = structure.volume;
            aStar = b*c*sin(alpha)/volume;
            bStar = a*c*sin(beta)/volume;
            cStar = a*b*sin(gamma)/volume;
            cosAlphaStar = (cos(beta)*cos(gamma)-cos(alpha)) / ...
                (sin(beta)*sin(gamma));
            cosBetaStar = (cos(alpha)*cos(gamma)-cos(beta)) / ...
                (sin(alpha)*sin(gamma));
            cosGammaStar = (cos(alpha)*cos(beta)-cos(gamma)) / ...
                (sin(alpha)*sin(beta));
            r1Norm = sqrt( ...
                p1(1)^2*aStar^2 + p1(2)^2*bStar^2 + ...
                p1(3)^2*cStar^2 + ...
                2*p1(1)*p1(2)*aStar*bStar*cosGammaStar + ...
                2*p1(1)*p1(3)*aStar*cStar*cosBetaStar + ...
                2*p1(2)*p1(3)*bStar*cStar*cosGammaStar);
            r2Norm = sqrt( ...
                p2(1)^2*aStar^2 + p2(2)^2*bStar^2 + ...
                p2(3)^2*cStar^2 + ...
                2*p2(1)*p2(2)*aStar*bStar*cosGammaStar + ...
                2*p2(1)*p2(3)*aStar*cStar*cosBetaStar + ...
                2*p2(2)*p2(3)*bStar*cStar*cosGammaStar);
            dotValue = ...
                p1(1)*p2(1)*aStar^2 + ...
                p1(2)*p2(2)*bStar^2 + ...
                p1(3)*p2(3)*cStar^2 + ...
                (p1(1)*p2(2)+p2(1)*p1(2))*aStar*bStar*cosGammaStar + ...
                (p1(1)*p2(3)+p2(1)*p1(2))*aStar*cStar*cosBetaStar + ...
                (p1(2)*p2(3)+p2(2)*p1(3))*bStar*cStar*cosAlphaStar;
            angle = rad2deg(acos(dotValue/(r1Norm*r2Norm)));
        end

        function coefficients = get_plot_coeffs(p1, p2, p3)
            matrix = [p1(:),p2(:)];
            coefficients = reshape(pinv(matrix)*p3(:),1,[]);
        end
    end

    methods (Access = private)
        function fig = makePlot(obj, structure, concise)
            if ~isempty(obj.symprec) && obj.symprec
                analyzer = ...
                    kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure, obj.symprec);
                structure = analyzer.get_refined_structure();
            end
            dots = obj.tem_dots(structure, obj.generate_points(-10,11));
            if concise
                dots(arrayfun(@(dot) all(dot.hkl == 0), dots)) = [];
            end
            fig = figure();
            ax = axes(fig);
            positions = vertcat(dots.position);
            intensities = [dots.intensity].';
            scatter(ax, positions(:,1), positions(:,2), ...
                8 - 4*logical(concise), intensities, "filled");
            colormap(ax, gray);
            clim(ax,[0,1]);
            xlim(ax,[-4,4]); ylim(ax,[-4,4]);
            axis(ax,"equal");
            ax.Color = "black";
            ax.XTick = []; ax.YTick = [];
            if ~concise
                hold(ax,"on");
                scatter(ax,0,0,14,"white","filled");
                title(ax, "2D Diffraction Pattern — Beam Direction: " + ...
                    strjoin(string(obj.beam_direction),""));
            end
        end
    end

    methods (Static, Access = private)
        function result = makeMap(planes, values)
            planes = reshape(double(planes), [], 3);
            if isvector(values) && size(planes,1) == numel(values)
                values = reshape(values, [], 1);
            end
            result = repmat(struct("hkl",zeros(1,3),"value",[]), ...
                size(planes,1),1);
            for index = 1:size(planes,1)
                result(index).hkl = planes(index,:);
                if size(values,1) == size(planes,1)
                    result(index).value = values(index,:);
                else
                    result(index).value = values(index);
                end
            end
        end

        function [planes, values] = unpackMap(mapping)
            if isempty(mapping)
                planes = zeros(0,3);
                values = zeros(0,1);
                return
            end
            if ~isstruct(mapping) || ~isfield(mapping,"hkl") || ...
                    ~isfield(mapping,"value")
                error("KSSOLV:Matgenlab:TEMCalculator:HklMap", ...
                    "hkl mappings must be struct arrays with hkl/value fields.");
            end
            planes = vertcat(mapping.hkl);
            values = vertcat(mapping.value);
        end

        function value = mapValue(mapping, plane)
            planes = vertcat(mapping.hkl);
            index = find(ismember(planes,reshape(plane,1,3),"rows"),1);
            if isempty(index)
                error("KSSOLV:Matgenlab:TEMCalculator:HklKey", ...
                    "The requested hkl is absent.");
            end
            value = mapping(index).value;
        end
    end
end
