function setup_paths()
%SETUP_PATHS  Додає всі підпапки full_system/ у path Octave.
%
%   Викликати один раз на початку сесії або з експериментів.

    here = fileparts(mfilename('fullpath'));
    root = fileparts(here);
    addpath(root);
    addpath(fullfile(root, 'modules'));
    addpath(fullfile(root, 'trackers'));
    addpath(fullfile(root, 'nn'));
    addpath(fullfile(root, 'sim'));
    addpath(fullfile(root, 'utils'));
end
