function order = get_bond_order(sp1, sp2, distance, tol, default_bl)
%GET_BOND_ORDER Interpolate a bond order from an inter-site distance.
if nargin < 4 || isempty(tol), tol = 0.2; end
if nargin < 5, default_bl = []; end
lengths = kssolv.analysis.matgenlab.core.obtain_all_bond_lengths( ...
    sp1, sp2, default_bl);
orders = sort(cell2mat(lengths.keys));
if ~isequal(orders, 1:numel(orders))
    error("KSSOLV:Matgenlab:Bonds:NonSuccessiveOrders", ...
        "Bond length data must contain successive orders starting at one.");
end
lens = [lengths(1) * (1 + tol), ...
    arrayfun(@(value) lengths(value), orders)];
trial = 0;
while trial < numel(lens)
    if lens(trial + 1) < distance
        if trial == 0
            order = 0;
            return
        end
        low = lens(trial + 1);
        high = lens(trial);
        order = trial - (distance - low) / (high - low);
        return
    end
    trial = trial + 1;
end
if distance < lens(end) * (1 - tol)
    warning("KSSOLV:Matgenlab:Bonds:DistanceTooShort", ...
        "%.2f angstrom distance is too short.", distance);
end
order = trial - 1;
end
