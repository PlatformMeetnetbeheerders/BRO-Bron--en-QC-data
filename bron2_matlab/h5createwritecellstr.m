function h5createwritecellstr( filepath, hdfpath, col)
%H5CREATEWRITECELLSTR Store a cellstring in an HDF5 file.
%   
% INPUT
%  filepath:
%    Char, path and name of the file to write to or to create if it does
%    not exist.
%  hdfroot:
%    Char, the root in the HDF5 hierarchy under which to store col
%  col:
%    Cellstr, the cellstr
%
% Since Matlab < R2020 does not support storing strings with h5{create/write},
% I adapted this from  the example HDF5_vlen_string_example.m at
% https://www.mathworks.com/matlabcentral/fileexchange/24091-hdf5-read-write-cellstr-example
% (BSD license)
% some column elements are {[]}, replace by {''}

if ischar(col)
    col = cellstr( col);
end

for i = 1 : length( col)
    if isempty(col{i})
        col{i} = '';
    end
end

try
    fid = H5F.open( filepath, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
catch
    fid = H5F.create( filepath, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
end

% Set variable length string type
vlstr_type = H5T.copy( 'H5T_C_S1');
H5T.set_size( vlstr_type, 'H5T_VARIABLE');


% Create dataset:
% If dataset exists, open and increase size to store size(str)
try
    dset = H5D.open( fid, hdfpath);
    H5D.set_extent( dset, fliplr(size(str)));
catch
% If hdfpath does not exist, create intermediate groups
% then create the dataset
    slashes = strfind( hdfpath, '/');
    for i = 2 : length( slashes)
        url = hdfpath( 1:(slashes(i)-1));
        try
            default = 'H5P_DEFAULT';
            H5G.create( fid, url, default, default, default);
        catch
        end
    end
    
    % Create a dataspace for cellstr
    H5S_UNLIMITED = H5ML.get_constant_value( 'H5S_UNLIMITED');
    spacerank = max( 1, sum( size( col) > 1));
    if ismatrix(col) && min(size(col)) == 1
        dspace = H5S.create_simple( spacerank, length( col),...
                                    ones( 1, spacerank)*H5S_UNLIMITED);
    else
        dspace = H5S.create_simple( spacerank, fliplr( size( col)),...
                                    ones( 1, spacerank)*H5S_UNLIMITED);
    end


    % Create a dataset plist for chunking. (A dataset can't be unlimited
    % unless the chunk size is defined.)
    plist = H5P.create( 'H5P_DATASET_CREATE');
    chunksize = ones( 1, spacerank);
    chunksize( 1) = 2; % 2 strings per chunk
    H5P.set_chunk( plist, chunksize);
    dset = H5D.create( fid, hdfpath, vlstr_type, dspace, plist);

    % Close resources
    H5P.close( plist);
    H5S.close( dspace);
end

% Write data
if true || ~isempty(col)
    H5D.write( dset, vlstr_type, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', col);
end
% Close resources
H5T.close( vlstr_type);
H5D.close( dset);
H5F.close( fid);
end
