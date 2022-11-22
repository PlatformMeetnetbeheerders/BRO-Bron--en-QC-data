function [gmw] = readBron2gmw(filepath, hdfroot)
%readBron2gmw - Read GMW object from a BronV2.x file
%
% INPUT
%  filepath:
%    Char, path of the file to be read.
%  hdfroot: [default value: '/']
%    Char, root in the hierarchy under which the GMW object is stored.
% 
% OUTPUT
%  gmw:
%    struct array with fields 'History', 'Tube' and 'Well'.
% 
% THROWS:
%  Exception 'QC-Wizard:badVErsion:BRON_VERSION' if the major version of
%  the Bron file does not agree with this library (BRON_VERSION(1)~=2)
% 
%  
% Written by Giel van Bergen (Provincie Gelderland) d.d. : 14-Mar-2022.
% Published by Provincie Gelderland, under the CC-BY Public License ( Creative Commons Attribution 4.0 International).


if ~exist( 'filepath', 'var')
    gmw = testFunction();
    return
end
if ~exist( 'hdfroot', 'var')
    hdfroot = '/';
end

% note: BRON_VERSION is always stored at '/', even if hdfroot is non-empty.
bron_version_file = h5readatt( filepath, '/', 'BRON_VERSION');

if bron_version_file(1) ~= 2
    throw(MException('QC-Wizard:badVersion:BRON_VERSION',...
                     'BRON_VERSION specified in file does not agree with this library.'))
end
% h5info only accepts '/', not '', for info about the top level of the
% hierarchy.
if strcmp( hdfroot, '')
   fileinfo = h5info( filepath, '/');
else
   fileinfo = h5info( filepath, hdfroot); 
end
% 

groups = fileinfo.Groups;
ngroups = numel(groups);

% TODO: Preallocate gmw
gmw = struct( 'History', {}, 'Tube', {}, 'Well', {});
for i_grp = 1 : ngroups
    hdfpathgmw = groups( i_grp).Name;
    history = readBron2table( filepath, [hdfpathgmw '/History']);
    tube = readBron2table( filepath, [hdfpathgmw '/Tube']);
    well = readBron2table( filepath, [hdfpathgmw '/Well']);
    gmw(i_grp) = struct( 'History', history, 'Tube', tube, 'Well', well);
end
end

function [tbl] = readBron2table(filepath, hdfroot)
%readBron2table - read (possibly nested) table from a BronV2.x file.
% INPUT
%  filepath:
%    Char, path and name of the file to read.
%  hdfroot:
%    Char, root in the hierarchy under which the table is stored.

colnames = h5read( filepath, [hdfroot '/VariableNames']);

% Happens for empty tables, so short-circuit and return empty table.
if isempty(colnames) || (length(colnames) ==1 && strcmp(colnames, 'Var1'))
    tbl = table([]);
    return
end

tbl = table();

for i_colname = 1 : numel(colnames)
    colname = colnames{i_colname};
    hdfpathcol = [hdfroot '/' colname];
    dtype = h5readatt( filepath, hdfpathcol, 'matlab_type');
    if ~strcmp( dtype, 'table')
        tbl.( colname) = h5read( filepath, hdfpathcol);
    else % if strcmp( dtype, 'table')
        n_rows = size(tbl,1);
        col = cell(1,n_rows);
        % Recurse if the column elements are tables themselves.
        for i_tblrow = 1 : n_rows
           col(i_tblrow) = {readBron2table( filepath,...
                               [ hdfpathcol '/Element' int2str(i_tblrow)])};
        end
        tbl.( colname) = col';
    end
end

% VariableDescriptions and -Units can only be assigned if not empty.
vd = h5read( filepath, [hdfroot '/VariableDescriptions']);
if ~isempty(vd)
    if ischar(vd)
        vd = {vd};
    end
    tbl.Properties.VariableDescriptions = vd;
end

vu = h5read( filepath, [hdfroot '/VariableUnits']);
if ~isempty(vu)
    if ischar(vu)
        vu = {vu};
    end
    tbl.Properties.VariableUnits = vu;
end

end

function [output] = testFunction()

% Define test case
if strcmp( getUser, 'Giel van Bergen')
    bron_file = 'C:\Users\Provincie Gelderland\Documents\archief\ICT\bron2_matlab\Testdata_Overijssel CB 3 juli 2020_v3xi.bron2';
else
    error( ['QC-Wizard:' mfilename ':Unknown User'], 'Error, user is unknown. Please modify code or contact support.')
end

% Call main function
output = readBron2gmw( bron_file, '');
end