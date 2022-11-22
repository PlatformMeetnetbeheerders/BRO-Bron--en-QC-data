function write2Bron2( filepath, hdfpath, obj)
%write2Bron2 - Write BRO object to Bron format v2.0
%
% INPUT
%  filepath:
%    Char, path and name of the file to write to or to create if it does
%    not exist.
%  hdfpath:
%    Char, the root in the HDF5 hierarchy under which to store obj.
%  obj:
%    Struct, contains BRO object data that will be written to filepath
%
% This ignores columns named 'Comment' (since there is something wrong with
% this column in the test data).
%
% Written by Giel van Bergen, Jos von Asmuth (Provincie Gelderland) d.d. : 14-Mar-2022.
% Published by Provincie Gelderland, under the CC-BY Public License ( Creative Commons Attribution 4.0 International).

%% Default input and test

if ~exist( 'filepath', 'var')
    testFunction();
    return
end

% Avoid that paths start with '//' when doing [hdfroot '/' ...] with hdfroot == '/'
if strcmp(hdfpath, '/')
    hdfpath = '';
end

%% Process object array
fields = fieldnames( obj);

for i = 1 : length( obj)
    %i / length( obj) % uncomment for a kind of 'progressbar'.
    
    %% Process object structure fields
    %wellCode = obj( i).Well.BROID{ 1};
    %assert(~isempty(wellCode));
    for j = 1 : size( fields, 1)
    
        %% Write table contained in structure field
        writeTable2Bron( filepath, [hdfpath '/' num2str(i) '/' fields{ j}], obj( i).( fields{ j}));
    end
end

% Note: BRON_VERSION is always stored at '/', even if hdfpath is non-empty.
try
    version_in_file = h5readatt( filepath, '/', 'BRON_VERSION');
catch
    version_in_file = [2,0];
    % Attributes can't be written if the file does not exist, which happens
    % if the structarray is empty.
    if exist(filepath, 'file')
        h5writeatt( filepath, '/', 'BRON_VERSION', version_in_file);
    end
end

% check for major version == 2
if version_in_file(1) ~= 2
    error( ['QC-Wizard:' mfilename ':MajorVersionConflict'], 'Error, incompatible Bron-format major version.');
end
end

function writeTable2Bron( filepath, hdfpath, tbl)
% writeTable2Bron - Write a table to a BronV2.x file, at hdfpath in the file
%
% INPUT
%  filepath:
%    Char, path and name of the file to read or write
%  hdfpath:
%    Char, path + name dataset the HDF5 file (e.g. '/group1/tablename')
%  tbl:
%    Table, containing BRO object data
%
% Written by Giel van Bergen, Jos von Asmuth (Provincie Gelderland) d.d. : 14-Mar-2022.
% Published by Provincie Gelderland, under the CC-BY Public License ( Creative Commons Attribution 4.0 International).

colnames = tbl.Properties.VariableNames;

if ~isempty(tbl)
    % Case 1 : tbl is a table with multiple columns : reduce to case of single
    % column and add some metadata.
    for i = 1 : size( tbl, 2)
        col = tbl( :, i);
        colname = colnames{i};
        processTableColumn( filepath, [hdfpath '/' colname], col);
    end
end

writeTblMetadata(filepath, hdfpath, tbl)
end

function processTableColumn( filepath, hdfpath, col)

%% To be continued...
% dbstop if error
% error( ['QC-Wizard:' mfilename ':FunctionUnderConstruction'], 'Error, function is under construction. Please modify code or contact support.')


%% Case 3) tbl is a single column from a table
%% 3z) IGNORE COLUMNS NAMED 'Comment' ( there is something wrong with this
%     column in the test data).
if strcmp( col.Properties.VariableNames{1}, 'Comment')
    A ={};
    % TODO: Pre-allocate A
    for i_col = 1 : size( col, 1)
        A(i_col) = {'COMMENT'};
    end
    h5createwritecellstr( filepath, hdfpath , A)
    h5writeatt( filepath, hdfpath, 'matlab_type', 'cellstr');
    return
end

%% 3a) Recognise if the column contains tables and use recursion

iscolwithtables = false;
for i_col = 1 : size( col, 1)
    z = col{i_col, 1};
    if istable( z) || ( iscell( z) && istable( z{1}))
        iscolwithtables = true;
        break
    end
end

if iscolwithtables
    '3a';
    for i_col = 1 : size( col, 1)
        z = col{i_col, 1};
        % Mutual recursion with writeTable2Bron for nested tables.
        hdfpathtable = [hdfpath '/Element' int2str( i_col)];
        if istable( z)
            writeTable2Bron( filepath, hdfpathtable, z);
        elseif iscell( z) && istable( z{1})
            writeTable2Bron( filepath, hdfpathtable, z{1});
        elseif isempty( z) || ( iscell( z) && isempty( z{1}))
            writeTable2Bron( filepath, hdfpathtable, table([]));
        else
            error(['QC-Wizard:' mfilename ':DatatypeError'], 'Struct contains unsupported datatype');
        end
    end

    % NOTE: while writeTblMetadata is indeed called in the 'writeTable's
    % above, those only write metadata for the individual column elements.
    % The following call is necessary for the column in its entirety.
    writeTblMetadata(filepath, hdfpath, col);
    return
end

%% 3b) The column contains something that is not a table.
z = col{1, 1};
dtype = class( z); % Datatype for the column elements.
if iscell( z) && ~ischar( z{1}) && ~isempty(z{1})
    error( ['Wrong dtype (cell{' class( col{1, 1}{1}) '})']);
end

% Create different datasets depending on the dtype
switch dtype
    case {'cell', 'char'}
        h5createwritecellstr( filepath, hdfpath, col{:,1})
    case 'double'
        fillval = nan;
        h5create( filepath, hdfpath, Inf, 'ChunkSize', 8, 'Datatype', 'double', 'FillValue', fillval);
        h5write( filepath, hdfpath, col{:, 1}, 1, size(col, 1));
    case {'uint8', 'uint16', 'uint32', 'uint64'}
        % (u)int# arithmetic in matlab returns max value possible
        % when overflow occurs
        fillval = eval( [dtype '(2)'])^65;
        h5create( filepath, hdfpath, Inf, 'ChunkSize', 8, 'Datatype', dtype, 'FillValue', fillval);
        h5write( filepath, hdfpath, col{:, 1}, 1, size(col, 1));
    otherwise
        error( ['wrong dtype (' dtype ')']);
end

if isequal(dtype, 'cell') || isequal(dtype, 'char')
    h5writeatt( filepath, hdfpath, 'matlab_type', 'cellstr');
else
    h5writeatt( filepath, hdfpath, 'matlab_type', dtype);
end
end


function writeTblMetadata(filepath, hdfpath, tbl)
%% Writes table metadata

h5createwritecellstr( filepath, [hdfpath '/VariableNames'], tbl.Properties.VariableNames);
h5writeatt( filepath, [hdfpath '/VariableNames'], 'matlab_type', 'cellstr');

% Keep this _after_ creating hdfpath/VariableNames, since that creates
% group hdfpath if the table is empty.
h5writeatt( filepath, hdfpath, 'matlab_type', 'table');

% VariableNames is the same as ColumnNames, but store anyways for consistency
% with VariableDescriptions and VariableUnits


% If these arrays are empty, create a dataset with no data.
if ~isempty( tbl.Properties.VariableDescriptions)
    h5createwritecellstr( filepath, [hdfpath '/VariableDescriptions'], tbl.Properties.VariableDescriptions);
else
    h5create( filepath, [hdfpath '/VariableDescriptions'],  Inf, 'Chunksize', 8)
end
h5writeatt( filepath, [hdfpath '/VariableDescriptions'], 'matlab_type', 'cellstr');

if ~isempty( tbl.Properties.VariableUnits)
    h5createwritecellstr( filepath, [hdfpath '/VariableUnits'], tbl.Properties.VariableUnits);
else
    h5create( filepath, [hdfpath '/VariableUnits'],  Inf, 'Chunksize', 8);
end
h5writeatt( filepath, [hdfpath '/VariableUnits'], 'matlab_type', 'cellstr');

end

function testFunction()

% Define test case
if strcmp( getUser, 'Jos von Asmuth (Trefoil Hydrology)')

    % BRO data putten dan wel gmw-structs Gelderland
    mat_file  = 'C:\Users\trefo\OneDrive - Trefoil Hydrology\Menyanthes\Data\Knooppunt_ruw\gelderland\gelderland.gmw';
    bron2_file = 'C:\Users\trefo\OneDrive - Trefoil Hydrology\Menyanthes\Data\Knooppunt_ruw\gelderland\gmw_gelderland.bron2';
    load( mat_file, '-mat');
elseif strcmp( getUser, 'Giel van Bergen')
    basename_file = 'C:\Users\Provincie Gelderland\Documents\archief\ICT\bron2_matlab\Testdata_Overijssel CB 3 juli 2020_v3xi';
    mat_file = [basename_file '.bron'];
    bron2_file = [basename_file '.bron2'];

    load( mat_file, '-mat');
    gmw = rmfield( d.GMW, 'H');
else
    error( ['QC-Wizard:' mfilename ':Unknown User'], 'Error, user is unknown. Please modify code or contact support.')
end
if exist( bron2_file, 'file')
   delete( bron2_file)
end
% Call main function
write2Bron2( bron2_file, '', gmw)
end
