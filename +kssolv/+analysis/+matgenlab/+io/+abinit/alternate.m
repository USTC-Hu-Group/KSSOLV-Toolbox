function value=alternate(varargin)
%ALTERNATE Interleave equally sized sequences.
n=numel(varargin{1});value=cell(1,n*numel(varargin));
for i=1:n,for j=1:numel(varargin),source=varargin{j};if iscell(source),value{(i-1)*numel(varargin)+j}=source{i};else,value{(i-1)*numel(varargin)+j}=source(i);end,end,end
end
