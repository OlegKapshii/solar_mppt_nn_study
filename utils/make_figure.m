function fig = make_figure(name, w, h)
%MAKE_FIGURE  Створює фігуру стандартного розміру з білим фоном.
%   У headless-режимі (octave-cli без DISPLAY) використовує gnuplot
%   як toolkit, що не потребує OpenGL.
    if nargin < 2, w = 900; end
    if nargin < 3, h = 600; end

    headless = isempty(getenv('DISPLAY'));
    if headless
        try, graphics_toolkit('gnuplot'); catch, end
    end

    fig = figure('Name', name, 'Position', [100 100 w h], 'Color', 'w');

    % У headless обов'язково перемикаємо toolkit самої фігури —
    % інакше figure() створює FLTK навіть при default=gnuplot.
    if headless
        try, set(fig, '__graphics_toolkit__', 'gnuplot'); catch, end
    end
end
