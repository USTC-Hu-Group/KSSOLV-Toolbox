function [value, status] = order_assimilation(args)
%ORDER_ASSIMILATION Assimilate one path and advance a status record.
if iscell(args)
    if numel(args) < 2
        error("KSSOLV:Matgenlab:BorgQueen:Arguments", ...
            "args must contain at least {path, drone}.");
    end
    path = args{1};
    drone = args{2};
    if numel(args) >= 4, status = args{4};
    else, status = struct("count", 0, "total", 1); end
elseif isstruct(args) && all(isfield(args, ["path", "drone"]))
    path = args.path;
    drone = args.drone;
    if isfield(args, "status"), status = args.status;
    else, status = struct("count", 0, "total", 1); end
else
    error("KSSOLV:Matgenlab:BorgQueen:Arguments", ...
        "args must be a tuple-like cell or a path/drone structure.");
end
value = drone.assimilate(path);
if ~isfield(status, "count"), status.count = 0; end
status.count = status.count + 1;
if ~isfield(status, "total"), status.total = status.count; end
end
