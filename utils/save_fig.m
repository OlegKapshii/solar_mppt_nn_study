function save_fig(fig_handle, name, cfg)
%SAVE_FIG  Зберігає фігуру як PNG у cfg.io.results_dir.
%
%   save_fig(fig_handle, name, cfg)
%
%   name — без розширення. Додається .png автоматично.

    if nargin < 3, cfg = config(); end
    if ~cfg.io.save_figures, return; end

    if ~exist(cfg.io.results_dir, 'dir')
        mkdir(cfg.io.results_dir);
    end

    fname = fullfile(cfg.io.results_dir, [name, '.png']);
    try
        % В gnuplot-режимі задаємо шрифт, що підтримує кирилицю
        if strcmp(get(fig_handle, '__graphics_toolkit__'), 'gnuplot')
            print(fig_handle, fname, '-dpng', ...
                  sprintf('-r%d', cfg.io.fig_dpi), ...
                  '-FArial:11');
        else
            print(fig_handle, fname, '-dpng', sprintf('-r%d', cfg.io.fig_dpi));
        end
    catch err
        warning('save_fig:print_failed', ...
                'Не вдалося зберегти %s: %s', fname, err.message);
    end
end
