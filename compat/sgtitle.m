function h = sgtitle(varargin)
%SGTITLE  Polyfill для відсутньої в Octave функції sgtitle (Matlab R2018b+).
%
%   sgtitle(title)
%   sgtitle(title, Name, Value, ...)
%
%   Створює загальний заголовок над усіма subplot'ами через приховану
%   повнорозмірну вісь і текстову анотацію.
%
%   Цей файл має бути в шляху Octave (через addpath). Якщо в системі
%   є рідна sgtitle (Matlab або новіший Octave) — вона має пріоритет
%   за рахунок порядку шляхів, тож ця обгортка не зашкодить.

    if isempty(varargin)
        h = [];
        return;
    end

    title_text = '';
    extra_args = {};
    if ischar(varargin{1}) || (exist('isstring','builtin') && isstring(varargin{1}))
        title_text = char(varargin{1});
        extra_args = varargin(2:end);
    end

    fig = gcf;
    try
        current_ax = gca;
    catch
        current_ax = [];
    end

    % Прихована повнорозмірна вісь — для розміщення текстового заголовка
    annotation_ax = axes('Parent', fig, ...
                        'Units', 'normalized', ...
                        'Position', [0, 0, 1, 1], ...
                        'Visible', 'off');

    h = text(0.5, 0.985, title_text, ...
             'Parent', annotation_ax, ...
             'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'top', ...
             'FontSize', 14, ...
             'FontWeight', 'bold');

    % Накладемо додаткові опції (FontSize/FontWeight/Color і т.д.)
    if ~isempty(extra_args)
        try
            set(h, extra_args{:});
        catch err
            warning('sgtitle:options', 'Не вдалося застосувати опції: %s', err.message);
        end
    end

    if ~isempty(current_ax) && ishandle(current_ax)
        try
            axes(current_ax);
        catch
        end
    end
end
