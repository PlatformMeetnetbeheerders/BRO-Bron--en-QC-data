function user = getUser( user)
% getUser - get current Windows user, if available use full name
%
% OUTPUT
%  user:
%    char array, current Windows user
%
% Written by J.R. von Asmuth (KWR) d.d.: 29-Jul-2014.
% Published under the Creative Commons CC-BY Public License

% Get current user by default
if ~exist( 'user', 'var')
    % user  = win_base( 'get_user');
    user  = winqueryreg( 'HKEY_CURRENT_USER', 'Volatile Environment', 'USERNAME');
end

% Available aliases
alias = { 'asmuthjo' 'J.R. von Asmuth' ;...
          'trefo'    'Jos von Asmuth (Trefoil Hydrology)' ;...   
          'jobwi'    'Job Winterdijk (Trefoil Hydrology)' ;...   
          'GooijJ02' 'J. Gooijer'
          'Provincie Gelderland' 'Giel van Bergen'}; % Hopelijk komt er geen tweede ontwikkelaar met provinciale laptop.
      
% Replace in case of match      
match = strcmp( user, alias( :,1));
if any( match)
    user = alias{ match, 2};
end   
end