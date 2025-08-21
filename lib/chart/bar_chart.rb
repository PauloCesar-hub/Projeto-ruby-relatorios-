require "chunky_png"

module CsvReportSuite
  module Chart
    class BarChart
      DEFAULTS = {
        width: 800,
        height: 400,
        padding: 40,
        background: ChunkyPNG::Color::WHITE,
        axis_color: ChunkyPNG::Color.rgb(30, 30, 30),
        bar_color: ChunkyPNG::Color.rgb(40, 120, 200),
        font_color: ChunkyPNG::Color.rgb(10, 10, 10),
        grid_color: ChunkyPNG::Color.rgb(220, 220, 220),
        bar_spacing: 8,
        label_font_size: 12
      }.freeze

      def initialize(categories:, values:, output_path:, options: {})
        @categories = categories
        @values = values.map(&:to_f)
        @output_path = output_path
        @opt = DEFAULTS.merge(options)
      end

      def render
        png = ChunkyPNG::Image.new(@opt[:width], @opt[:height], @opt[:background])

        max_val = (@values.max || 1)
        usable_height = @opt[:height] - 2 * @opt[:padding]
        usable_width  = @opt[:width] - 2 * @opt[:padding]

        (0..5).each do |i|
          y_ratio = i / 5.0
            y = @opt[:padding] + (1 - y_ratio) * usable_height
          draw_hline(png, y.to_i, @opt[:grid_color])
          label_val = (y_ratio * max_val).round(2)
          draw_text(png, 5, y.to_i - 8, label_val.to_s, size: 10)
        end

        y_axis_x = @opt[:padding]
        x_axis_y = @opt[:height] - @opt[:padding]
        draw_vline(png, y_axis_x, @opt[:axis_color])
        draw_hline(png, x_axis_y, @opt[:axis_color])

        bar_count = @values.size
        return save(png) if bar_count.zero?

        bar_width = [(usable_width - (@opt[:bar_spacing] * (bar_count + 1))) / bar_count.to_f, 5].max

        @values.each_with_index do |val, idx|
          x = @opt[:padding] + @opt[:bar_spacing] + idx * (bar_width + @opt[:bar_spacing])
          bar_height = (val / max_val) * usable_height
          y_top = x_axis_y - bar_height
          draw_filled_rect(png, x, y_top, x + bar_width, x_axis_y - 1, @opt[:bar_color])

          draw_text(png, x + bar_width / 4, y_top - 14, val.round(2).to_s, size: 10)

          label = truncate(@categories[idx].to_s, 12)
          draw_text(png, x + 2, x_axis_y + 4, label, size: 10)
        end

        save(png)
      end

      private

      def save(png)
        png.save(@output_path)
      end

      def draw_hline(png, y, color)
        (0...png.width).each { |x| png[x, y] = color }
      end

      def draw_vline(png, x, color)
        (0...png.height).each { |y| png[x, y] = color }
      end

      def draw_filled_rect(png, x0, y0, x1, y1, color)
        (y0.to_i..y1.to_i).each do |y|
          (x0.to_i..x1.to_i).each do |x|
            next if x < 0 || y < 0 || x >= png.width || y >= png.height
            png[x, y] = color
          end
        end
      end


      SIMPLE_FONT = {
        "0" => ["###","# #","# #","# #","###"],
        "1" => [" # ","## "," # "," # ","###"],
        "2" => ["###","  #","###","#  ","###"],
        "3" => ["###","  #"," ##","  #","###"],
        "4" => ["# #","# #","###","  #","  #"],
        "5" => ["###","#  ","###","  #","###"],
        "6" => ["###","#  ","###","# #","###"],
        "7" => ["###","  #","  #","  #","  #"],
        "8" => ["###","# #","###","# #","###"],
        "9" => ["###","# #","###","  #","###"]
      }.freeze

      def draw_text(png, x, y, text, size: 10)
        scale = (size / 10.0)
        cursor_x = x.to_i
        text.to_s.each_char do |ch|
            pattern = SIMPLE_FONT[ch]
            if pattern
              pattern.each_with_index do |row, ry|
                row.chars.each_with_index do |px, rx|
                  next unless px == "#"
                  (0...(scale.ceil)).each do |dx|
                    (0...(scale.ceil)).each do |dy|
                      xx = cursor_x + rx * scale + dx
                      yy = y + ry * scale + dy
                      next if xx < 0 || yy < 0 || xx >= png.width || yy >= png.height
                      png[xx.to_i, yy.to_i] = @opt[:font_color]
                    end
                  end
                end
              end
              cursor_x += (4 * scale).to_i
            else
              cursor_x += (4 * scale).to_i
            end
        end
      end

      def truncate(str, max_len)
        return str if str.size <= max_len
        str[0, max_len - 1] + "…"
      end
    end
  end
end