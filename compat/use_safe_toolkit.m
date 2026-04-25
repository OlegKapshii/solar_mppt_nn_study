function use_safe_toolkit()
%USE_SAFE_TOOLKIT  Перемкнути графічний тулкіт на gnuplot, якщо він є.
%
%   На Windows-Octave 11 fltk-тулкіт використовує OpenGL і часто падає
%   з діалогом «Load library failed (код 87)» при складних графіках
%   (зокрема scatter3, велика кількість subplot'ів). Gnuplot обходить
%   OpenGL — стабільніший для нашого набору графіків.
%
%   Викликати на початку кожного entry-point скрипта.

    try
        avail = available_graphics_toolkits();
        if any(strcmp(avail, 'gnuplot'))
            graphics_toolkit('gnuplot');
        end
    catch
        % silent — якщо щось пішло не так, лишаємо тулкіт за замовч.
    end
end
